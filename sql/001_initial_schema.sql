-- Tetra Agent — Supabase Schema Migration
-- Run this in the Supabase SQL Editor after creating your project
-- Version: 1.0.0
-- Date: 2026-03-23

-- ============================================================
-- TABLES
-- ============================================================

-- Clients
CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  email TEXT,
  phone TEXT,
  language TEXT DEFAULT 'he' CHECK (language IN ('he', 'en')),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Projects
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  token TEXT UNIQUE NOT NULL DEFAULT gen_random_uuid()::TEXT,
  github_repo TEXT,
  phase TEXT DEFAULT '0' CHECK (phase IN ('0','1','2','3','4','5')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active','paused','completed','archived')),
  intake_system_prompt TEXT,
  site_url TEXT,
  vercel_project_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Entries (every voice interaction)
CREATE TABLE IF NOT EXISTS entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  intent TEXT NOT NULL CHECK (intent IN ('intake','feedback','feature','bug','content')),
  mode TEXT NOT NULL CHECK (mode IN ('intake','feedback')),
  raw_transcript TEXT NOT NULL,
  structured_output JSONB,
  ai_conversation JSONB,
  coverage JSONB,
  status TEXT DEFAULT 'new' CHECK (status IN (
    'new','processing','action_items_generated','executing',
    'pr_open','merged','deployed','rejected','error'
  )),
  github_pr_url TEXT,
  github_pr_number INTEGER,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Action Items
CREATE TABLE IF NOT EXISTS action_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id UUID REFERENCES entries(id) ON DELETE CASCADE NOT NULL,
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  type TEXT NOT NULL CHECK (type IN ('code','content','design','config','investigation')),
  status TEXT DEFAULT 'pending' CHECK (status IN (
    'pending','executing','pr_open','merged','deployed','rejected','skipped'
  )),
  execution_result JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Conversation State (multi-turn intake sessions)
CREATE TABLE IF NOT EXISTS conversation_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL UNIQUE,
  messages JSONB NOT NULL DEFAULT '[]'::JSONB,
  layer_coverage JSONB DEFAULT '{
    "person": 0,
    "business_reality": 0,
    "brand_identity": 0,
    "digital_presence": 0,
    "vision_growth": 0
  }'::JSONB,
  session_count INTEGER DEFAULT 0,
  last_session_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Agent Executions (tracks GitHub Action runs)
CREATE TABLE IF NOT EXISTS agent_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id UUID REFERENCES entries(id) ON DELETE CASCADE,
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  github_run_id TEXT,
  github_run_url TEXT,
  prompt TEXT NOT NULL,
  status TEXT DEFAULT 'triggered' CHECK (status IN (
    'triggered','running','completed','failed'
  )),
  result JSONB,
  started_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_entries_project ON entries(project_id);
CREATE INDEX idx_entries_status ON entries(status);
CREATE INDEX idx_entries_created ON entries(created_at DESC);
CREATE INDEX idx_action_items_project ON action_items(project_id);
CREATE INDEX idx_action_items_status ON action_items(status);
CREATE INDEX idx_action_items_entry ON action_items(entry_id);
CREATE INDEX idx_projects_token ON projects(token);
CREATE INDEX idx_projects_client ON projects(client_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_agent_executions_entry ON agent_executions(entry_id);

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clients_updated_at
  BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER conversation_state_updated_at
  BEFORE UPDATE ON conversation_state
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE action_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_executions ENABLE ROW LEVEL SECURITY;

-- Service role (n8n, backend) gets full access
CREATE POLICY "Service role full access" ON clients
  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access" ON projects
  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access" ON entries
  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access" ON action_items
  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access" ON conversation_state
  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access" ON agent_executions
  FOR ALL USING (auth.role() = 'service_role');

-- Anon role (web app) can only read projects by token and insert entries
CREATE POLICY "Anon read projects by token" ON projects
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon insert entries" ON entries
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon read own entries" ON entries
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon read conversation state" ON conversation_state
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon update conversation state" ON conversation_state
  FOR UPDATE USING (auth.role() = 'anon');

CREATE POLICY "Anon insert conversation state" ON conversation_state
  FOR INSERT WITH CHECK (auth.role() = 'anon');

-- ============================================================
-- SEED DATA: Test project for pilot
-- ============================================================

INSERT INTO clients (name, slug, email, language)
VALUES ('Test Client', 'test-client', 'test@tetra.dev', 'en');

INSERT INTO projects (
  client_id,
  name,
  slug,
  github_repo,
  phase,
  intake_system_prompt
)
SELECT
  c.id,
  'Test Project',
  'test-project',
  'shay-griever/tetra-test-project',
  '4',
  'You are a test intake assistant for Tetra. Respond briefly to test messages.'
FROM clients c WHERE c.slug = 'test-client';

-- Print the generated token for the test project
DO $$
DECLARE
  proj_token TEXT;
BEGIN
  SELECT token INTO proj_token FROM projects WHERE slug = 'test-project';
  RAISE NOTICE 'Test project token: %', proj_token;
  RAISE NOTICE 'Test URL will be: https://voice.tetra.dev/p/%', proj_token;
END $$;
