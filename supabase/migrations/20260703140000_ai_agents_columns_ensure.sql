-- Ensure ai_agents has columns required by the current app
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS avatar TEXT;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS welcome_message TEXT;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS conversation_starters JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS usage_count INTEGER DEFAULT 0;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS tool_code_interpreter BOOLEAN DEFAULT false;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS tool_file_search BOOLEAN DEFAULT false;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS tool_web_search BOOLEAN DEFAULT false;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS tool_image_generation BOOLEAN DEFAULT false;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS tool_mcp BOOLEAN DEFAULT false;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS mcp_server_ids UUID[] DEFAULT '{}';
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS tools_config JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS rag_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.ai_agents ADD COLUMN IF NOT EXISTS graphify_enabled BOOLEAN NOT NULL DEFAULT false;
