-- ============================================================================
-- ONE-TIME FIX: agent_knowledge_files + embedding_status on files
-- ============================================================================
-- Run in Supabase Dashboard -> SQL Editor when you see:
--   PGRST205 Could not find the table 'public.agent_knowledge_files'
--
-- Safe to re-run (uses IF NOT EXISTS / OR REPLACE).
-- ============================================================================

-- embedding_status on knowledge base manager files table (if present)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'files'
  ) THEN
    ALTER TABLE public.files
      ADD COLUMN IF NOT EXISTS embedding_status TEXT NOT NULL DEFAULT 'none';

    ALTER TABLE public.files
      DROP CONSTRAINT IF EXISTS files_embedding_status_check;

    ALTER TABLE public.files
      ADD CONSTRAINT files_embedding_status_check
      CHECK (embedding_status IN ('none', 'pending', 'processing', 'completed', 'failed'));

    CREATE INDEX IF NOT EXISTS idx_files_embedding_status
    ON public.files (embedding_status)
    WHERE deleted_at IS NULL;
  END IF;
END $$;

-- agent <-> knowledge file links
CREATE TABLE IF NOT EXISTS public.agent_knowledge_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES public.ai_agents(id) ON DELETE CASCADE,
  file_id UUID NOT NULL,
  added_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (agent_id, file_id)
);

-- FK to files when that table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'files'
  )
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_schema = 'public'
      AND table_name = 'agent_knowledge_files'
      AND constraint_name = 'agent_knowledge_files_file_id_fkey'
  ) THEN
    ALTER TABLE public.agent_knowledge_files
      ADD CONSTRAINT agent_knowledge_files_file_id_fkey
      FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_agent_knowledge_files_agent
ON public.agent_knowledge_files (agent_id);

CREATE INDEX IF NOT EXISTS idx_agent_knowledge_files_file
ON public.agent_knowledge_files (file_id);

ALTER TABLE public.agent_knowledge_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read agent knowledge file links" ON public.agent_knowledge_files;
CREATE POLICY "Users can read agent knowledge file links"
ON public.agent_knowledge_files FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Users can manage own agent knowledge file links" ON public.agent_knowledge_files;
DROP POLICY IF EXISTS "Admins manage agent knowledge file links" ON public.agent_knowledge_files;

CREATE POLICY "Users can manage own agent knowledge file links"
ON public.agent_knowledge_files FOR ALL
TO authenticated
USING (
  added_by = auth.uid()
  OR (
    EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'has_role'
    )
    AND public.has_role(auth.uid(), 'admin')
  )
)
WITH CHECK (
  added_by = auth.uid()
  OR (
    EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'has_role'
    )
    AND public.has_role(auth.uid(), 'admin')
  )
);

-- Extend embedding queue entity types (optional)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'embedding_queue'
  ) THEN
    ALTER TABLE public.embedding_queue
      DROP CONSTRAINT IF EXISTS embedding_queue_entity_type_check;

    ALTER TABLE public.embedding_queue
      ADD CONSTRAINT embedding_queue_entity_type_check
      CHECK (entity_type IN ('file', 'entry', 'meeting', 'user_file', 'knowledge_base_file'));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.cleanup_knowledge_base_file_embeddings(target_file_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.embeddings
  WHERE entity_type = 'knowledge_base_file'
    AND entity_id = target_file_id;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'embedding_queue'
  ) THEN
    DELETE FROM public.embedding_queue
    WHERE entity_type = 'knowledge_base_file'
      AND entity_id = target_file_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_knowledge_base_file_embeddings(UUID) TO authenticated;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
