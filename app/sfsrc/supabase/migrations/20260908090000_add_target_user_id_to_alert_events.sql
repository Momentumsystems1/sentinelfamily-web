-- Phase 2: Add target_user_id to alert_events for directed ok_check events
-- This allows "¿Todo bien?" to target a specific group member.

ALTER TABLE public.alert_events
ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_alert_events_target_user_id
  ON public.alert_events(target_user_id);
