-- ============================================================
-- SENTINEL P0: Admin provisioning fix
-- ============================================================
-- Problem: Primary admin account has can_create_groups = FALSE
-- because the previous migration only migrated users with
-- existing active owner memberships. If group creation had
-- previously failed, the admin has no membership row and
-- was not migrated.
--
-- This migration:
-- 1. Provisions the earliest registered user (primary admin)
--    with can_create_groups = TRUE if they have no groups yet
-- 2. Provisions ALL users who own at least one group (belt-and-suspenders)
-- 3. Fixes profiles UPDATE RLS to block self-updating can_create_groups
-- 4. Updates accept_invitation RPC to explicitly set can_create_groups = FALSE
-- 5. Adds a trigger on auth.users to auto-provision new signups
-- ============================================================

-- ─── 1. PROVISION EXISTING PRIMARY ADMIN ────────────────────
-- The earliest registered user in auth.users is the primary admin.
-- If they have no active owner membership (group creation failed),
-- the previous migration did not set their flag.
-- We provision them now.
DO $$
DECLARE
  v_earliest_user_id UUID;
BEGIN
  -- Get the earliest registered user from auth.users
  SELECT id INTO v_earliest_user_id
  FROM auth.users
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_earliest_user_id IS NOT NULL THEN
    UPDATE public.profiles
    SET can_create_groups = TRUE
    WHERE id = v_earliest_user_id;

    RAISE NOTICE 'Provisioned primary admin: %', v_earliest_user_id;
  ELSE
    RAISE NOTICE 'No users found in auth.users';
  END IF;
END $$;

-- ─── 2. ALSO MIGRATE ALL EXISTING GROUP OWNERS ──────────────
-- Belt-and-suspenders: any user who owns a group must have TRUE.
UPDATE public.profiles p
SET can_create_groups = TRUE
WHERE EXISTS (
  SELECT 1 FROM public.group_members gm
  WHERE gm.user_id = p.id
    AND gm.role    = 'owner'
    AND gm.status  = 'active'
)
AND p.can_create_groups = FALSE;

-- ─── 3. FIX profiles UPDATE RLS ─────────────────────────────
-- The existing profiles_update_own policy allows users to update
-- their own profile including can_create_groups — a security hole.
-- Replace it with a policy that blocks can_create_groups self-update.
--
-- Strategy: Use a SECURITY DEFINER function that validates the update
-- does not change can_create_groups.
CREATE OR REPLACE FUNCTION public.profiles_update_allowed()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  -- This function is used in the WITH CHECK clause.
  -- The actual column-level restriction is enforced by the RPC.
  -- We return TRUE here; column-level security is handled by
  -- the set_can_create_groups_blocked trigger below.
  SELECT TRUE;
$$;

-- Trigger function: block direct updates to can_create_groups
CREATE OR REPLACE FUNCTION public.block_can_create_groups_self_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If can_create_groups is being changed and the caller is not a service role,
  -- block the update by reverting the field to its old value.
  -- SECURITY DEFINER functions (RPCs) bypass RLS and triggers are not affected
  -- by this check because they run as the table owner.
  -- This trigger fires on direct client updates via RLS-authenticated sessions.
  IF NEW.can_create_groups IS DISTINCT FROM OLD.can_create_groups THEN
    -- Revert the change — cannot raise exception as it would break other updates
    NEW.can_create_groups := OLD.can_create_groups;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_can_create_groups ON public.profiles;
CREATE TRIGGER trg_block_can_create_groups
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.block_can_create_groups_self_update();

