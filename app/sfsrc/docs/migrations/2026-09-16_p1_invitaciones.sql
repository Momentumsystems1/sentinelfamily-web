-- ============================================================
-- MIGRACIÓN P1 — Invitaciones, onboarding de círculo y
-- autorización de círculos nuevos (Spec P1 aprobada 2026-09-16)
-- Proyecto: sentinel-dev (nvannetdrfybowwjqqhf) — SOLO DEV
-- Aplica: K200 · Idempotente · No toca policies existentes
-- ============================================================

-- ---------- 1. Tabla invitations: extender la existente ----------
ALTER TABLE public.invitations
  ADD COLUMN IF NOT EXISTS invitee_name text,
  ADD COLUMN IF NOT EXISTS membership text NOT NULL DEFAULT 'fixed',
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'member',
  ADD COLUMN IF NOT EXISTS expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS accepted_by uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS accepted_at timestamptz;

ALTER TABLE public.invitations ALTER COLUMN status SET DEFAULT 'pending';

-- status: conserva valores legacy + añade 'pending' y 'declined' (spec 2.1)
ALTER TABLE public.invitations DROP CONSTRAINT IF EXISTS invitations_status_check;
ALTER TABLE public.invitations ADD CONSTRAINT invitations_status_check
  CHECK (status IN ('pending','prepared','dispatched','accepted','declined','expired','revoked'));

ALTER TABLE public.invitations DROP CONSTRAINT IF EXISTS invitations_membership_check;
ALTER TABLE public.invitations ADD CONSTRAINT invitations_membership_check
  CHECK (membership IN ('fixed','temporary'));

ALTER TABLE public.invitations DROP CONSTRAINT IF EXISTS invitations_role_check;
ALTER TABLE public.invitations ADD CONSTRAINT invitations_role_check
  CHECK (role IN ('member','guest'));

-- D4: si es temporal, expires_at es obligatorio
ALTER TABLE public.invitations DROP CONSTRAINT IF EXISTS invitations_temp_expiry_check;
ALTER TABLE public.invitations ADD CONSTRAINT invitations_temp_expiry_check
  CHECK (membership = 'fixed' OR expires_at IS NOT NULL);

ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
-- Policies: las 4 existentes (invitations_admin ALL, invitations_insert_admin,
-- invitations_select, invitations_update_admin) ya implementan el patrón
-- owner/admin de la spec 2.1. No se tocan.

-- ---------- 2. group_members: membership + expiración ----------
ALTER TABLE public.group_members
  ADD COLUMN IF NOT EXISTS membership text NOT NULL DEFAULT 'fixed',
  ADD COLUMN IF NOT EXISTS expires_at timestamptz;

ALTER TABLE public.group_members DROP CONSTRAINT IF EXISTS group_members_membership_check;
ALTER TABLE public.group_members ADD CONSTRAINT group_members_membership_check
  CHECK (membership IN ('fixed','temporary'));

-- status: conserva ('invited','active','paused') + añade 'expired'
ALTER TABLE public.group_members DROP CONSTRAINT IF EXISTS group_members_status_check;
ALTER TABLE public.group_members ADD CONSTRAINT group_members_status_check
  CHECK (status IN ('invited','active','paused','expired'));

-- ---------- 3. Tabla circle_requests (spec 2.2) ----------
CREATE TABLE IF NOT EXISTS public.circle_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id uuid NOT NULL REFERENCES public.profiles(id),
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  desired_name text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','denied')),
  decided_by uuid REFERENCES public.profiles(id),
  decided_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- anti-spam: una solicitud pendiente por usuario
CREATE UNIQUE INDEX IF NOT EXISTS circle_requests_one_pending
  ON public.circle_requests (requester_user_id) WHERE status = 'pending';

ALTER TABLE public.circle_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS circle_requests_insert_member ON public.circle_requests;
CREATE POLICY circle_requests_insert_member ON public.circle_requests
  FOR INSERT WITH CHECK (
    requester_user_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = circle_requests.group_id
        AND gm.user_id = auth.uid() AND gm.status = 'active'));

