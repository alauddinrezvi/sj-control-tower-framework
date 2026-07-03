-- ============================================================================
-- ONE-TIME FIX: Create user_role_preferences
-- Run in Supabase Dashboard → SQL Editor if role setup fails with PGRST205
-- "Could not find the table 'public.user_role_preferences'"
-- ============================================================================

DO $$
BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.user_role_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role app_role NOT NULL,
  agency_role text,
  is_eos_user boolean NOT NULL DEFAULT false,
  dashboard_layout jsonb DEFAULT '{}',
  primary_pod_id uuid,
  ai_digest_enabled boolean NOT NULL DEFAULT true,
  ai_digest_frequency text NOT NULL DEFAULT 'weekly',
  hide_completed_tasks boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);

ALTER TABLE public.user_role_preferences
  DROP CONSTRAINT IF EXISTS user_role_preferences_agency_role_check;

ALTER TABLE public.user_role_preferences
  ADD CONSTRAINT user_role_preferences_agency_role_check
  CHECK (agency_role IS NULL OR agency_role IN ('owner', 'pm', 'ic', 'bd'));

ALTER TABLE public.user_role_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_manage_own_role_prefs" ON public.user_role_preferences;
CREATE POLICY "users_manage_own_role_prefs"
  ON public.user_role_preferences
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "admins_read_all_role_prefs" ON public.user_role_preferences;
CREATE POLICY "admins_read_all_role_prefs"
  ON public.user_role_preferences
  FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE INDEX IF NOT EXISTS idx_user_role_preferences_user_id
  ON public.user_role_preferences(user_id);

NOTIFY pgrst, 'reload schema';
