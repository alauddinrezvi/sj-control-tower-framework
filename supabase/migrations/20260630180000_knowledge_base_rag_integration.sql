-- Knowledge Base RAG integration: agent file links + embedding status on files table.

ALTER TABLE public.files
  ADD COLUMN IF NOT EXISTS embedding_status TEXT NOT NULL DEFAULT 'none'
    CHECK (embedding_status IN ('none', 'pending', 'processing', 'completed', 'failed'));

CREATE INDEX IF NOT EXISTS idx_files_embedding_status
ON public.files (embedding_status)
WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS public.agent_knowledge_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL,
  file_id UUID NOT NULL REFERENCES public.files(id) ON DELETE CASCADE,
  added_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (agent_id, file_id)
);

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
CREATE POLICY "Users can manage own agent knowledge file links"
ON public.agent_knowledge_files FOR ALL
TO authenticated
USING (added_by = auth.uid())
WITH CHECK (added_by = auth.uid());

-- Extend embedding queue to support knowledge base manager files.
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

  DELETE FROM public.embedding_queue
  WHERE entity_type = 'knowledge_base_file'
    AND entity_id = target_file_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_knowledge_base_file_embeddings(UUID) TO authenticated;