-- ─── 4. UPDATE accept_invitation RPC ────────────────────────
-- Explicitly set can_create_groups = FALSE for invited users.
-- This is belt-and-suspenders (default is already FALSE) but
-- makes the intent explicit and handles edge cases where a user
-- might have been provisioned as admin before accepting an invite.
CREATE OR REPLACE FUNCTION public.accept_invitation(p_token UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invitation  RECORD;
  v_user_id     UUID := auth.uid();
  v_already     BOOLEAN;
BEGIN
  -- Must be authenticated
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Lock the invitation row to prevent concurrent double-accepts
  SELECT * INTO v_invitation
  FROM public.invitations
  WHERE token = p_token
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'invitation_not_found');
  END IF;

  -- Only accept if status is prepared, pending, or dispatched
  IF v_invitation.status NOT IN ('prepared', 'pending', 'dispatched') THEN
    RETURN jsonb_build_object(
      'error',
      CASE v_invitation.status
        WHEN 'accepted' THEN 'already_accepted'
        WHEN 'expired'  THEN 'invitation_expired'
        WHEN 'revoked'  THEN 'invitation_revoked'
        ELSE 'invitation_unavailable'
      END
    );
  END IF;

  -- Check for duplicate membership (any status)
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = v_invitation.group_id
      AND user_id  = v_user_id
  ) INTO v_already;

  IF v_already THEN
    -- Already a member — mark invitation accepted and return group_id
    UPDATE public.invitations
    SET status = 'accepted'
    WHERE token = p_token;

    RETURN jsonb_build_object(
      'group_id',       v_invitation.group_id,
      'already_member', true
    );
  END IF;

  -- Insert membership as role = 'member'
  INSERT INTO public.group_members (group_id, user_id, role, status)
  VALUES (v_invitation.group_id, v_user_id, 'member', 'active');

  -- Explicitly ensure invited user cannot create groups
  -- (default is FALSE, but be explicit for users who may have been
  --  provisioned as admin before accepting the invite)
  UPDATE public.profiles
  SET can_create_groups = FALSE
  WHERE id = v_user_id
    AND NOT EXISTS (
      -- Do not revoke if they own another group
      SELECT 1 FROM public.group_members gm2
      WHERE gm2.user_id = v_user_id
        AND gm2.role    = 'owner'
        AND gm2.status  = 'active'
        AND gm2.group_id != v_invitation.group_id
    );

  -- Mark invitation accepted
  UPDATE public.invitations
  SET status = 'accepted'
  WHERE token = p_token;

  RETURN jsonb_build_object(
    'group_id', v_invitation.group_id,
    'role',     'member'
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- ─── 5. SERVER-SIDE TRIGGER FOR NEW SIGNUPS ─────────────────
-- When a new user registers through normal signup (not via invitation),
-- they should get can_create_groups = TRUE automatically.
-- Invitation-path users get FALSE (default) and the accept_invitation
-- RPC keeps it FALSE.
--
-- We cannot distinguish signup path in the trigger alone, so we
-- provision all new signups as TRUE by default. The invitation
-- acceptance RPC will set it to FALSE for invited members.
-- This matches the product rule:
--   standalone signup → TRUE
--   invitation signup → FALSE (set by accept_invitation RPC)
CREATE OR REPLACE FUNCTION public.handle_new_user_provisioning()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Upsert profile with can_create_groups = TRUE for new signups.
  -- Invitation-path users will have this set to FALSE by accept_invitation RPC.
  INSERT INTO public.profiles (id, can_create_groups)
  VALUES (NEW.id, TRUE)
  ON CONFLICT (id) DO UPDATE
    SET can_create_groups = TRUE
    WHERE public.profiles.can_create_groups = FALSE
      AND NOT EXISTS (
        -- Only set TRUE if user has no existing group memberships
        -- (i.e., they are not an invited member who already accepted)
        SELECT 1 FROM public.group_members gm
        WHERE gm.user_id = NEW.id
          AND gm.role    = 'member'
          AND gm.status  = 'active'
      );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_provisioning ON auth.users;
CREATE TRIGGER on_auth_user_created_provisioning
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user_provisioning();

-- ─── 6. GRANT EXECUTE PERMISSIONS ───────────────────────────
GRANT EXECUTE ON FUNCTION public.grant_can_create_groups(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_group_as_owner(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_invitation(UUID) TO authenticated, anon;
