-- App config, user invites, and user status (moved from early 20241231_* migrations)
-- Depends on: 20251231002141 (has_role, profiles, update_updated_at_column)

-- Migration 1: App Config Table
CREATE TABLE IF NOT EXISTS public.app_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  category text NOT NULL DEFAULT 'general',
  description text,
  is_sensitive boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage config" ON public.app_config;
CREATE POLICY "Admins can manage config"
  ON public.app_config FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'::app_role));

DROP POLICY IF EXISTS "Users can read non-sensitive config" ON public.app_config;
CREATE POLICY "Users can read non-sensitive config"
  ON public.app_config FOR SELECT TO authenticated
  USING (is_sensitive = false);

DROP TRIGGER IF EXISTS update_app_config_updated_at ON public.app_config;
CREATE TRIGGER update_app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

INSERT INTO public.app_config (key, value, category, description) VALUES
  ('branding.company_name', '"CollabAi"', 'branding', 'Platform name displayed in UI'),
  ('branding.tagline', '"AI-Powered Collaboration Platform"', 'branding', 'Platform tagline'),
  ('branding.support_email', '"support@collabai.software"', 'branding', 'Support contact email'),
  ('features.enableAIChat', 'true', 'features', 'Enable AI chat functionality'),
  ('features.enableKnowledgeBase', 'true', 'features', 'Enable knowledge base module'),
  ('features.enableMeetings', 'true', 'features', 'Enable meetings module'),
  ('features.enableTasks', 'true', 'features', 'Enable tasks module'),
  ('features.enableNotifications', 'true', 'features', 'Enable notifications system'),
  ('features.enableSemanticSearch', 'true', 'features', 'Enable semantic search'),
  ('email.enableEmailNotifications', 'true', 'email', 'Enable email notifications'),
  ('email.fromName', '"CollabAi"', 'email', 'Email sender name'),
  ('email.fromEmail', '"noreply@collabai.software"', 'email', 'Email sender address'),
  ('system.maintenanceMode', 'false', 'system', 'Put platform in maintenance mode'),
  ('system.allowSignups', 'true', 'system', 'Allow new user registrations'),
  ('system.requireEmailVerification', 'false', 'system', 'Require email verification'),
  ('system.sessionTimeout', '7', 'system', 'Session timeout in days')
ON CONFLICT (key) DO NOTHING;

-- Migration 2: User Invites Table
CREATE TABLE IF NOT EXISTS public.user_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  role text DEFAULT 'user',
  invited_by uuid REFERENCES public.profiles(id),
  token text UNIQUE NOT NULL DEFAULT replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  used_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage invites" ON public.user_invites;
CREATE POLICY "Admins can manage invites"
  ON public.user_invites FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE INDEX IF NOT EXISTS idx_user_invites_email ON public.user_invites(email);
CREATE INDEX IF NOT EXISTS idx_user_invites_token ON public.user_invites(token);
CREATE INDEX IF NOT EXISTS idx_user_invites_expires_at ON public.user_invites(expires_at);

-- Migration 3: User Status Columns on Profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS deactivated_at timestamptz;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS deactivated_by uuid REFERENCES public.profiles(id);

CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON public.profiles(is_active);

UPDATE public.profiles SET is_active = true WHERE is_active IS NULL;
