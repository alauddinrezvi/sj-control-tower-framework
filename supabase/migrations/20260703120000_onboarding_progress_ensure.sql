-- Ensure onboarding_progress exists for user onboarding wizard
CREATE TABLE IF NOT EXISTS public.onboarding_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  current_step INTEGER NOT NULL DEFAULT 1,
  steps_completed JSONB NOT NULL DEFAULT '{}'::jsonb,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_onboarding_progress_user ON public.onboarding_progress(user_id);

ALTER TABLE public.onboarding_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own onboarding progress" ON public.onboarding_progress;
CREATE POLICY "Users can view own onboarding progress"
  ON public.onboarding_progress FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage own onboarding progress" ON public.onboarding_progress;
CREATE POLICY "Users can manage own onboarding progress"
  ON public.onboarding_progress FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all onboarding progress" ON public.onboarding_progress;
CREATE POLICY "Admins can view all onboarding progress"
  ON public.onboarding_progress FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Allow users to add themselves to a department during onboarding (only if table exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'department_users'
  ) THEN
    DROP POLICY IF EXISTS "Users can join departments for themselves" ON public.department_users;
    CREATE POLICY "Users can join departments for themselves"
      ON public.department_users FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;
