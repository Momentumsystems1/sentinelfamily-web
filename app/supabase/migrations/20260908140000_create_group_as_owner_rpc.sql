-- ============================================================
-- SENTINEL P0: Atomic group creation RPC + can_create_groups
-- ============================================================

-- ─── 1. ADD can_create_groups TO profiles ───────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_create_groups BOOLEAN NOT NULL DEFAULT FALSE;

-- ─── 2. MIGRATE EXISTING OWNERS → TRUE ──────────────────────
-- Any user who already owns at least one group gets the capability.
UPDATE public.profiles p
SET can_create_groups = TRUE
WHERE EXISTS (
  SELECT 1 FROM public.group_members gm
  WHERE gm.user_id = p.id
    AND gm.role    = 'owner'
    AND gm.status  = 'active'
);

-- ─── 3. ATOMIC create_group_as_owner RPC ────────────────────
-- Atomically:
--   • Verifies caller is authenticated
--   • Verifies profiles.can_create_groups = TRUE
--   • Inserts into groups (owner_id = caller)
--   • Inserts caller into group_members as role='owner', status='active'
--   • Returns the created group row
-- If any step fails the whole transaction rolls back.
CREATE OR REPLACE FUNCTION public.create_group_as_owner(
  p_name        TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_can       BOOLEAN;
  v_group     RECORD;
BEGIN
  -- Must be authenticated
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Check account-level capability
  SELECT can_create_groups INTO v_can
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_can IS NULL OR v_can = FALSE THEN
    RETURN jsonb_build_object('error', 'permission_denied');
  END IF;

  -- Validate name
  IF p_name IS NULL OR trim(p_name) = '' THEN
    RETURN jsonb_build_object('error', 'name_required');
  END IF;

  -- Insert group
  INSERT INTO public.groups (name, owner_id)
  VALUES (trim(p_name), v_user_id)
  RETURNING * INTO v_group;

  -- Insert owner membership
  INSERT INTO public.group_members (group_id, user_id, role, status)
  VALUES (v_group.id, v_user_id, 'owner', 'active');

  RETURN jsonb_build_object(
    'id',         v_group.id,
    'name',       v_group.name,
    'owner_id',   v_group.owner_id,
    'created_at', v_group.created_at
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- ─── 4. UPDATE groups INSERT RLS ────────────────────────────
-- Direct client inserts into groups are now blocked.
-- All group creation must go through create_group_as_owner RPC (SECURITY DEFINER).
-- We keep the policy but tighten it: require can_create_groups = TRUE.
DROP POLICY IF EXISTS "groups_insert_owner" ON public.groups;
CREATE POLICY "groups_insert_owner"
ON public.groups
FOR INSERT
TO authenticated
WITH CHECK (
  owner_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND can_create_groups = TRUE
  )
);

-- ─── 5. GRANT can_create_groups TO ADMINISTRATOR ONBOARDING ─
-- The onboarding flow creates the first admin. We expose a helper
-- that can be called by the onboarding RPC (or directly in onboarding
-- if the user is the first to register).
-- This function is SECURITY DEFINER so it can set the flag regardless of RLS.
CREATE OR REPLACE FUNCTION public.grant_can_create_groups(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET can_create_groups = TRUE
  WHERE id = p_user_id;
END;
$$;

-- ─── 6. ENSURE profiles RLS allows reading own can_create_groups ─
-- (profiles table should already have RLS; this is additive)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
ON public.profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own"
ON public.profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());
