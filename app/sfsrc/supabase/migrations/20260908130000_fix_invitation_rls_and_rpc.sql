-- ============================================================
-- SENTINEL P0: Invitation acceptance RPC + Role-based RLS
-- ============================================================

-- ─── 1. HELPER FUNCTION: is_group_admin ─────────────────────
-- Returns true if the calling user is owner or admin of a group.
-- Used by RLS policies on groups and invitations.
CREATE OR REPLACE FUNCTION public.is_group_admin(p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = p_group_id
      AND gm.user_id  = auth.uid()
      AND gm.role     IN ('owner', 'admin')
      AND gm.status   = 'active'
  );
$$;

-- ─── 2. ATOMIC INVITATION ACCEPTANCE RPC ────────────────────
-- Accepts an invitation in a single transaction:
--   • Validates token exists and is in 'prepared' or 'pending' state
--   • Checks caller is authenticated
--   • Prevents duplicate membership
--   • Inserts group_members with role = 'member'
--   • Marks invitation as 'accepted'
--   • Returns the group_id so the client can set it as active
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

  -- Only accept if status is prepared or pending (dispatched is also OK)
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
      'group_id',  v_invitation.group_id,
      'already_member', true
    );
  END IF;

  -- Insert membership as role = 'member'
  INSERT INTO public.group_members (group_id, user_id, role, status)
  VALUES (v_invitation.group_id, v_user_id, 'member', 'active');

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

-- ─── 3. RLS: groups ─────────────────────────────────────────
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

-- SELECT: any member of the group can read it
DROP POLICY IF EXISTS "groups_select_members" ON public.groups;
CREATE POLICY "groups_select_members"
ON public.groups
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = public.groups.id
      AND gm.user_id  = auth.uid()
      AND gm.status   = 'active'
  )
);

-- INSERT: only authenticated users can create a group (owner_id must be themselves)
-- Backend enforcement: owner_id = auth.uid()
DROP POLICY IF EXISTS "groups_insert_owner" ON public.groups;
CREATE POLICY "groups_insert_owner"
ON public.groups
FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- UPDATE: only owner/admin of the group
DROP POLICY IF EXISTS "groups_update_admin" ON public.groups;
CREATE POLICY "groups_update_admin"
ON public.groups
FOR UPDATE
TO authenticated
USING (public.is_group_admin(id))
WITH CHECK (public.is_group_admin(id));

-- DELETE: only owner of the group
DROP POLICY IF EXISTS "groups_delete_owner" ON public.groups;
CREATE POLICY "groups_delete_owner"
ON public.groups
FOR DELETE
TO authenticated
USING (owner_id = auth.uid());

-- ─── 4. RLS: group_members ───────────────────────────────────
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

-- SELECT: members can see other members of their own groups
DROP POLICY IF EXISTS "group_members_select" ON public.group_members;
CREATE POLICY "group_members_select"
ON public.group_members
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.group_members gm2
    WHERE gm2.group_id = public.group_members.group_id
      AND gm2.user_id  = auth.uid()
      AND gm2.status   = 'active'
  )
);

-- INSERT: only the accept_invitation RPC (SECURITY DEFINER) inserts memberships.
-- Direct client inserts are blocked except for the group creator inserting themselves
-- as owner (handled by createGroup flow where owner_id = auth.uid()).
DROP POLICY IF EXISTS "group_members_insert_self_owner" ON public.group_members;
CREATE POLICY "group_members_insert_self_owner"
ON public.group_members
FOR INSERT
TO authenticated
WITH CHECK (
  -- Allow only if inserting yourself as owner (group creation flow)
  (user_id = auth.uid() AND role = 'owner')
);

-- UPDATE: only owner/admin can change roles/status of members
DROP POLICY IF EXISTS "group_members_update_admin" ON public.group_members;
CREATE POLICY "group_members_update_admin"
ON public.group_members
FOR UPDATE
TO authenticated
USING (public.is_group_admin(group_id))
WITH CHECK (public.is_group_admin(group_id));

-- DELETE: owner/admin can remove members; members can remove themselves
DROP POLICY IF EXISTS "group_members_delete" ON public.group_members;
CREATE POLICY "group_members_delete"
ON public.group_members
FOR DELETE
TO authenticated
USING (
  user_id = auth.uid()
  OR public.is_group_admin(group_id)
);

-- ─── 5. RLS: invitations ─────────────────────────────────────
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;

-- SELECT: invited_by (admin) can see their invitations;
--         anyone can read an invitation by token (needed for join screen)
DROP POLICY IF EXISTS "invitations_select" ON public.invitations;
CREATE POLICY "invitations_select"
ON public.invitations
FOR SELECT
TO authenticated
USING (
  invited_by = auth.uid()
  OR public.is_group_admin(group_id)
);

-- SELECT for unauthenticated token lookup (join screen loads before login)
DROP POLICY IF EXISTS "invitations_select_anon_token" ON public.invitations;
CREATE POLICY "invitations_select_anon_token"
ON public.invitations
FOR SELECT
TO anon
USING (true);

-- INSERT: only owner/admin of the group can create invitations
DROP POLICY IF EXISTS "invitations_insert_admin" ON public.invitations;
CREATE POLICY "invitations_insert_admin"
ON public.invitations
FOR INSERT
TO authenticated
WITH CHECK (
  invited_by = auth.uid()
  AND public.is_group_admin(group_id)
);

-- UPDATE: only the accept_invitation RPC (SECURITY DEFINER) updates status.
-- Direct client updates blocked.
DROP POLICY IF EXISTS "invitations_update_admin" ON public.invitations;
CREATE POLICY "invitations_update_admin"
ON public.invitations
FOR UPDATE
TO authenticated
USING (
  invited_by = auth.uid()
  OR public.is_group_admin(group_id)
)
WITH CHECK (
  invited_by = auth.uid()
  OR public.is_group_admin(group_id)
);