DROP POLICY IF EXISTS circle_requests_select ON public.circle_requests;
CREATE POLICY circle_requests_select ON public.circle_requests
  FOR SELECT USING (
    requester_user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = circle_requests.group_id
        AND gm.user_id = auth.uid()
        AND gm.role IN ('owner','admin') AND gm.status = 'active'));

DROP POLICY IF EXISTS circle_requests_update_admin ON public.circle_requests;
CREATE POLICY circle_requests_update_admin ON public.circle_requests
  FOR UPDATE USING (EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = circle_requests.group_id
        AND gm.user_id = auth.uid()
        AND gm.role IN ('owner','admin') AND gm.status = 'active'));

-- ---------- 4. RPC accept_invitation (spec 2.3, upgrade del legacy) ----------
CREATE OR REPLACE FUNCTION public.accept_invitation(p_token uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_invitation RECORD;
  v_user_id    UUID := auth.uid();
  v_group_name TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  SELECT * INTO v_invitation FROM public.invitations WHERE token = p_token FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'invitation_not_found');
  END IF;

  IF v_invitation.status NOT IN ('pending','prepared','dispatched') THEN
    RETURN jsonb_build_object('error', CASE v_invitation.status
      WHEN 'accepted' THEN 'already_accepted'
      WHEN 'declined' THEN 'invitation_declined'
      WHEN 'expired'  THEN 'invitation_expired'
      WHEN 'revoked'  THEN 'invitation_revoked'
      ELSE 'invitation_unavailable' END);
  END IF;

  -- expiración heredada (D4): invitación temporal caducada no se puede aceptar
  IF v_invitation.expires_at IS NOT NULL AND v_invitation.expires_at < now() THEN
    UPDATE public.invitations SET status = 'expired' WHERE token = p_token;
    RETURN jsonb_build_object('error', 'invitation_expired');
  END IF;

  -- membership: rol + tipo + expiración heredados de la invitación
  INSERT INTO public.group_members (group_id, user_id, role, status, membership, expires_at)
  VALUES (v_invitation.group_id, v_user_id, COALESCE(v_invitation.role,'member'), 'active',
          COALESCE(v_invitation.membership,'fixed'), v_invitation.expires_at)
  ON CONFLICT (group_id, user_id) DO UPDATE
    SET status = 'active',
        role = EXCLUDED.role,
        membership = EXCLUDED.membership,
        expires_at = EXCLUDED.expires_at;

  -- un invitado no puede crear grupos (salvo que ya sea owner de otro)
  UPDATE public.profiles SET can_create_groups = FALSE
  WHERE id = v_user_id AND NOT EXISTS (
    SELECT 1 FROM public.group_members gm2
    WHERE gm2.user_id = v_user_id AND gm2.role = 'owner' AND gm2.status = 'active'
      AND gm2.group_id != v_invitation.group_id);

  UPDATE public.invitations
  SET status = 'accepted', accepted_by = v_user_id, accepted_at = now()
  WHERE token = p_token;

  SELECT name INTO v_group_name FROM public.groups WHERE id = v_invitation.group_id;

  RETURN jsonb_build_object(
    'group_id', v_invitation.group_id,
    'group_name', v_group_name,
    'role', COALESCE(v_invitation.role,'member'),
    'membership', COALESCE(v_invitation.membership,'fixed'),
    'expires_at', v_invitation.expires_at);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$function$;

REVOKE ALL ON FUNCTION public.accept_invitation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_invitation(uuid) TO authenticated;

