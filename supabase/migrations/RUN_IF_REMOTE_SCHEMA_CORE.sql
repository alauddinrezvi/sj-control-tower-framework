-- ============================================================================
-- ONE-TIME FIX: Core missing RPC + tables on remote Supabase
-- Run in Supabase Dashboard → SQL Editor when you see:
--   PGRST202: get_user_permissions
--   PGRST205: organization_integrations
--   PGRST205: mfa_enrollment_status
-- Idempotent — safe to run more than once.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) get_user_permissions + has_permission (works with legacy user_roles enum)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_user_permissions(_user_id UUID)
RETURNS SETOF TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'permissions'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_roles' AND column_name = 'role_id'
  ) THEN
    RETURN QUERY
    SELECT DISTINCT p.key::TEXT
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON rp.role_id = ur.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = _user_id AND ur.role_id IS NOT NULL
    UNION
    SELECT DISTINCT p.key::TEXT
    FROM public.user_roles ur
    JOIN public.roles r ON (
      (ur.role = 'admin' AND r.slug = 'admin') OR
      (ur.role = 'moderator' AND r.slug = 'manager') OR
      (ur.role = 'user' AND r.slug = 'member')
    )
    JOIN public.role_permissions rp ON rp.role_id = r.id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = _user_id
      AND ur.role_id IS NULL
      AND r.tenant_id = '00000000-0000-0000-0000-000000000001';
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = _user_id AND ur.role = 'admin'
  ) THEN
    RETURN QUERY SELECT unnest(ARRAY[
      'settings.admin', 'users.admin', 'integrations.admin', 'ai_hub.admin',
      'knowledge.admin', 'settings.view', 'users.view', 'integrations.view', 'ai_hub.view'
    ]::TEXT[]);
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = _user_id AND ur.role = 'moderator'
  ) THEN
    RETURN QUERY SELECT unnest(ARRAY[
      'settings.view', 'users.view', 'integrations.view', 'ai_hub.view'
    ]::TEXT[]);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.has_permission(_user_id UUID, _permission_key TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.get_user_permissions(_user_id) AS perm
    WHERE perm = _permission_key
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_user_permissions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2) MFA policy + enrollment tracking
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.mfa_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
  required BOOLEAN NOT NULL DEFAULT false,
  grace_period_days INTEGER NOT NULL DEFAULT 7,
  allowed_factors TEXT[] NOT NULL DEFAULT ARRAY['totp'],
  trust_idp_mfa BOOLEAN NOT NULL DEFAULT false,
  updated_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id)
);

CREATE TABLE IF NOT EXISTS public.mfa_enrollment_status (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  enrolled BOOLEAN NOT NULL DEFAULT false,
  enrolled_at TIMESTAMPTZ,
  grace_period_ends_at TIMESTAMPTZ,
  last_reminded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.mfa_policies (tenant_id, required, grace_period_days, allowed_factors, trust_idp_mfa)
VALUES ('00000000-0000-0000-0000-000000000001', false, 7, ARRAY['totp'], false)
ON CONFLICT (tenant_id) DO NOTHING;

ALTER TABLE public.mfa_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mfa_enrollment_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mfa_policies_select_authenticated" ON public.mfa_policies;
CREATE POLICY "mfa_policies_select_authenticated" ON public.mfa_policies
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "mfa_policies_no_direct_write" ON public.mfa_policies;
CREATE POLICY "mfa_policies_no_direct_write" ON public.mfa_policies
  FOR ALL TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS "mfa_enrollment_status_select_own" ON public.mfa_enrollment_status;
CREATE POLICY "mfa_enrollment_status_select_own" ON public.mfa_enrollment_status
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "mfa_enrollment_status_update_own" ON public.mfa_enrollment_status;
CREATE POLICY "mfa_enrollment_status_update_own" ON public.mfa_enrollment_status
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "mfa_enrollment_status_insert_own" ON public.mfa_enrollment_status;
CREATE POLICY "mfa_enrollment_status_insert_own" ON public.mfa_enrollment_status
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3) Integration hub (minimal — organization_integrations + dependencies)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS public.integration_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  icon TEXT,
  display_order INTEGER DEFAULT 0,
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.integration_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.integration_categories(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  logo_url TEXT,
  docs_url TEXT,
  auth_type TEXT NOT NULL DEFAULT 'api_key',
  oauth_config JSONB,
  is_available BOOLEAN DEFAULT true,
  is_coming_soon BOOLEAN DEFAULT false,
  is_beta BOOLEAN DEFAULT false,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.organization_integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES public.integration_providers(id) ON DELETE CASCADE,
  enabled BOOLEAN DEFAULT false,
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  connection_status TEXT DEFAULT 'disconnected',
  connection_message TEXT,
  last_tested_at TIMESTAMPTZ,
  last_sync_at TIMESTAMPTZ,
  oauth_tokens JSONB,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.organization_integrations
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_organization_integrations_provider
  ON public.organization_integrations(provider_id);
CREATE INDEX IF NOT EXISTS idx_organization_integrations_user_id
  ON public.organization_integrations(user_id);

ALTER TABLE public.organization_integrations
  DROP CONSTRAINT IF EXISTS organization_integrations_organization_id_provider_id_key;

ALTER TABLE public.organization_integrations
  DROP CONSTRAINT IF EXISTS organization_integrations_user_provider_key;

ALTER TABLE public.organization_integrations
  ADD CONSTRAINT organization_integrations_user_provider_key
  UNIQUE (user_id, provider_id);

ALTER TABLE public.integration_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_integrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Categories are viewable by authenticated users" ON public.integration_categories;
CREATE POLICY "Categories are viewable by authenticated users"
  ON public.integration_categories FOR SELECT TO authenticated
  USING (enabled = true OR public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Providers are viewable by authenticated users" ON public.integration_providers;
CREATE POLICY "Providers are viewable by authenticated users"
  ON public.integration_providers FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can view own integrations" ON public.organization_integrations;
CREATE POLICY "Users can view own integrations"
  ON public.organization_integrations FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own integrations" ON public.organization_integrations;
CREATE POLICY "Users can create own integrations"
  ON public.organization_integrations FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own integrations" ON public.organization_integrations;
CREATE POLICY "Users can update own integrations"
  ON public.organization_integrations FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own integrations" ON public.organization_integrations;
CREATE POLICY "Users can delete own integrations"
  ON public.organization_integrations FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all integrations" ON public.organization_integrations;
CREATE POLICY "Admins can view all integrations"
  ON public.organization_integrations FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Admins can manage all integrations" ON public.organization_integrations;
CREATE POLICY "Admins can manage all integrations"
  ON public.organization_integrations FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

INSERT INTO public.integration_categories (name, slug, description, icon, display_order, enabled)
VALUES ('AI', 'ai', 'AI providers', 'Brain', 1, true)
ON CONFLICT (slug) DO NOTHING;

NOTIFY pgrst, 'reload schema';