-- ---------- 5. RPC decide_circle_request (spec 2.3 + D2) ----------
CREATE OR REPLACE FUNCTION public.decide_circle_request(
  p_request_id uuid, p_approve boolean, p_new_group_name text DEFAULT null)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_req      RECORD;
  v_user_id  UUID := auth.uid();
  v_new_group UUID;
  v_name     TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  SELECT * INTO v_req FROM public.circle_requests WHERE id = p_request_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'request_not_found');
  END IF;
  IF v_req.status != 'pending' THEN
    RETURN jsonb_build_object('error', 'already_decided');
  END IF;

  -- solo owner/admin del grupo origen decide
  IF NOT EXISTS (SELECT 1 FROM public.group_members gm
                 WHERE gm.group_id = v_req.group_id AND gm.user_id = v_user_id
                   AND gm.role IN ('owner','admin') AND gm.status = 'active') THEN
    RETURN jsonb_build_object('error', 'not_authorized');
  END IF;

  IF p_approve THEN
    v_name := COALESCE(NULLIF(p_new_group_name,''), v_req.desired_name);
    INSERT INTO public.groups (name, owner_id) VALUES (v_name, v_req.requester_user_id)
    RETURNING id INTO v_new_group;

    -- D2: el solicitante SE MUEVE al nuevo círculo como owner
    DELETE FROM public.group_members
    WHERE group_id = v_req.group_id AND user_id = v_req.requester_user_id;
    INSERT INTO public.group_members (group_id, user_id, role, status, membership)
    VALUES (v_new_group, v_req.requester_user_id, 'owner', 'active', 'fixed');

    UPDATE public.profiles SET can_create_groups = TRUE WHERE id = v_req.requester_user_id;

    UPDATE public.circle_requests
    SET status = 'approved', decided_by = v_user_id, decided_at = now()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('status','approved','new_group_id', v_new_group,'group_name', v_name);
  ELSE
    UPDATE public.circle_requests
    SET status = 'denied', decided_by = v_user_id, decided_at = now()
    WHERE id = p_request_id;
    RETURN jsonb_build_object('status','denied');
  END IF;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$function$;

REVOKE ALL ON FUNCTION public.decide_circle_request(uuid,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.decide_circle_request(uuid,boolean,text) TO authenticated;

-- ---------- 6. RPC expire_temporary_memberships (spec 2.3) ----------
CREATE OR REPLACE FUNCTION public.expire_temporary_memberships()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_members INT; v_invites INT;
BEGIN
  UPDATE public.group_members SET status = 'expired'
  WHERE membership = 'temporary' AND status = 'active' AND expires_at IS NOT NULL AND expires_at < now();
  GET DIAGNOSTICS v_members = ROW_COUNT;

  UPDATE public.invitations SET status = 'expired'
  WHERE status IN ('pending','prepared','dispatched') AND expires_at IS NOT NULL AND expires_at < now();
  GET DIAGNOSTICS v_invites = ROW_COUNT;

  RETURN jsonb_build_object('members_expired', v_members, 'invitations_expired', v_invites);
END;
$function$;

REVOKE ALL ON FUNCTION public.expire_temporary_memberships() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.expire_temporary_memberships() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.expire_temporary_memberships() TO service_role;

-- RPC get_invitation_preview: datos no sensibles para la pantalla de bienvenida (spec 3.2)
-- El token uuid ES el secreto; sin fila visible vía RLS para anónimos.
CREATE OR REPLACE FUNCTION public.get_invitation_preview(p_token uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v RECORD;
BEGIN
  SELECT i.status, i.membership, i.expires_at, i.invitee_name,
         g.name AS group_name, p.display_name AS inviter_name
  INTO v
  FROM public.invitations i
  JOIN public.groups g ON g.id = i.group_id
  LEFT JOIN public.profiles p ON p.id = i.invited_by
  WHERE i.token = p_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'invitation_not_found');
  END IF;
  IF v.status NOT IN ('pending','prepared','dispatched') THEN
    RETURN jsonb_build_object('error', 'invitation_not_valid', 'status', v.status);
  END IF;
  IF v.expires_at IS NOT NULL AND v.expires_at < now() THEN
    RETURN jsonb_build_object('error', 'invitation_expired');
  END IF;

  RETURN jsonb_build_object(
    'group_name', v.group_name,
    'inviter_name', v.inviter_name,
    'invitee_name', v.invitee_name,
    'membership', v.membership,
    'expires_at', v.expires_at);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_invitation_preview(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_invitation_preview(uuid) TO anon, authenticated;
