-- ============================================================================
-- DUMMY DATA - Single consolidated seed file for SJ Control Tower
-- ============================================================================
-- Run AFTER all migrations are applied (supabase db push).
--
-- Prerequisites:
--   1. At least one user in auth.users (sign up via the app or Supabase Dashboard)
--   2. All migrations applied
--
-- Usage:
--   Supabase SQL Editor: paste and run this entire file
--   psql: psql "$DATABASE_URL" -f supabase/seed/dummy-data.sql
--   CLI:  npm run db:seed
--
-- Safe to re-run - all INSERTs use ON CONFLICT DO NOTHING or conditional logic.
-- ============================================================================

-- >>> BEGIN: 00-platform-core.sql

-- ============================================================
-- SEED: Platform Core
-- Profiles, roles, app_modules, system_settings, notifications
-- Run FIRST — other seeds reference clients & modules.
-- ============================================================

-- 0. Guard: skip everything when no auth users exist
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users LIMIT 1) THEN
    RAISE EXCEPTION 'No auth.users rows — sign up at least one user before seeding.';
  END IF;
END $$;

-- 0.5 Grant admin role to designated admin email (if user exists in auth.users)
-- Create this user in Supabase Dashboard → Authentication → Users → Add user, then run seeds.
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role FROM auth.users WHERE email = 'zia.khan@sjinnovation.com'
ON CONFLICT (user_id, role) DO NOTHING;

-- 1. Clients (5 already exist from test-data migration; add 3 more)
-- Guard: clients table has no UNIQUE on email, so use conditional inserts
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'rachel@designstudio.co') THEN
    INSERT INTO public.clients (name, email, company, phone, status, metadata) VALUES
      ('Rachel Green', 'rachel@designstudio.co', 'Design Studio Co', '+1-555-0201', 'active',
       '{"notes":"Creative agency, monthly retainer","industry":"design"}');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'tom@finedge.io') THEN
    INSERT INTO public.clients (name, email, company, phone, status, metadata) VALUES
      ('Tom Bradley', 'tom@finedge.io', 'FinEdge Solutions', '+1-555-0202', 'active',
       '{"notes":"Fintech startup, Series A","industry":"finance"}');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'lisa@healthsync.com') THEN
    INSERT INTO public.clients (name, email, company, phone, status, metadata) VALUES
      ('Lisa Nguyen', 'lisa@healthsync.com', 'HealthSync Inc', '+1-555-0203', 'prospect',
       '{"notes":"Healthcare SaaS, evaluating platform","industry":"healthcare"}');
  END IF;
END $$;

-- 2. App modules (enable all 10 modules for demo)
INSERT INTO public.app_modules (name, slug, description, icon, category, is_core, is_active, sort_order) VALUES
  ('Platform Core',    'platform',      'Auth, profiles, navigation, shared infra',       'Shield',       'core',          true,  true, 1),
  ('Actions',          'actions',       'Task management with streams & categories',      'CheckSquare',  'operations',    false, true, 2),
  ('EOS',              'eos',           'Entrepreneurial Operating System toolkit',        'Target',       'operations',    false, true, 3),
  ('Meetings',         'meetings',      'Meeting scheduling, agendas & takeaways',        'Calendar',     'operations',    false, true, 4),
  ('Knowledge Base',   'knowledge',     'Company knowledge, docs & vector search',        'BookOpen',     'intelligence',  false, true, 5),
  ('Projects',         'projects',      'Project tracking, milestones & billing',         'FolderKanban', 'business',      false, true, 6),
  ('Business Dev',     'business-dev',  'Deals pipeline, contacts & communications',      'TrendingUp',   'business',      false, true, 7),
  ('Productivity',     'productivity',  'Team productivity metrics & process docs',       'BarChart3',    'operations',    false, true, 8),
  ('Admin',            'admin',         'Platform administration & configuration',        'Settings',     'core',          true,  true, 9),
  ('AI Agents',        'ai-agents',     'AI agents, chat, and usage tracking',            'Bot',          'intelligence',  false, true, 10)
ON CONFLICT (slug) DO NOTHING;

-- 3. System settings
INSERT INTO public.system_settings (category, key, value, description) VALUES
  ('general',  'company_name',       '"SJ Innovation"',                      'Organization display name'),
  ('general',  'timezone',           '"America/New_York"',                   'Default timezone'),
  ('general',  'fiscal_year_start',  '"01-01"',                              'Fiscal year start MM-DD'),
  ('eos',      'current_quarter',    '"Q1 2026"',                            'Active EOS quarter'),
  ('eos',      'vto_version',        '1',                                    'VTO document version'),
  ('meetings', 'default_duration',   '30',                                   'Default meeting duration minutes'),
  ('meetings', 'auto_create_tasks',  'true',                                 'Auto-convert action-item takeaways to tasks')
ON CONFLICT (category, key) DO NOTHING;

-- 4. Feature flags (ensure all demo flags enabled)
INSERT INTO public.app_config (key, value, category, description) VALUES
  ('features.enableEOS',              'true', 'features', 'Enable EOS module'),
  ('features.enableMeetings',         'true', 'features', 'Enable Meetings module'),
  ('features.enableProjects',         'true', 'features', 'Enable Projects module'),
  ('features.enableBusinessDev',      'true', 'features', 'Enable Business Development module'),
  ('features.enableProductivity',     'true', 'features', 'Enable Productivity module'),
  ('features.enableActions',          'true', 'features', 'Enable Actions module')
ON CONFLICT (key) DO NOTHING;

-- 5. Sample notifications for first user
-- Note: type must be one of: info, success, warning, error
INSERT INTO public.notifications (user_id, title, message, type, link, is_read) VALUES
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'Welcome to Control Tower', 'Your platform is ready. Explore the modules from the sidebar.',
   'info', '/dashboard', false),
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'New EOS Quarter Started', 'Q1 2026 is now active. Review your OKRs and rocks.',
   'info', '/eos/okrs', false),
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'Task Due Tomorrow', 'Client onboarding checklist is due Jan 28.',
   'warning', '/actions/tasks', false);

-- 6. Sample activity logs
-- Note: Uses COALESCE to handle missing clients gracefully
INSERT INTO public.activity_logs (user_id, action, resource_type, resource_id, details) VALUES
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'login', 'session', gen_random_uuid(), '{"method":"email"}'),
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'create', 'client', (SELECT id::text FROM clients WHERE email = 'john.doe@example.com' LIMIT 1),
   '{"client_name":"Acme Corp"}'),
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'update', 'deal', gen_random_uuid(), '{"field":"stage","from":"lead","to":"discovery"}');

-- 7. Sample feedback
-- Note: status must be one of: pending, reviewed, resolved, closed
INSERT INTO public.feedback (user_id, type, subject, message, rating, status) VALUES
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'feature', 'Dark mode support', 'Would love a dark mode toggle in settings.', 4, 'pending'),
  ((SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
   'bug', 'Calendar not loading on Safari', 'Meetings calendar blank on Safari 18.', 2, 'pending');

-- <<< END: 00-platform-core.sql

-- >>> BEGIN: 01-actions.sql

-- ============================================================
-- SEED: Actions Module
-- Task streams, categories, tasks, comments, contributors
-- ============================================================

-- 1. Task streams
INSERT INTO public.task_streams (name, slug, description, color, is_archived, created_by) VALUES
  ('Engineering',    'engineering',    'Software development & technical tasks',  '#3B82F6', false, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Marketing',      'marketing',     'Marketing campaigns & content',           '#10B981', false, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Operations',     'operations',    'Day-to-day operational tasks',            '#F59E0B', false, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Client Success', 'client-success','Client onboarding & support',             '#8B5CF6', false, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Sales',          'sales',         'Sales pipeline & outreach',               '#EF4444', false, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1))
ON CONFLICT (slug) DO NOTHING;

-- 2. Task categories
INSERT INTO public.task_categories (name, slug, color, sort_order) VALUES
  ('Bug Fix',       'bug-fix',       '#EF4444', 1),
  ('Feature',       'feature',       '#3B82F6', 2),
  ('Improvement',   'improvement',   '#10B981', 3),
  ('Documentation', 'documentation', '#F59E0B', 4),
  ('Research',      'research',      '#8B5CF6', 5),
  ('Admin',         'admin-task',    '#6B7280', 6)
ON CONFLICT (slug) DO NOTHING;

-- 3. Tasks (20 sample tasks across streams)
DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  s_eng UUID := (SELECT id FROM task_streams WHERE slug = 'engineering');
  s_mkt UUID := (SELECT id FROM task_streams WHERE slug = 'marketing');
  s_ops UUID := (SELECT id FROM task_streams WHERE slug = 'operations');
  s_cs  UUID := (SELECT id FROM task_streams WHERE slug = 'client-success');
  s_sal UUID := (SELECT id FROM task_streams WHERE slug = 'sales');
  c_bug UUID := (SELECT id FROM task_categories WHERE slug = 'bug-fix');
  c_feat UUID := (SELECT id FROM task_categories WHERE slug = 'feature');
  c_imp UUID := (SELECT id FROM task_categories WHERE slug = 'improvement');
  c_doc UUID := (SELECT id FROM task_categories WHERE slug = 'documentation');
  c_res UUID := (SELECT id FROM task_categories WHERE slug = 'research');
  c_adm UUID := (SELECT id FROM task_categories WHERE slug = 'admin-task');
  cl_acme UUID := (SELECT id FROM clients WHERE email = 'john.doe@example.com' LIMIT 1);
  cl_tech UUID := (SELECT id FROM clients WHERE email = 'jane.smith@techstart.io' LIMIT 1);
BEGIN
  -- Guard: skip if tasks already seeded
  IF EXISTS (SELECT 1 FROM tasks WHERE slug = 'implement-sso-entra') THEN
    RAISE NOTICE 'Tasks already seeded — skipping.';
    RETURN;
  END IF;

  INSERT INTO tasks (title, slug, description, status, priority, due_date, assigned_to, created_by, stream_id, category_id, client_id, position) VALUES
    -- Engineering stream
    ('Implement SSO with Microsoft Entra', 'implement-sso-entra', 'Set up SAML/OIDC flow for enterprise clients.', 'in_progress', 'high', NOW() + INTERVAL '7 days', u1, u1, s_eng, c_feat, NULL, 1),
    ('Fix date picker timezone bug', 'fix-datepicker-tz', 'Dates shift by 1 day in UTC-negative timezones.', 'todo', 'urgent', NOW() + INTERVAL '2 days', u1, u1, s_eng, c_bug, NULL, 2),
    ('Upgrade React Router to v7', 'upgrade-react-router-v7', 'Migrate from v6 to v7 for improved type safety.', 'todo', 'medium', NOW() + INTERVAL '14 days', u1, u1, s_eng, c_imp, NULL, 3),
    ('Add CSV export to productivity', 'csv-export-productivity', 'Users need to export weekly reports as CSV.', 'todo', 'medium', NOW() + INTERVAL '10 days', u1, u1, s_eng, c_feat, NULL, 4),
    ('Write API rate-limit documentation', 'api-rate-limit-docs', 'Document the edge function rate limits.', 'completed', 'low', NOW() - INTERVAL '3 days', u1, u1, s_eng, c_doc, NULL, 5),

    -- Marketing stream
    ('Draft Q1 newsletter', 'draft-q1-newsletter', 'Product updates newsletter for Q1 2026.', 'in_progress', 'medium', NOW() + INTERVAL '5 days', u1, u1, s_mkt, c_doc, NULL, 1),
    ('Update landing page copy', 'update-landing-copy', 'Refresh hero section with new value props.', 'todo', 'low', NOW() + INTERVAL '12 days', u1, u1, s_mkt, c_imp, NULL, 2),
    ('Research competitor pricing', 'research-competitor-pricing', 'Compare pricing tiers of top 5 competitors.', 'completed', 'medium', NOW() - INTERVAL '5 days', u1, u1, s_mkt, c_res, NULL, 3),

    -- Operations stream
    ('Set up monitoring alerts', 'setup-monitoring-alerts', 'Configure Supabase alerts for DB and edge function errors.', 'todo', 'high', NOW() + INTERVAL '3 days', u1, u1, s_ops, c_adm, NULL, 1),
    ('Review and renew SSL certificates', 'renew-ssl-certs', 'Custom domain SSL certs expire Feb 15.', 'todo', 'urgent', NOW() + INTERVAL '14 days', u1, u1, s_ops, c_adm, NULL, 2),
    ('Quarterly access review', 'quarterly-access-review', 'Audit user roles and module permissions.', 'in_progress', 'medium', NOW() + INTERVAL '7 days', u1, u1, s_ops, c_adm, NULL, 3),
    ('Update disaster recovery plan', 'update-dr-plan', 'Document RTO/RPO for all modules.', 'todo', 'low', NOW() + INTERVAL '21 days', u1, u1, s_ops, c_doc, NULL, 4),

    -- Client Success stream
    ('Onboard Acme Corp', 'onboard-acme-corp', 'Complete onboarding checklist for Acme Corp.', 'in_progress', 'high', NOW() + INTERVAL '4 days', u1, u1, s_cs, c_adm, cl_acme, 1),
    ('Prepare TechStart training materials', 'techstart-training', 'Build slide deck and walkthrough for TechStart team.', 'todo', 'medium', NOW() + INTERVAL '8 days', u1, u1, s_cs, c_doc, cl_tech, 2),
    ('Schedule quarterly review — Enterprise Solutions', 'qbr-enterprise-solutions', 'Set up QBR meeting and prepare metrics.', 'todo', 'medium', NOW() + INTERVAL '14 days', u1, u1, s_cs, c_adm, NULL, 3),
    ('Resolve Acme billing discrepancy', 'acme-billing-fix', 'Invoice #1042 shows wrong hours. Reconcile.', 'todo', 'high', NOW() + INTERVAL '2 days', u1, u1, s_cs, c_bug, cl_acme, 4),

    -- Sales stream
    ('Follow up with FinEdge after demo', 'followup-finedge', 'Send proposal and ROI calculator.', 'todo', 'high', NOW() + INTERVAL '1 day', u1, u1, s_sal, c_adm, NULL, 1),
    ('Prepare case study — Acme Corp', 'case-study-acme', 'Write up success story for marketing.', 'in_progress', 'medium', NOW() + INTERVAL '10 days', u1, u1, s_sal, c_doc, cl_acme, 2),
    ('Cold outreach list — Healthcare SaaS', 'outreach-healthcare', 'Build prospect list of 50 healthcare SaaS companies.', 'todo', 'low', NOW() + INTERVAL '14 days', u1, u1, s_sal, c_res, NULL, 3),
    ('Update CRM deal stages', 'update-crm-stages', 'Align internal deal stages with HubSpot pipeline.', 'completed', 'low', NOW() - INTERVAL '7 days', u1, u1, s_sal, c_adm, NULL, 4);
END $$;

-- 4. Task comments
DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  t_sso UUID := (SELECT id FROM tasks WHERE slug = 'implement-sso-entra' LIMIT 1);
  t_onboard UUID := (SELECT id FROM tasks WHERE slug = 'onboard-acme-corp' LIMIT 1);
BEGIN
  IF t_sso IS NOT NULL THEN
    INSERT INTO task_comments (task_id, user_id, content) VALUES
      (t_sso, u1, 'Microsoft Entra docs: https://learn.microsoft.com/en-us/entra/identity/. Need to register app first.'),
      (t_sso, u1, 'App registration done. Client ID is in Vault. Moving to SAML config next.');
  END IF;
  IF t_onboard IS NOT NULL THEN
    INSERT INTO task_comments (task_id, user_id, content) VALUES
      (t_onboard, u1, 'Sent welcome email. Awaiting user list from Acme IT team.'),
      (t_onboard, u1, 'Received 12 users. Creating accounts now.');
  END IF;
END $$;

-- 5. Stream members (first user owns all streams)
INSERT INTO public.task_stream_members (stream_id, user_id, role)
SELECT s.id, u.id, 'owner'
FROM task_streams s
CROSS JOIN (SELECT id FROM auth.users ORDER BY created_at LIMIT 1) u
ON CONFLICT DO NOTHING;

-- <<< END: 01-actions.sql

-- >>> BEGIN: 02-eos.sql

-- ============================================================
-- SEED: EOS Module
-- Pods, VTO, OKRs, key results, issues, scorecards,
-- accountability chart, GWC assessments
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  pod_eng UUID;
  pod_sales UUID;
  pod_ops UUID;
  okr1 UUID;
  okr2 UUID;
  okr3 UUID;
  okr4 UUID;
  okr5 UUID;
  okr6 UUID;
  okr7 UUID;
  kr1 UUID;
  kr2 UUID;
  sc1 UUID;
  chart_id UUID;
  resp_ceo UUID;
BEGIN

-- 1. Pods
INSERT INTO eos_pods (name, description, color, lead_id, is_active)
VALUES
  ('Engineering', 'Product development & infrastructure', '#3B82F6', u1, true),
  ('Sales & BD',  'Revenue generation & partnerships',    '#10B981', u1, true),
  ('Operations',  'HR, finance & internal processes',     '#F59E0B', u1, true)
ON CONFLICT DO NOTHING;

SELECT id INTO pod_eng  FROM eos_pods WHERE name = 'Engineering'  LIMIT 1;
SELECT id INTO pod_sales FROM eos_pods WHERE name = 'Sales & BD' LIMIT 1;
SELECT id INTO pod_ops  FROM eos_pods WHERE name = 'Operations'  LIMIT 1;

-- 2. VTO sections
INSERT INTO eos_vto (section, title, content, sort_order, updated_by) VALUES
  ('core_values', 'Core Values', '["Ownership","Transparency","Customer Obsession","Continuous Learning","Ship Fast"]'::jsonb, 1, u1),
  ('core_focus', 'Core Focus', '{"purpose":"Empower teams with intelligent operations management","niche":"Mid-market agencies & consultancies"}'::jsonb, 2, u1),
  ('ten_year_target', '10-Year Target', '{"target":"Become the #1 AI-powered operations platform for professional services firms globally."}'::jsonb, 3, u1),
  ('marketing_strategy', 'Marketing Strategy', '{"target_market":"Agencies, consultancies, and professional services firms with 20–200 employees","differentiators":["AI-native from day one","All-in-one ops platform","EOS built-in"],"proven_process":"Discover → Implement → Optimize → Scale"}'::jsonb, 4, u1),
  ('three_year_picture', '3-Year Picture', '{"revenue":"$5M ARR","employees":30,"capabilities":["Full EOS suite","Marketplace integrations","White-label option"]}'::jsonb, 5, u1),
  ('one_year_plan', '1-Year Plan', '{"revenue":"$500K ARR","goals":["Launch all 10 modules","50 paying customers","SOC 2 certification"]}'::jsonb, 6, u1),
  ('quarterly_rocks', 'Q1 2026 Rocks', '["Complete QA across all modules","Onboard 10 pilot customers","Ship AI agent marketplace","Achieve 99.9% uptime"]'::jsonb, 7, u1),
  ('issues_list', 'Issues List', '["Hiring senior backend engineer","Need SOC 2 readiness assessment","Meeting transcription accuracy below target"]'::jsonb, 8, u1)
ON CONFLICT (section) DO UPDATE SET content = EXCLUDED.content, updated_by = EXCLUDED.updated_by;

-- 3. OKRs (active Q2 2026)
INSERT INTO okrs (title, description, owner_id, status, quarter, start_date, end_date, progress, pod_id, created_by, okr_type, year, is_archived)
VALUES
  ('Ship all 10 modules to production', 'Complete development, QA, and data seeding for all platform modules.', u1, 'active', 'Q2 2026', '2026-04-01', '2026-06-30', 65, pod_eng, u1, 'company', 2026, false),
  ('Acquire 10 pilot customers', 'Sign paid pilot agreements with 10 mid-market agencies.', u1, 'active', 'Q2 2026', '2026-04-01', '2026-06-30', 20, pod_sales, u1, 'team', 2026, false),
  ('Establish operational excellence', 'Implement SOPs, OKR tracking, and team cadences.', u1, 'on_track', 'Q2 2026', '2026-04-01', '2026-06-30', 40, pod_ops, u1, 'team', 2026, false),
  ('Improve platform reliability to 99.9%', 'Reduce downtime, add monitoring, and fix top-10 bugs.', u1, 'at_risk', 'Q2 2026', '2026-04-01', '2026-06-30', 30, pod_eng, u1, 'company', 2026, false);

-- OKRs (closed / archived from Q1 2026)
INSERT INTO okrs (title, description, owner_id, status, quarter, start_date, end_date, progress, pod_id, created_by, okr_type, year, is_archived)
VALUES
  ('Launch MVP platform', 'Deliver core modules (auth, dashboard, CRM, meetings) to production.', u1, 'completed', 'Q1 2026', '2026-01-01', '2026-03-31', 100, pod_eng, u1, 'company', 2026, true),
  ('Close first 3 paying customers', 'Convert pilot users to paid subscriptions.', u1, 'completed', 'Q1 2026', '2026-01-01', '2026-03-31', 100, pod_sales, u1, 'team', 2026, true),
  ('Set up team cadences', 'Establish L10 meetings, scorecards, and weekly check-ins.', u1, 'closed', 'Q1 2026', '2026-01-01', '2026-03-31', 85, pod_ops, u1, 'team', 2026, true);

-- Personal OKRs
INSERT INTO okrs (title, description, owner_id, status, quarter, start_date, end_date, progress, pod_id, created_by, okr_type, year, is_archived)
VALUES
  ('Complete AI/ML certification', 'Finish Stanford online AI course and apply learnings to product.', u1, 'active', 'Q2 2026', '2026-04-01', '2026-06-30', 55, null, u1, 'personal', 2026, false);

SELECT id INTO okr1 FROM okrs WHERE title = 'Ship all 10 modules to production' LIMIT 1;
SELECT id INTO okr2 FROM okrs WHERE title = 'Acquire 10 pilot customers' LIMIT 1;
SELECT id INTO okr3 FROM okrs WHERE title = 'Establish operational excellence' LIMIT 1;
SELECT id INTO okr4 FROM okrs WHERE title = 'Improve platform reliability to 99.9%' LIMIT 1;
SELECT id INTO okr5 FROM okrs WHERE title = 'Launch MVP platform' LIMIT 1;
SELECT id INTO okr6 FROM okrs WHERE title = 'Close first 3 paying customers' LIMIT 1;
SELECT id INTO okr7 FROM okrs WHERE title = 'Complete AI/ML certification' LIMIT 1;

-- 4. Key Results
INSERT INTO okr_key_results (okr_id, title, metric_type, current_value, target_value, start_value, unit, status, owner_id, sort_order) VALUES
  (okr1, 'Modules with development complete',     'number',     8,  10, 0, 'modules',  'on_track',    u1, 1),
  (okr1, 'QA checklist items tested',             'number',     45, 85, 0, 'items',    'behind',      u1, 2),
  (okr1, 'Demo seed data coverage',               'percentage', 60, 100, 0, '%',       'on_track',    u1, 3),
  (okr2, 'Discovery calls completed',             'number',     6,  30, 0, 'calls',    'on_track',    u1, 1),
  (okr2, 'Proposals sent',                        'number',     2,  15, 0, 'proposals','behind',      u1, 2),
  (okr2, 'Signed pilot agreements',               'number',     0,  10, 0, 'pilots',   'not_started', u1, 3),
  (okr3, 'SOPs documented',                       'number',     4,  12, 0, 'SOPs',     'on_track',    u1, 1),
  (okr3, 'Weekly L10 completion rate',             'percentage', 80, 95, 0, '%',        'on_track',    u1, 2),
  (okr3, 'Team NPS score',                        'number',     72, 80, 0, 'NPS',      'on_track',    u1, 3),
  (okr4, 'P0 bugs resolved',                      'number',     3,  10, 0, 'bugs',     'at_risk',     u1, 1),
  (okr4, 'Uptime percentage',                     'percentage', 99.2, 99.9, 98, '%',   'behind',      u1, 2),
  (okr4, 'Monitoring alerts configured',           'number',     5,  20, 0, 'alerts',   'on_track',    u1, 3),
  -- Closed OKR key results
  (okr5, 'Core modules deployed',                 'number',     5,  5, 0, 'modules',   'completed',   u1, 1),
  (okr5, 'Auth & SSO working',                    'number',     1,  1, 0, 'milestone', 'completed',   u1, 2),
  (okr6, 'Customers converted',                   'number',     3,  3, 0, 'customers', 'completed',   u1, 1),
  (okr6, 'MRR achieved',                          'currency',   4500, 3000, 0, 'USD',  'completed',   u1, 2),
  -- Personal OKR key results
  (okr7, 'Course modules completed',              'number',     6,  12, 0, 'modules',  'on_track',    u1, 1),
  (okr7, 'AI features prototyped',                'number',     2,  4, 0, 'prototypes','on_track',    u1, 2);

-- 5. OKR check-ins
SELECT id INTO kr1 FROM okr_key_results WHERE title = 'Modules with development complete' LIMIT 1;
SELECT id INTO kr2 FROM okr_key_results WHERE title = 'Discovery calls completed' LIMIT 1;

IF kr1 IS NOT NULL THEN
  INSERT INTO okr_check_ins (okr_id, key_result_id, user_id, previous_value, new_value, confidence, notes) VALUES
    (okr1, kr1, u1, 6, 8, 'high', 'Completed Actions categories + Productivity charts this week.'),
    (okr1, kr1, u1, 5, 6, 'high', 'Knowledge Base modularization done. Projects finalized.');
END IF;

IF kr2 IS NOT NULL THEN
  INSERT INTO okr_check_ins (okr_id, key_result_id, user_id, previous_value, new_value, confidence, notes) VALUES
    (okr2, kr2, u1, 4, 6, 'medium', 'Two calls with healthcare SaaS prospects. Good pipeline.');
END IF;

-- 6. Issues
INSERT INTO eos_issues (title, description, status, priority, category, pod_id, assigned_to, reported_by, source) VALUES
  ('Need dedicated QA resource', 'Currently relying on Lovable QA. Need a human QA engineer for edge cases.', 'open', 'high', 'people', pod_eng, u1, u1, 'meeting'),
  ('Meeting transcript accuracy < 85%', 'Zoom transcript provider returning noisy text. Affects AI summary quality.', 'in_progress', 'medium', 'system', pod_eng, u1, u1, 'manual'),
  ('SOC 2 readiness assessment overdue', 'Was supposed to start in January. Need to hire auditor.', 'open', 'critical', 'process', pod_ops, u1, u1, 'manual'),
  ('Sales collateral not up to date', 'Pitch deck still references v1 features. Need refresh.', 'open', 'medium', 'process', pod_sales, u1, u1, 'meeting'),
  ('Onboarding flow too many steps', 'New users drop off at step 4 of 7. Simplify.', 'solved', 'high', 'process', pod_eng, u1, u1, 'ai');

-- 7. Scorecards
INSERT INTO eos_scorecards (name, description, owner_id, frequency, is_active, created_by)
VALUES ('Engineering Weekly Scorecard', 'Key engineering health metrics tracked weekly.', u1, 'weekly', true, u1)
RETURNING id INTO sc1;

INSERT INTO eos_scorecard_metrics (scorecard_id, name, description, metric_type, target_value, current_value, unit, goal_direction, week_of, status, sort_order) VALUES
  (sc1, 'Deploy frequency',    'Number of production deploys this week',  'number',     5,  4, 'deploys',  'higher_is_better', '2026-01-27', 'on_track',       1),
  (sc1, 'Build success rate',  'CI build pass percentage',                'percentage', 95, 97, '%',       'higher_is_better', '2026-01-27', 'on_track',       2),
  (sc1, 'Open bug count',      'Total unresolved bugs',                   'number',     10, 14, 'bugs',    'lower_is_better',  '2026-01-27', 'needs_attention', 3),
  (sc1, 'Sprint velocity',     'Story points completed',                  'number',     40, 38, 'points',  'higher_is_better', '2026-01-27', 'on_track',       4),
  (sc1, 'Code review turnaround', 'Average hours to first review',        'number',     4,  3, 'hours',    'lower_is_better',  '2026-01-27', 'on_track',       5);

-- 8. Accountability chart
INSERT INTO accountability_charts (name, description, is_current, version, published_by, created_by)
VALUES ('SJ Innovation Org Chart Q1 2026', 'Current accountability structure.', true, 1, u1, u1)
RETURNING id INTO chart_id;

INSERT INTO accountability_responsibilities (chart_id, user_id, role_title, department, responsibilities, sort_order) VALUES
  (chart_id, u1, 'CEO / Visionary',  'Leadership',   '["Set vision & strategy","Manage key relationships","Final sign-off on product direction"]'::jsonb, 1)
RETURNING id INTO resp_ceo;

INSERT INTO accountability_responsibilities (chart_id, user_id, role_title, department, reports_to, responsibilities, sort_order) VALUES
  (chart_id, u1, 'VP Engineering',   'Engineering',  resp_ceo, '["Technical architecture","Sprint planning","Code quality & reviews"]'::jsonb, 2),
  (chart_id, u1, 'VP Sales',         'Sales & BD',   resp_ceo, '["Pipeline management","Close deals","Customer success"]'::jsonb, 3),
  (chart_id, u1, 'VP Operations',    'Operations',   resp_ceo, '["HR & hiring","Finance & billing","Internal process optimization"]'::jsonb, 4);

-- 9. GWC assessment for CEO role
INSERT INTO gwc_assessments (responsibility_id, assessor_id, gets_it, wants_it, has_capacity, notes, assessment_date)
VALUES (resp_ceo, u1, true, true, true, 'Founder-led, fully aligned.', '2026-01-15');

END $$;

-- <<< END: 02-eos.sql

-- >>> BEGIN: 03-meetings.sql

-- ============================================================
-- SEED: Meetings Module
-- Series, meetings, participants, agenda items, takeaways
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  cl_acme UUID := (SELECT id FROM clients WHERE email = 'john.doe@example.com' LIMIT 1);
  cl_tech UUID := (SELECT id FROM clients WHERE email = 'jane.smith@techstart.io' LIMIT 1);
  series_l10 UUID;
  series_standup UUID;
  m1 UUID; m2 UUID; m3 UUID; m4 UUID; m5 UUID; m6 UUID;
  ag1 UUID; ag2 UUID;
BEGIN

-- 1. Meeting series
INSERT INTO meeting_series (title, description, recurrence_rule, duration_minutes, organizer_id, default_agenda, is_active)
VALUES
  ('Weekly L10 Meeting', 'EOS Level 10 leadership meeting every Monday at 9 AM.', 'RRULE:FREQ=WEEKLY;BYDAY=MO', 90, u1,
   '[{"title":"Segue (good news)","duration":5},{"title":"Scorecard review","duration":10},{"title":"Rock review","duration":10},{"title":"Customer/employee headlines","duration":5},{"title":"To-do review","duration":5},{"title":"IDS (issues)","duration":50},{"title":"Conclude","duration":5}]'::jsonb, true),
  ('Daily Standup', 'Quick daily sync for engineering team.', 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', 15, u1,
   '[{"title":"Yesterday","duration":5},{"title":"Today","duration":5},{"title":"Blockers","duration":5}]'::jsonb, true);

SELECT id INTO series_l10   FROM meeting_series WHERE title = 'Weekly L10 Meeting' LIMIT 1;
SELECT id INTO series_standup FROM meeting_series WHERE title = 'Daily Standup' LIMIT 1;

-- 2. Meetings (mix of past + upcoming)
INSERT INTO meetings (title, description, scheduled_at, duration_minutes, provider, status, organizer_id, client_id, meeting_type, series_id, is_recurring) VALUES
  -- Past L10 meetings
  ('L10 Meeting — Jan 13', 'Weekly leadership meeting.', '2026-01-13 09:00:00-05', 90, 'zoom', 'completed', u1, NULL, 'l10', series_l10, true),
  ('L10 Meeting — Jan 20', 'Weekly leadership meeting.', '2026-01-20 09:00:00-05', 90, 'zoom', 'completed', u1, NULL, 'l10', series_l10, true),
  ('L10 Meeting — Jan 27', 'Weekly leadership meeting.', '2026-01-27 09:00:00-05', 90, 'zoom', 'completed', u1, NULL, 'l10', series_l10, true),
  -- Upcoming L10
  ('L10 Meeting — Feb 3', 'Weekly leadership meeting.',  '2026-02-03 09:00:00-05', 90, 'zoom', 'scheduled', u1, NULL, 'l10', series_l10, true),
  -- Client meetings
  ('Acme Corp — Quarterly Review', 'Q1 business review with Acme leadership.', '2026-02-05 14:00:00-05', 60, 'google_meet', 'scheduled', u1, cl_acme, 'client_review', NULL, false),
  ('TechStart — Product Demo', 'Demo of new AI features for TechStart team.', '2026-01-28 11:00:00-05', 45, 'zoom', 'completed', u1, cl_tech, 'demo', NULL, false);

SELECT id INTO m1 FROM meetings WHERE title = 'L10 Meeting — Jan 13' LIMIT 1;
SELECT id INTO m2 FROM meetings WHERE title = 'L10 Meeting — Jan 20' LIMIT 1;
SELECT id INTO m3 FROM meetings WHERE title = 'L10 Meeting — Jan 27' LIMIT 1;
SELECT id INTO m4 FROM meetings WHERE title = 'L10 Meeting — Feb 3' LIMIT 1;
SELECT id INTO m5 FROM meetings WHERE title = 'Acme Corp — Quarterly Review' LIMIT 1;
SELECT id INTO m6 FROM meetings WHERE title = 'TechStart — Product Demo' LIMIT 1;

-- 3. Participants (upsert to avoid duplicate key on re-seed)
IF m3 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended)
  VALUES (m3, u1, 'organizer', 'accepted', true)
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET
    role = EXCLUDED.role, rsvp_status = EXCLUDED.rsvp_status, attended = EXCLUDED.attended;
END IF;
IF m5 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, email, name, role, rsvp_status)
  VALUES
    (m5, u1, NULL, NULL, 'organizer', 'accepted'),
    (m5, NULL, 'john.doe@example.com', 'John Doe', 'attendee', 'accepted')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET
    email = EXCLUDED.email, name = EXCLUDED.name, role = EXCLUDED.role, rsvp_status = EXCLUDED.rsvp_status;
END IF;
IF m6 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, email, name, role, rsvp_status, attended)
  VALUES
    (m6, u1, NULL, NULL, 'presenter', 'accepted', true),
    (m6, NULL, 'jane.smith@techstart.io', 'Jane Smith', 'attendee', 'accepted', true)
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET
    email = EXCLUDED.email, name = EXCLUDED.name, role = EXCLUDED.role, rsvp_status = EXCLUDED.rsvp_status, attended = EXCLUDED.attended;
END IF;

-- 4. Agenda items (L10 Jan 27 meeting)
IF m3 IS NOT NULL THEN
  INSERT INTO meeting_agenda_items (meeting_id, title, description, duration_minutes, presenter_id, sort_order, is_completed, created_by) VALUES
    (m3, 'Segue — Good News',      'Share personal/professional wins.',            5,  u1, 1, true, u1),
    (m3, 'Scorecard Review',        'Review weekly KPIs.',                          10, u1, 2, true, u1),
    (m3, 'Rock Review',             'Status update on Q1 rocks.',                   10, u1, 3, true, u1),
    (m3, 'Customer Headlines',      'Notable customer events this week.',           5,  u1, 4, true, u1),
    (m3, 'To-Do Review',            'Check off completed to-dos from last week.',   5,  u1, 5, true, u1),
    (m3, 'IDS — Issues',            'Identify, Discuss, Solve.',                    50, u1, 6, true, u1),
    (m3, 'Conclude',                'Rate meeting 1-10, review to-dos.',            5,  u1, 7, true, u1);

  SELECT id INTO ag1 FROM meeting_agenda_items WHERE meeting_id = m3 AND title = 'IDS — Issues' LIMIT 1;
  SELECT id INTO ag2 FROM meeting_agenda_items WHERE meeting_id = m3 AND title = 'To-Do Review' LIMIT 1;
END IF;

-- 5. Takeaways
IF m3 IS NOT NULL THEN
  INSERT INTO meeting_takeaways (meeting_id, agenda_item_id, content, takeaway_type, assigned_to, due_date, is_completed, created_by) VALUES
    (m3, ag1, 'Hire QA contractor for February sprint.',                  'action_item', u1, '2026-02-07', false, u1),
    (m3, ag1, 'Approved: Move to Anthropic Claude as primary AI model.',  'decision',    NULL, NULL, false, u1),
    (m3, ag1, 'Need to scope SOC 2 assessment before end of Q1.',        'follow_up',   u1, '2026-03-15', false, u1),
    (m3, ag2, 'All 5 to-dos from last week completed.',                  'note',        NULL, NULL, false, u1);
END IF;

-- 6. Transcript for TechStart demo
-- Note: meeting_transcripts has two possible schemas depending on migration order:
--   V1 (20260101): full_transcript, summary, speaker_count, etc.
--   V2 (20260201): content, ai_summary, source, duration_seconds, etc.
-- We try V2 first (module-level), then V1 (legacy), to support both.
IF m6 IS NOT NULL THEN
  BEGIN
    INSERT INTO meeting_transcripts (meeting_id, content, source, word_count, duration_seconds, ai_summary) VALUES
      (m6,
       'Presenter: Welcome everyone to the product demo. Today I will walk you through our new AI features including the knowledge base semantic search and the agent framework. Jane: Thanks, we are excited to see what you have built. Presenter: Let me start with the knowledge base. You can upload documents and our system automatically chunks and embeds them for semantic search...',
       'zoom', 280, 2700,
       'Demo covered AI knowledge base with semantic search, agent framework with custom system prompts, and productivity analytics. TechStart expressed strong interest in the knowledge base feature. Action: Send pricing proposal by Friday.');
  EXCEPTION WHEN undefined_column THEN
    BEGIN
      INSERT INTO meeting_transcripts (meeting_id, full_transcript, word_count, summary) VALUES
        (m6,
         'Presenter: Welcome everyone to the product demo. Today I will walk you through our new AI features including the knowledge base semantic search and the agent framework. Jane: Thanks, we are excited to see what you have built. Presenter: Let me start with the knowledge base. You can upload documents and our system automatically chunks and embeds them for semantic search...',
         280,
         'Demo covered AI knowledge base with semantic search, agent framework with custom system prompts, and productivity analytics. TechStart expressed strong interest in the knowledge base feature. Action: Send pricing proposal by Friday.');
    EXCEPTION WHEN undefined_column THEN
      RAISE NOTICE 'meeting_transcripts: schema mismatch — skipping transcript seed.';
    END;
  END;
END IF;

-- 7. Meeting assignments
IF m5 IS NOT NULL AND cl_acme IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m5, 'client', cl_acme, u1);
END IF;

END $$;

-- <<< END: 03-meetings.sql

-- >>> BEGIN: 03b-meetings-extended.sql

-- ============================================================
-- SEED: Meetings Module (Extended V2)
-- Comprehensive mock data for all V2 meetings tables:
--   meetings, meeting_series, meeting_participants,
--   meeting_external_participants, meeting_agenda_items,
--   meeting_takeaways, meeting_transcripts, meeting_files,
--   meeting_categorizations, meeting_assignments,
--   meeting_action_items, meeting_assignment_suggestions,
--   client_meetings, contact_meeting_links
--
-- Run AFTER 03-meetings.sql and 06-business-dev.sql
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  -- Clients
  cl_acme    UUID := (SELECT id FROM clients WHERE email = 'john.doe@example.com' LIMIT 1);
  cl_tech    UUID := (SELECT id FROM clients WHERE email = 'jane.smith@techstart.io' LIMIT 1);
  cl_fin     UUID := (SELECT id FROM clients WHERE email = 'tom@finedge.io' LIMIT 1);
  cl_health  UUID := (SELECT id FROM clients WHERE email = 'lisa@healthsync.com' LIMIT 1);
  cl_design  UUID := (SELECT id FROM clients WHERE email = 'rachel@designstudio.co' LIMIT 1);
  -- Contacts
  ct_john    UUID := (SELECT id FROM contacts WHERE email = 'john.doe@example.com' LIMIT 1);
  ct_jane    UUID := (SELECT id FROM contacts WHERE email = 'jane.smith@techstart.io' LIMIT 1);
  ct_michael UUID := (SELECT id FROM contacts WHERE email = 'mjohnson@enterprise.com' LIMIT 1);
  ct_tom     UUID := (SELECT id FROM contacts WHERE email = 'tom@finedge.io' LIMIT 1);
  ct_lisa    UUID := (SELECT id FROM contacts WHERE email = 'lisa@healthsync.com' LIMIT 1);
  ct_david   UUID := (SELECT id FROM contacts WHERE email = 'david.kim@cloudbase.dev' LIMIT 1);
  -- Deals
  dl_acme    UUID := (SELECT id FROM deals WHERE slug = 'acme-annual-license' LIMIT 1);
  dl_tech    UUID := (SELECT id FROM deals WHERE slug = 'techstart-ai-package' LIMIT 1);
  dl_fin     UUID := (SELECT id FROM deals WHERE slug = 'finedge-poc' LIMIT 1);
  dl_health  UUID := (SELECT id FROM deals WHERE slug = 'healthsync-eval' LIMIT 1);
  -- Projects (if seeded)
  prj1       UUID := (SELECT id FROM projects LIMIT 1);
  -- Existing series
  series_l10     UUID := (SELECT id FROM meeting_series WHERE title = 'Weekly L10 Meeting' LIMIT 1);
  series_standup UUID := (SELECT id FROM meeting_series WHERE title = 'Daily Standup' LIMIT 1);
  -- New series
  series_retro UUID;
  series_client UUID;
  -- Meetings
  m10 UUID; m11 UUID; m12 UUID; m13 UUID; m14 UUID; m15 UUID;
  m16 UUID; m17 UUID; m18 UUID; m19 UUID; m20 UUID; m21 UUID;
  m22 UUID; m23 UUID; m24 UUID; m25 UUID; m26 UUID; m27 UUID;
  m28 UUID; m29 UUID; m30 UUID;
  -- Agenda items
  ag10 UUID; ag11 UUID; ag12 UUID; ag13 UUID; ag14 UUID; ag15 UUID;
  ag16 UUID; ag17 UUID; ag18 UUID; ag19 UUID; ag20 UUID;
  -- Action items
  ai1 UUID; ai2 UUID; ai3 UUID;
BEGIN

-- =========================
-- 1. Additional Meeting Series
-- =========================
INSERT INTO meeting_series (title, description, recurrence_rule, duration_minutes, organizer_id, default_agenda, is_active) VALUES
  ('Sprint Retrospective', 'Bi-weekly sprint retrospective for engineering.', 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=FR', 60, u1,
   '[{"title":"What went well","duration":15},{"title":"What could improve","duration":15},{"title":"Action items","duration":20},{"title":"Shoutouts","duration":10}]'::jsonb, true),
  ('Monthly Client Check-in', 'Monthly account health review with each active client.', 'RRULE:FREQ=MONTHLY;BYDAY=1TH', 45, u1,
   '[{"title":"Account health","duration":10},{"title":"Project updates","duration":15},{"title":"Upcoming needs","duration":10},{"title":"Open items","duration":10}]'::jsonb, true)
ON CONFLICT DO NOTHING;

SELECT id INTO series_retro  FROM meeting_series WHERE title = 'Sprint Retrospective' LIMIT 1;
SELECT id INTO series_client FROM meeting_series WHERE title = 'Monthly Client Check-in' LIMIT 1;

-- =========================
-- 2. Meetings (30 total: mix of past completed, current in-progress, future scheduled, one cancelled, one no-show)
-- =========================
INSERT INTO meetings (title, description, scheduled_at, duration_minutes, provider, status, organizer_id, client_id, meeting_type, series_id, is_recurring, slug, deal_id, timezone, recurrence_pattern, ai_summary, notes, is_external, efficiency_score) VALUES
  -- Sprint retros (past)
  ('Sprint 21 Retro', 'Sprint 21 retrospective.', '2025-12-19 15:00:00-05', 60, 'google_meet', 'completed', u1, NULL, 'retro', series_retro, true, 'sprint-21-retro', NULL, 'America/New_York', 'biweekly', 'Team velocity improved 15%. CI pipeline issues flagged.', 'Good energy. Team aligned on next sprint goals.', false, 78),
  ('Sprint 22 Retro', 'Sprint 22 retrospective.', '2026-01-02 15:00:00-05', 60, 'google_meet', 'completed', u1, NULL, 'retro', series_retro, true, 'sprint-22-retro', NULL, 'America/New_York', 'biweekly', 'Deployment frequency up. Need better PR review turnaround.', NULL, false, 82),
  ('Sprint 23 Retro', 'Sprint 23 retrospective.', '2026-01-16 15:00:00-05', 60, 'google_meet', 'completed', u1, NULL, 'retro', series_retro, true, 'sprint-23-retro', NULL, 'America/New_York', 'biweekly', 'Record velocity. QA bottleneck resolved.', 'Best sprint of Q1.', false, 91),
  ('Sprint 24 Retro', 'Sprint 24 retrospective — upcoming.', '2026-02-14 15:00:00-05', 60, 'google_meet', 'scheduled', u1, NULL, 'retro', series_retro, true, 'sprint-24-retro', NULL, 'America/New_York', 'biweekly', NULL, NULL, false, NULL),

  -- Client meetings (Acme)
  ('Acme Corp — Kickoff', 'Annual license kickoff and roadmap review.', '2026-01-06 10:00:00-05', 60, 'zoom', 'completed', u1, cl_acme, 'client_review', NULL, false, 'acme-kickoff-jan', dl_acme, 'America/New_York', NULL, 'Reviewed 2026 roadmap. Acme excited about AI features. Agreed on quarterly business reviews.', 'Strong relationship. John wants early access to new features.', false, 85),
  ('Acme Corp — Jan Check-in', 'Monthly check-in with Acme team.', '2026-01-30 14:00:00-05', 45, 'zoom', 'completed', u1, cl_acme, 'client_review', series_client, true, 'acme-checkin-jan', dl_acme, 'America/New_York', 'monthly', 'Usage metrics growing. 3 support tickets resolved. Feature request for advanced reporting.', NULL, false, 88),

  -- Client meetings (TechStart)
  ('TechStart — Discovery Call', 'Initial discovery call with TechStart CEO.', '2025-12-15 11:00:00-05', 30, 'zoom', 'completed', u1, cl_tech, 'discovery', NULL, false, 'techstart-discovery', dl_tech, 'America/New_York', NULL, 'Jane wants AI agent framework for their API docs. Budget approved for Q1.', 'Great call. Jane is technically savvy and understands the value prop.', false, 90),
  ('TechStart — Technical Deep Dive', 'Deep dive into AI agent and knowledge base architecture.', '2026-01-10 13:00:00-05', 90, 'zoom', 'completed', u1, cl_tech, 'demo', NULL, false, 'techstart-deep-dive', dl_tech, 'America/New_York', NULL, 'Walked through embedding pipeline, agent system prompts, and RAG architecture. Jane wants custom fine-tuning.', 'Need to follow up with pricing for custom agent training.', false, 92),
  ('TechStart — Proposal Review', 'Review AI package proposal with TechStart.', '2026-02-12 10:00:00-05', 45, 'zoom', 'scheduled', u1, cl_tech, 'proposal', NULL, false, 'techstart-proposal', dl_tech, 'America/New_York', NULL, NULL, NULL, false, NULL),

  -- Client meetings (FinEdge)
  ('FinEdge — Intro Call', 'Introduction call with FinEdge head of product.', '2026-01-08 16:00:00-05', 30, 'microsoft_teams', 'completed', u1, cl_fin, 'discovery', NULL, false, 'finedge-intro', dl_fin, 'America/New_York', NULL, 'Tom interested in productivity analytics. Wants POC with 10-person team.', NULL, false, 75),
  ('FinEdge — POC Planning', 'Plan the proof-of-concept engagement.', '2026-01-22 15:00:00-05', 45, 'microsoft_teams', 'completed', u1, cl_fin, 'planning', NULL, false, 'finedge-poc-planning', dl_fin, 'America/New_York', NULL, 'Agreed on 4-week POC. FinEdge will provide test data next week. Monthly progress check-ins.', NULL, false, 80),
  ('FinEdge — POC Review', 'Mid-point POC review.', '2026-02-19 15:00:00-05', 45, 'microsoft_teams', 'scheduled', u1, cl_fin, 'review', NULL, false, 'finedge-poc-review', dl_fin, 'America/New_York', NULL, NULL, NULL, false, NULL),

  -- Client meetings (HealthSync)
  ('HealthSync — Cold Outreach Call', 'First call with HealthSync COO.', '2026-01-15 09:00:00-05', 20, 'zoom', 'completed', u1, cl_health, 'discovery', NULL, false, 'healthsync-outreach', dl_health, 'America/New_York', NULL, 'Lisa evaluating platforms for Q2. Interested in operations management. Need to send one-pager.', NULL, true, 65),
  ('HealthSync — Platform Demo', 'Demo of the full platform for HealthSync.', '2026-02-20 11:00:00-05', 60, 'zoom', 'scheduled', u1, cl_health, 'demo', NULL, false, 'healthsync-demo', dl_health, 'America/New_York', NULL, NULL, NULL, true, NULL),

  -- Client meetings (Design Studio)
  ('Design Studio — Creative Review', 'Monthly creative deliverables review.', '2026-01-23 10:00:00-05', 30, 'google_meet', 'completed', u1, cl_design, 'client_review', NULL, false, 'designstudio-review-jan', NULL, 'America/New_York', NULL, 'Reviewed January deliverables. All milestones met. Rachel happy with quality.', 'Consider upselling analytics package.', false, 88),
  ('Design Studio — Feb Review', 'February creative review.', '2026-02-20 10:00:00-05', 30, 'google_meet', 'scheduled', u1, cl_design, 'client_review', NULL, false, 'designstudio-review-feb', NULL, 'America/New_York', NULL, NULL, NULL, false, NULL),

  -- Internal meetings
  ('All-Hands Q1 Kickoff', 'Company-wide Q1 kickoff meeting.', '2026-01-03 09:00:00-05', 90, 'zoom', 'completed', u1, NULL, 'all_hands', NULL, false, 'allhands-q1-kickoff', NULL, 'America/New_York', NULL, 'CEO shared vision for 2026. Revenue targets, product roadmap, and hiring plans. Team Q&A session.', 'Great energy from the team. Several good questions about AI roadmap.', false, 85),
  ('Product Roadmap Workshop', 'Cross-functional roadmap planning session.', '2026-01-14 13:00:00-05', 120, 'google_meet', 'completed', u1, NULL, 'workshop', NULL, false, 'roadmap-workshop-q1', NULL, 'America/New_York', NULL, 'Prioritized 12 features for Q1. AI agents and knowledge base top priorities. Design system refresh deferred to Q2.', 'Good alignment across product, engineering, and design.', false, 90),
  ('Engineering Sync', 'Weekly engineering team sync.', '2026-02-10 09:30:00-05', 30, 'google_meet', 'in_progress', u1, NULL, 'standup', NULL, false, 'eng-sync-feb10', NULL, 'America/New_York', 'weekly', NULL, NULL, false, NULL),

  -- Cancelled / No-show
  ('Enterprise Solutions — Intro', 'Introduction call with Enterprise Solutions VP.', '2026-01-20 14:00:00-05', 30, 'zoom', 'cancelled', u1, NULL, 'discovery', NULL, false, 'enterprise-intro-cancelled', NULL, 'America/New_York', NULL, NULL, 'Michael cancelled — not evaluating tools this quarter.', true, NULL),
  ('CloudBase — Demo', 'Product demo for CloudBase engineering lead.', '2026-02-03 16:00:00-05', 45, 'zoom', 'no_show', u1, NULL, 'demo', NULL, false, 'cloudbase-demo-noshow', NULL, 'America/New_York', NULL, NULL, 'David did not show up. Need to reschedule.', true, NULL)
ON CONFLICT DO NOTHING;

-- Retrieve meeting IDs
SELECT id INTO m10 FROM meetings WHERE slug = 'sprint-21-retro' LIMIT 1;
SELECT id INTO m11 FROM meetings WHERE slug = 'sprint-22-retro' LIMIT 1;
SELECT id INTO m12 FROM meetings WHERE slug = 'sprint-23-retro' LIMIT 1;
SELECT id INTO m13 FROM meetings WHERE slug = 'sprint-24-retro' LIMIT 1;
SELECT id INTO m14 FROM meetings WHERE slug = 'acme-kickoff-jan' LIMIT 1;
SELECT id INTO m15 FROM meetings WHERE slug = 'acme-checkin-jan' LIMIT 1;
SELECT id INTO m16 FROM meetings WHERE slug = 'techstart-discovery' LIMIT 1;
SELECT id INTO m17 FROM meetings WHERE slug = 'techstart-deep-dive' LIMIT 1;
SELECT id INTO m18 FROM meetings WHERE slug = 'techstart-proposal' LIMIT 1;
SELECT id INTO m19 FROM meetings WHERE slug = 'finedge-intro' LIMIT 1;
SELECT id INTO m20 FROM meetings WHERE slug = 'finedge-poc-planning' LIMIT 1;
SELECT id INTO m21 FROM meetings WHERE slug = 'finedge-poc-review' LIMIT 1;
SELECT id INTO m22 FROM meetings WHERE slug = 'healthsync-outreach' LIMIT 1;
SELECT id INTO m23 FROM meetings WHERE slug = 'healthsync-demo' LIMIT 1;
SELECT id INTO m24 FROM meetings WHERE slug = 'designstudio-review-jan' LIMIT 1;
SELECT id INTO m25 FROM meetings WHERE slug = 'designstudio-review-feb' LIMIT 1;
SELECT id INTO m26 FROM meetings WHERE slug = 'allhands-q1-kickoff' LIMIT 1;
SELECT id INTO m27 FROM meetings WHERE slug = 'roadmap-workshop-q1' LIMIT 1;
SELECT id INTO m28 FROM meetings WHERE slug = 'eng-sync-feb10' LIMIT 1;
SELECT id INTO m29 FROM meetings WHERE slug = 'enterprise-intro-cancelled' LIMIT 1;
SELECT id INTO m30 FROM meetings WHERE slug = 'cloudbase-demo-noshow' LIMIT 1;

-- =========================
-- 3. Meeting Participants (internal)
-- =========================
IF m14 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m14, u1, 'organizer', 'accepted', true, '2026-01-05 08:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m15 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m15, u1, 'organizer', 'accepted', true, '2026-01-29 09:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m16 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m16, u1, 'organizer', 'accepted', true, '2025-12-14 10:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m17 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m17, u1, 'presenter', 'accepted', true, '2026-01-09 08:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m19 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m19, u1, 'organizer', 'accepted', true, '2026-01-07 12:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m20 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m20, u1, 'organizer', 'accepted', true, '2026-01-21 10:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m22 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m22, u1, 'organizer', 'accepted', true, '2026-01-14 14:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m24 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m24, u1, 'organizer', 'accepted', true, '2026-01-22 08:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m26 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m26, u1, 'presenter', 'accepted', true, '2026-01-02 10:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;
IF m27 IS NOT NULL THEN
  INSERT INTO meeting_participants (meeting_id, user_id, role, rsvp_status, attended, response_at) VALUES
    (m27, u1, 'organizer', 'accepted', true, '2026-01-13 09:00:00-05')
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END IF;

-- =========================
-- 4. External Participants
-- =========================
IF m14 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m14, 'john.doe@example.com', 'John Doe', 'required', 'accepted'),
    (m14, 'sarah.chen@acmecorp.com', 'Sarah Chen', 'optional', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m15 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m15, 'john.doe@example.com', 'John Doe', 'required', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m16 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m16, 'jane.smith@techstart.io', 'Jane Smith', 'required', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m17 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m17, 'jane.smith@techstart.io', 'Jane Smith', 'required', 'accepted'),
    (m17, 'dev.lead@techstart.io', 'Alex Rivera', 'optional', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m19 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m19, 'tom@finedge.io', 'Tom Bradley', 'required', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m20 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m20, 'tom@finedge.io', 'Tom Bradley', 'required', 'accepted'),
    (m20, 'ops@finedge.io', 'Karen Lee', 'optional', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m22 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m22, 'lisa@healthsync.com', 'Lisa Nguyen', 'required', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m24 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m24, 'rachel@designstudio.co', 'Rachel Green', 'required', 'accepted')
  ON CONFLICT DO NOTHING;
END IF;
IF m29 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m29, 'mjohnson@enterprise.com', 'Michael Johnson', 'required', 'declined')
  ON CONFLICT DO NOTHING;
END IF;
IF m30 IS NOT NULL THEN
  INSERT INTO meeting_external_participants (meeting_id, external_email, external_name, role, status) VALUES
    (m30, 'david.kim@cloudbase.dev', 'David Kim', 'required', 'pending')
  ON CONFLICT DO NOTHING;
END IF;

-- =========================
-- 5. Agenda Items (for completed meetings)
-- =========================

-- Acme Kickoff agenda
IF m14 IS NOT NULL THEN
  INSERT INTO meeting_agenda_items (meeting_id, title, description, duration_minutes, presenter_id, sort_order, is_completed, created_by, assigned_to) VALUES
    (m14, '2026 Roadmap Overview', 'Present product roadmap highlights for 2026.', 20, u1, 1, true, u1, u1),
    (m14, 'Account Health Review', 'Review current usage metrics and satisfaction.', 15, u1, 2, true, u1, NULL),
    (m14, 'Feature Requests', 'Discuss Acme priority feature requests.', 15, u1, 3, true, u1, NULL),
    (m14, 'Action Items & Next Steps', 'Agree on Q1 deliverables and cadence.', 10, u1, 4, true, u1, u1)
  ON CONFLICT DO NOTHING;
  SELECT id INTO ag10 FROM meeting_agenda_items WHERE meeting_id = m14 AND sort_order = 1 LIMIT 1;
  SELECT id INTO ag11 FROM meeting_agenda_items WHERE meeting_id = m14 AND sort_order = 3 LIMIT 1;
  SELECT id INTO ag12 FROM meeting_agenda_items WHERE meeting_id = m14 AND sort_order = 4 LIMIT 1;
END IF;

-- TechStart Deep Dive agenda
IF m17 IS NOT NULL THEN
  INSERT INTO meeting_agenda_items (meeting_id, title, description, duration_minutes, presenter_id, sort_order, is_completed, created_by) VALUES
    (m17, 'Architecture Overview', 'High-level system architecture walkthrough.', 20, u1, 1, true, u1),
    (m17, 'AI Agent Framework Demo', 'Live demo of agent creation and execution.', 25, u1, 2, true, u1),
    (m17, 'Knowledge Base & RAG', 'Embedding pipeline and semantic search demo.', 25, u1, 3, true, u1),
    (m17, 'Q&A and Integration Discussion', 'Technical questions and integration points.', 20, u1, 4, true, u1)
  ON CONFLICT DO NOTHING;
  SELECT id INTO ag13 FROM meeting_agenda_items WHERE meeting_id = m17 AND sort_order = 2 LIMIT 1;
  SELECT id INTO ag14 FROM meeting_agenda_items WHERE meeting_id = m17 AND sort_order = 3 LIMIT 1;
END IF;

-- Sprint 23 Retro agenda
IF m12 IS NOT NULL THEN
  INSERT INTO meeting_agenda_items (meeting_id, title, description, duration_minutes, presenter_id, sort_order, is_completed, created_by) VALUES
    (m12, 'What Went Well', 'Celebrate wins from Sprint 23.', 15, u1, 1, true, u1),
    (m12, 'What Could Improve', 'Identify areas for improvement.', 15, u1, 2, true, u1),
    (m12, 'Action Items', 'Commit to specific improvements.', 20, u1, 3, true, u1),
    (m12, 'Shoutouts', 'Recognize team contributions.', 10, u1, 4, true, u1)
  ON CONFLICT DO NOTHING;
  SELECT id INTO ag15 FROM meeting_agenda_items WHERE meeting_id = m12 AND sort_order = 1 LIMIT 1;
  SELECT id INTO ag16 FROM meeting_agenda_items WHERE meeting_id = m12 AND sort_order = 2 LIMIT 1;
  SELECT id INTO ag17 FROM meeting_agenda_items WHERE meeting_id = m12 AND sort_order = 3 LIMIT 1;
END IF;

-- All-Hands agenda
IF m26 IS NOT NULL THEN
  INSERT INTO meeting_agenda_items (meeting_id, title, description, duration_minutes, presenter_id, sort_order, is_completed, created_by) VALUES
    (m26, 'CEO Vision for 2026', 'Company direction, mission, and goals.', 25, u1, 1, true, u1),
    (m26, 'Revenue & Growth Targets', 'Financial targets and growth strategy.', 20, u1, 2, true, u1),
    (m26, 'Product Roadmap Highlights', 'Key product initiatives for Q1-Q2.', 20, u1, 3, true, u1),
    (m26, 'Hiring & Team Growth', 'Planned hires and team structure changes.', 10, u1, 4, true, u1),
    (m26, 'Q&A', 'Open floor for questions.', 15, u1, 5, true, u1)
  ON CONFLICT DO NOTHING;
  SELECT id INTO ag18 FROM meeting_agenda_items WHERE meeting_id = m26 AND sort_order = 3 LIMIT 1;
END IF;

-- =========================
-- 6. Takeaways
-- =========================

-- Acme Kickoff takeaways
IF m14 IS NOT NULL AND ag10 IS NOT NULL THEN
  INSERT INTO meeting_takeaways (meeting_id, agenda_item_id, content, takeaway_type, assigned_to, due_date, is_completed, priority, status, created_by) VALUES
    (m14, ag10,  'Acme gets early access to AI agent beta in February.',       'decision',    NULL, NULL,         false, 'high',   'open',        u1),
    (m14, ag11,  'Advanced reporting feature prioritized for Q1 sprint 3.',    'decision',    NULL, NULL,         false, 'high',   'open',        u1),
    (m14, ag11,  'Send Acme the feature request form for tracking.',           'action_item', u1,   '2026-01-10', true,  'medium', 'completed',   u1),
    (m14, ag12,  'Schedule quarterly business reviews — next one March 15.',   'action_item', u1,   '2026-03-15', false, 'medium', 'open',        u1),
    (m14, NULL,  'John mentioned potential referral to sister company.',        'note',        NULL, NULL,         false, 'low',    'open',        u1)
  ON CONFLICT DO NOTHING;
END IF;

-- TechStart Deep Dive takeaways
IF m17 IS NOT NULL AND ag13 IS NOT NULL THEN
  INSERT INTO meeting_takeaways (meeting_id, agenda_item_id, content, takeaway_type, assigned_to, due_date, is_completed, priority, status, created_by) VALUES
    (m17, ag13,  'Jane wants custom agent for TechStart API documentation.',   'action_item', u1,   '2026-01-20', false, 'high',   'in_progress', u1),
    (m17, ag14,  'TechStart to provide sample docs for embedding test.',       'follow_up',   NULL, '2026-01-17', true,  'high',   'completed',   u1),
    (m17, ag14,  'Semantic search accuracy exceeds TechStart requirements.',   'note',        NULL, NULL,         false, 'low',    'open',        u1),
    (m17, NULL,  'Approved: Proceed with AI package proposal.',                'decision',    NULL, NULL,         false, 'high',   'open',        u1)
  ON CONFLICT DO NOTHING;
END IF;

-- Sprint 23 Retro takeaways
IF m12 IS NOT NULL AND ag15 IS NOT NULL THEN
  INSERT INTO meeting_takeaways (meeting_id, agenda_item_id, content, takeaway_type, assigned_to, due_date, is_completed, priority, status, created_by) VALUES
    (m12, ag15,  'CI pipeline speed improved 40% after Docker layer caching.', 'note',        NULL, NULL,         false, 'low',    'open',        u1),
    (m12, ag16,  'PR review turnaround still averaging 18 hours.',             'note',        NULL, NULL,         false, 'medium', 'open',        u1),
    (m12, ag17,  'Implement PR review SLA: 4-hour response, 24-hour merge.',  'action_item', u1,   '2026-01-23', true,  'high',   'completed',   u1),
    (m12, ag17,  'Set up automated Slack reminder for stale PRs.',             'action_item', u1,   '2026-01-20', true,  'medium', 'completed',   u1),
    (m12, NULL,  'Shoutout to engineering for record sprint velocity.',        'note',        NULL, NULL,         false, 'low',    'open',        u1)
  ON CONFLICT DO NOTHING;
END IF;

-- All-Hands takeaways
IF m26 IS NOT NULL AND ag18 IS NOT NULL THEN
  INSERT INTO meeting_takeaways (meeting_id, agenda_item_id, content, takeaway_type, assigned_to, due_date, is_completed, priority, status, created_by) VALUES
    (m26, ag18,  'AI agents and knowledge base are top product priorities.',   'decision',    NULL, NULL,         false, 'high',   'open',        u1),
    (m26, ag18,  'Design system refresh deferred to Q2.',                      'decision',    NULL, NULL,         false, 'medium', 'open',        u1),
    (m26, NULL,  'Hiring 3 engineers and 1 designer in Q1.',                   'note',        NULL, NULL,         false, 'medium', 'open',        u1),
    (m26, NULL,  'Revenue target: $2M ARR by end of Q2.',                      'note',        NULL, NULL,         false, 'high',   'open',        u1)
  ON CONFLICT DO NOTHING;
END IF;

-- =========================
-- 7. Transcripts (for key meetings)
-- =========================
IF m14 IS NOT NULL THEN
  BEGIN
    INSERT INTO meeting_transcripts (meeting_id, content, source, word_count, duration_seconds, ai_summary) VALUES
      (m14,
       'Organizer: Good morning John, Sarah! Happy New Year. Let us kick off 2026 with a review of what we have planned. John: Thanks, happy new year to you too. We are excited about the AI features you teased last quarter. Organizer: Absolutely. Let me share the roadmap. First, our AI Agent framework is going into beta in February. You will get early access. Second, we are shipping a redesigned knowledge base with semantic search. John: That sounds great. We have been wanting better search for our internal docs. Sarah: Can we also get advanced reporting? Our VP has been asking for custom dashboards. Organizer: Noted. I will prioritize that for Sprint 3. John: Perfect. Also, I might have a referral for you — our sister company is looking for a similar platform.',
       'zoom', 450, 3600,
       'Reviewed 2026 product roadmap with Acme team. AI agent beta access confirmed for February. Advanced reporting prioritized for Q1. Potential referral to Acme sister company.');
  EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'meeting_transcripts schema mismatch — skipping Acme kickoff transcript.';
  END;
END IF;

IF m17 IS NOT NULL THEN
  BEGIN
    INSERT INTO meeting_transcripts (meeting_id, content, source, word_count, duration_seconds, ai_summary) VALUES
      (m17,
       'Presenter: Welcome Jane and Alex. Today we will deep dive into our AI architecture. Let me start with the high-level system design. We use a microservices approach with Supabase edge functions for AI orchestration. Jane: How do you handle multi-provider support? Presenter: Great question. We have an AI provider routing layer that supports OpenAI, Anthropic, Google Gemini, and Perplexity. Each agent can be configured with a primary and fallback provider. Alex: What about latency? Presenter: Typical response time is under 2 seconds for chat completions. For embedding generation, we batch process and can handle thousands of documents. Jane: Impressive. Can we create custom agents for our API documentation? Presenter: Absolutely. You define a system prompt, choose data sources, and configure the model. The agent gets RAG context from your uploaded documents automatically. Alex: What about the semantic search accuracy? Presenter: Our embedding pipeline uses OpenAI text-embedding-3-small with 1536 dimensions. In our tests, relevance scores above 0.7 consistently return high-quality results. Jane: This exceeds our requirements. Let us proceed with a proposal.',
       'zoom', 680, 5400,
       'Deep technical walkthrough of AI agent framework and knowledge base architecture. TechStart team (Jane Smith CEO, Alex Rivera Dev Lead) impressed with multi-provider support, custom agent creation, and semantic search accuracy. Proceeding to proposal stage.');
  EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'meeting_transcripts schema mismatch — skipping TechStart deep-dive transcript.';
  END;
END IF;

IF m26 IS NOT NULL THEN
  BEGIN
    INSERT INTO meeting_transcripts (meeting_id, content, source, word_count, duration_seconds, ai_summary) VALUES
      (m26,
       'CEO: Good morning everyone. Welcome to our Q1 2026 kickoff. This year is going to be transformative. Our vision is clear: become the leading AI-powered business operations platform. Let me walk through our targets. Revenue goal: $2M ARR by end of Q2. We are currently at $1.2M. Product priorities for Q1: AI agents and knowledge base are number one. We will ship the agent framework beta in February and GA in March. Design system refresh moves to Q2 — we need to focus. On the team side, we are hiring 3 engineers and 1 designer this quarter. Questions? Employee1: What about the EOS module updates? CEO: EOS improvements are in the Q1 roadmap but secondary to AI features. Employee2: Will we have budget for attending conferences? CEO: Yes, we have allocated $50K for conferences and events in H1. Focus on AI and SaaS conferences.',
       'zoom', 520, 5400,
       'Q1 2026 all-hands kickoff. Revenue target $2M ARR by Q2 end (currently $1.2M). AI agents and knowledge base are top product priorities. Hiring 3 engineers + 1 designer. Design system refresh deferred to Q2. $50K conference budget for H1.');
  EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'meeting_transcripts schema mismatch — skipping all-hands transcript.';
  END;
END IF;

-- =========================
-- 8. Meeting Categorizations
-- =========================
IF m14 IS NOT NULL THEN
  INSERT INTO meeting_categorizations (meeting_id, category, meeting_type, confidence, source, created_by, related_clients, tags) VALUES
    (m14, 'client_engagement', 'kickoff',         0.95, 'ai', u1, ('[{"client_id":"' || cl_acme || '","confidence":0.98}]')::jsonb, '["enterprise","renewal","roadmap"]'::jsonb),
    (m14, 'strategic',         'business_review',  0.85, 'ai', u1, NULL, '["quarterly","strategy"]'::jsonb)
  ON CONFLICT (meeting_id, category) DO UPDATE SET meeting_type = EXCLUDED.meeting_type, confidence = EXCLUDED.confidence;
END IF;
IF m17 IS NOT NULL THEN
  INSERT INTO meeting_categorizations (meeting_id, category, meeting_type, confidence, source, created_by, related_clients, tags) VALUES
    (m17, 'sales',             'technical_demo',   0.92, 'ai', u1, ('[{"client_id":"' || cl_tech || '","confidence":0.95}]')::jsonb, '["ai","demo","technical"]'::jsonb),
    (m17, 'client_engagement', 'deep_dive',        0.88, 'ai', u1, NULL, '["architecture","knowledge-base"]'::jsonb)
  ON CONFLICT (meeting_id, category) DO UPDATE SET meeting_type = EXCLUDED.meeting_type, confidence = EXCLUDED.confidence;
END IF;
IF m12 IS NOT NULL THEN
  INSERT INTO meeting_categorizations (meeting_id, category, meeting_type, confidence, source, created_by, tags) VALUES
    (m12, 'internal',          'retrospective',    0.98, 'ai', u1, '["agile","engineering","sprint"]'::jsonb)
  ON CONFLICT (meeting_id, category) DO UPDATE SET meeting_type = EXCLUDED.meeting_type;
END IF;
IF m26 IS NOT NULL THEN
  INSERT INTO meeting_categorizations (meeting_id, category, meeting_type, confidence, source, created_by, tags) VALUES
    (m26, 'internal',          'all_hands',        0.99, 'ai', u1, '["company","strategy","q1"]'::jsonb),
    (m26, 'strategic',         'planning',         0.90, 'ai', u1, '["roadmap","hiring","revenue"]'::jsonb)
  ON CONFLICT (meeting_id, category) DO UPDATE SET meeting_type = EXCLUDED.meeting_type;
END IF;
IF m22 IS NOT NULL THEN
  INSERT INTO meeting_categorizations (meeting_id, category, meeting_type, confidence, source, created_by, related_clients, tags) VALUES
    (m22, 'sales',             'cold_outreach',    0.88, 'ai', u1, ('[{"client_id":"' || cl_health || '","confidence":0.90}]')::jsonb, '["healthcare","outbound"]'::jsonb)
  ON CONFLICT (meeting_id, category) DO UPDATE SET meeting_type = EXCLUDED.meeting_type;
END IF;

-- =========================
-- 9. Meeting Assignments
-- =========================
IF m14 IS NOT NULL AND cl_acme IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m14, 'client', cl_acme, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;
IF m14 IS NOT NULL AND dl_acme IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m14, 'deal', dl_acme, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;
IF m17 IS NOT NULL AND cl_tech IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m17, 'client', cl_tech, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;
IF m17 IS NOT NULL AND dl_tech IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m17, 'deal', dl_tech, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;
IF m19 IS NOT NULL AND cl_fin IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m19, 'client', cl_fin, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;
IF m20 IS NOT NULL AND cl_fin IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m20, 'client', cl_fin, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;
IF m22 IS NOT NULL AND cl_health IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m22, 'client', cl_health, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;
IF m27 IS NOT NULL AND prj1 IS NOT NULL THEN
  INSERT INTO meeting_assignments (meeting_id, entity_type, entity_id, assigned_by) VALUES
    (m27, 'project', prj1, u1)
  ON CONFLICT (meeting_id, entity_type, entity_id) DO NOTHING;
END IF;

-- =========================
-- 10. Client Meetings (many-to-many)
-- =========================
IF m14 IS NOT NULL AND cl_acme IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_acme, m14) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m15 IS NOT NULL AND cl_acme IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_acme, m15) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m16 IS NOT NULL AND cl_tech IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_tech, m16) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m17 IS NOT NULL AND cl_tech IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_tech, m17) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m18 IS NOT NULL AND cl_tech IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_tech, m18) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m19 IS NOT NULL AND cl_fin IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_fin, m19) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m20 IS NOT NULL AND cl_fin IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_fin, m20) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m21 IS NOT NULL AND cl_fin IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_fin, m21) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m22 IS NOT NULL AND cl_health IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_health, m22) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m23 IS NOT NULL AND cl_health IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_health, m23) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m24 IS NOT NULL AND cl_design IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_design, m24) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;
IF m25 IS NOT NULL AND cl_design IS NOT NULL THEN
  INSERT INTO client_meetings (client_id, meeting_id) VALUES (cl_design, m25) ON CONFLICT (client_id, meeting_id) DO NOTHING;
END IF;

-- =========================
-- 11. Contact Meeting Links
-- =========================
IF m14 IS NOT NULL AND ct_john IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_john, m14) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m15 IS NOT NULL AND ct_john IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_john, m15) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m16 IS NOT NULL AND ct_jane IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_jane, m16) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m17 IS NOT NULL AND ct_jane IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_jane, m17) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m18 IS NOT NULL AND ct_jane IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_jane, m18) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m19 IS NOT NULL AND ct_tom IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_tom, m19) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m20 IS NOT NULL AND ct_tom IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_tom, m20) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m22 IS NOT NULL AND ct_lisa IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_lisa, m22) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m29 IS NOT NULL AND ct_michael IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_michael, m29) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;
IF m30 IS NOT NULL AND ct_david IS NOT NULL THEN
  INSERT INTO contact_meeting_links (contact_id, meeting_id) VALUES (ct_david, m30) ON CONFLICT (contact_id, meeting_id) DO NOTHING;
END IF;

-- =========================
-- 12. Meeting Action Items (extracted from transcripts)
-- =========================
IF m14 IS NOT NULL THEN
  INSERT INTO meeting_action_items (meeting_id, text, assignee_id, due_date, priority, status, extracted_from_transcript, extraction_confidence) VALUES
    (m14, 'Grant Acme early access to AI agent beta by February 1.',       u1, '2026-02-01', 'high',   'pending',     true,  0.92),
    (m14, 'Prioritize advanced reporting feature for Sprint 3.',           u1, '2026-02-15', 'high',   'in_progress', true,  0.88),
    (m14, 'Send feature request form to John Doe at Acme.',                u1, '2026-01-10', 'medium', 'completed',   true,  0.95),
    (m14, 'Follow up on Acme sister company referral.',                    u1, '2026-01-20', 'medium', 'pending',     true,  0.72)
  ON CONFLICT DO NOTHING;
END IF;
IF m17 IS NOT NULL THEN
  INSERT INTO meeting_action_items (meeting_id, text, assignee_id, assignee_email, due_date, priority, status, extracted_from_transcript, extraction_confidence) VALUES
    (m17, 'Create custom AI agent prototype for TechStart API docs.',      u1, NULL,                    '2026-01-20', 'high',   'in_progress', true,  0.90),
    (m17, 'TechStart to provide sample documentation for embedding test.', NULL, 'jane.smith@techstart.io', '2026-01-17', 'high',   'completed',   true,  0.85),
    (m17, 'Prepare AI package proposal with pricing.',                     u1, NULL,                    '2026-01-25', 'high',   'pending',     true,  0.93)
  ON CONFLICT DO NOTHING;
END IF;
IF m26 IS NOT NULL THEN
  INSERT INTO meeting_action_items (meeting_id, text, assignee_id, due_date, priority, status, extracted_from_transcript, extraction_confidence) VALUES
    (m26, 'Publish job postings for 3 engineering and 1 design role.',     u1, '2026-01-15', 'high',   'completed',   true,  0.88),
    (m26, 'Finalize Q1 product sprint plan with AI agent priorities.',     u1, '2026-01-10', 'high',   'completed',   true,  0.91),
    (m26, 'Allocate conference budget across AI and SaaS events.',         u1, '2026-01-20', 'medium', 'pending',     true,  0.78)
  ON CONFLICT DO NOTHING;
END IF;

-- =========================
-- 13. Assignment Suggestions (AI-generated, for review)
-- =========================
IF m22 IS NOT NULL AND cl_health IS NOT NULL THEN
  INSERT INTO meeting_assignment_suggestions (meeting_id, suggested_type, suggested_id, confidence, reasoning, review_status) VALUES
    (m22, 'client',  cl_health, 0.92, 'Meeting title mentions HealthSync and participant Lisa Nguyen matches HealthSync COO contact.', 'approved'),
    (m22, 'project', COALESCE(prj1, gen_random_uuid()), 0.45, 'Low confidence: meeting discusses platform evaluation which may relate to onboarding project.', 'pending')
  ON CONFLICT DO NOTHING;
END IF;
IF m29 IS NOT NULL THEN
  INSERT INTO meeting_assignment_suggestions (meeting_id, suggested_type, suggested_id, confidence, reasoning, review_status) VALUES
    (m29, 'client', COALESCE((SELECT id FROM clients WHERE company = 'Enterprise Solutions' LIMIT 1), gen_random_uuid()), 0.78, 'Participant Michael Johnson from Enterprise Solutions matches client record.', 'rejected')
  ON CONFLICT DO NOTHING;
END IF;
IF m24 IS NOT NULL AND cl_design IS NOT NULL THEN
  INSERT INTO meeting_assignment_suggestions (meeting_id, suggested_type, suggested_id, confidence, reasoning, review_status) VALUES
    (m24, 'client', cl_design, 0.96, 'Meeting title "Design Studio — Creative Review" strongly matches Design Studio Co client.', 'approved')
  ON CONFLICT DO NOTHING;
END IF;
IF m19 IS NOT NULL AND dl_fin IS NOT NULL THEN
  INSERT INTO meeting_assignment_suggestions (meeting_id, suggested_type, suggested_id, confidence, reasoning, review_status) VALUES
    (m19, 'client', cl_fin, 0.94, 'FinEdge mentioned in title. Tom Bradley confirmed as FinEdge contact.', 'approved')
  ON CONFLICT DO NOTHING;
END IF;
-- Pending suggestions for upcoming meetings
IF m18 IS NOT NULL AND cl_tech IS NOT NULL THEN
  INSERT INTO meeting_assignment_suggestions (meeting_id, suggested_type, suggested_id, confidence, reasoning, review_status) VALUES
    (m18, 'client', cl_tech, 0.97, 'TechStart in meeting title. Jane Smith is scheduled participant from TechStart.', 'pending')
  ON CONFLICT DO NOTHING;
END IF;
IF m21 IS NOT NULL AND cl_fin IS NOT NULL THEN
  INSERT INTO meeting_assignment_suggestions (meeting_id, suggested_type, suggested_id, confidence, reasoning, review_status) VALUES
    (m21, 'client', cl_fin, 0.95, 'FinEdge POC Review — direct match to FinEdge client.', 'pending')
  ON CONFLICT DO NOTHING;
END IF;
IF m23 IS NOT NULL AND cl_health IS NOT NULL THEN
  INSERT INTO meeting_assignment_suggestions (meeting_id, suggested_type, suggested_id, confidence, reasoning, review_status) VALUES
    (m23, 'client', cl_health, 0.93, 'HealthSync Platform Demo — matches HealthSync Inc client.', 'pending')
  ON CONFLICT DO NOTHING;
END IF;

-- =========================
-- 14. Meeting Files
-- =========================
IF m14 IS NOT NULL THEN
  INSERT INTO meeting_files (meeting_id, provider, file_type, file_name, file_size, is_processed, has_embeddings, processing_status, assignment_status, assignment_confidence, suggested_client_id, assignment_reasoning, metadata) VALUES
    (m14, 'zoom', 'recording',  'acme-kickoff-recording.mp4',     524288000, true,  false, 'completed',   'assigned',       0.95, cl_acme, 'Recording clearly associated with Acme Corp kickoff.',                    '{"duration_seconds":3600,"resolution":"720p"}'::jsonb),
    (m14, 'zoom', 'transcript', 'acme-kickoff-transcript.vtt',    45000,     true,  true,  'completed',   'assigned',       0.95, cl_acme, 'Transcript from Acme Corp kickoff meeting.',                              '{"format":"vtt","language":"en"}'::jsonb),
    (m14, 'zoom', 'chat',       'acme-kickoff-chat.txt',          2300,      true,  false, 'completed',   'assigned',       0.90, cl_acme, 'Chat log from Acme meeting.',                                             '{}'::jsonb)
  ON CONFLICT DO NOTHING;
END IF;
IF m17 IS NOT NULL THEN
  INSERT INTO meeting_files (meeting_id, provider, file_type, file_name, file_size, is_processed, has_embeddings, processing_status, assignment_status, assignment_confidence, suggested_client_id, assignment_reasoning, metadata) VALUES
    (m17, 'zoom', 'recording',  'techstart-deepdive-recording.mp4', 786432000, true,  false, 'completed', 'assigned',       0.93, cl_tech, 'TechStart technical deep dive recording.',                                '{"duration_seconds":5400,"resolution":"1080p"}'::jsonb),
    (m17, 'zoom', 'transcript', 'techstart-deepdive-transcript.vtt', 82000,    true,  true,  'completed', 'assigned',       0.93, cl_tech, 'Transcript from TechStart architecture deep dive.',                       '{"format":"vtt","language":"en"}'::jsonb)
  ON CONFLICT DO NOTHING;
END IF;
-- Unreviewed files (for pending assignments testing)
IF m22 IS NOT NULL THEN
  INSERT INTO meeting_files (meeting_id, provider, file_type, file_name, file_size, is_processed, has_embeddings, processing_status, assignment_status, assignment_confidence, suggested_client_id, assignment_reasoning, metadata) VALUES
    (m22, 'zoom', 'recording',  'healthsync-outreach-recording.mp4', 209715200, true,  false, 'completed', 'pending_review', 0.82, cl_health, 'AI suggests HealthSync based on participant email match.', '{"duration_seconds":1200,"resolution":"720p"}'::jsonb)
  ON CONFLICT DO NOTHING;
END IF;

RAISE NOTICE 'Meetings extended seed completed successfully.';

END $$;

-- <<< END: 03b-meetings-extended.sql

-- >>> BEGIN: 04-knowledge.sql

-- ============================================================
-- SEED: Knowledge Base Module
-- Categories (extend existing), entries, sources, files,
-- common knowledge
-- ============================================================

-- 1. Additional knowledge categories (5 already exist from test-data)
INSERT INTO public.knowledge_categories (name, slug, description, icon, color, sort_order) VALUES
  ('Company Policies',   'company-policies',   'HR policies, code of conduct, benefits',    '📋', '#6366F1', 6),
  ('Client Playbooks',   'client-playbooks',   'Client onboarding and engagement guides',   '🤝', '#EC4899', 7),
  ('Technical Standards', 'technical-standards', 'Coding standards, architecture decisions',  '⚙️', '#14B8A6', 8),
  ('Templates',          'templates',          'Reusable document and email templates',      '📄', '#F97316', 9)
ON CONFLICT (slug) DO NOTHING;

-- 2. Additional knowledge entries
DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  cat_policy UUID := (SELECT id FROM knowledge_categories WHERE slug = 'company-policies' LIMIT 1);
  cat_playbook UUID := (SELECT id FROM knowledge_categories WHERE slug = 'client-playbooks' LIMIT 1);
  cat_tech UUID := (SELECT id FROM knowledge_categories WHERE slug = 'technical-standards' LIMIT 1);
  cat_template UUID := (SELECT id FROM knowledge_categories WHERE slug = 'templates' LIMIT 1);
  cat_bp UUID := (SELECT id FROM knowledge_categories WHERE slug = 'best-practices' LIMIT 1);
BEGIN
  INSERT INTO knowledge_entries (title, slug, content, summary, category_id, author_id, status, tags, view_count) VALUES
    -- Company Policies
    ('Remote Work Policy', 'remote-work-policy',
     E'# Remote Work Policy\n\n## Overview\nAll team members may work remotely. Core hours are 10 AM – 2 PM ET.\n\n## Equipment\n- Company provides laptop, monitor, and headset.\n- $500 annual stipend for home office.\n\n## Communication\n- Slack for async, Zoom for sync.\n- Camera on for client calls.\n\n## Time Tracking\n- Log hours in Productivity module weekly.',
     'Guidelines for remote work including core hours, equipment, and communication.', cat_policy, u1, 'published', ARRAY['policy','remote','hr'], 42),

    ('PTO & Leave Policy', 'pto-leave-policy',
     E'# PTO & Leave Policy\n\n## Allowances\n- 20 days PTO per year (accrued monthly)\n- 5 sick days\n- 10 public holidays\n\n## Process\n1. Submit leave request via Productivity module.\n2. Manager approves within 48 hours.\n3. Handoff notes required for absences > 3 days.',
     'Paid time off allowances and request process.', cat_policy, u1, 'published', ARRAY['policy','pto','leave','hr'], 38),

    -- Client Playbooks
    ('Client Onboarding Playbook', 'client-onboarding-playbook',
     E'# Client Onboarding Playbook\n\n## Phase 1: Discovery (Week 1)\n- Kickoff call with stakeholders\n- Document requirements\n- Set up project in Projects module\n\n## Phase 2: Setup (Week 2)\n- Create client account\n- Configure modules\n- Invite client users\n\n## Phase 3: Training (Week 3-4)\n- Live training sessions\n- Share knowledge base articles\n- First QBR scheduled',
     'Step-by-step guide for onboarding new clients.', cat_playbook, u1, 'published', ARRAY['client','onboarding','process'], 67),

    ('Quarterly Business Review Template', 'qbr-template',
     E'# QBR Template\n\n## Agenda\n1. Recap of deliverables (10 min)\n2. KPI review (15 min)\n3. Wins & challenges (10 min)\n4. Roadmap & next quarter (15 min)\n5. Open discussion (10 min)\n\n## Preparation\n- Pull metrics from Productivity module\n- Gather client feedback\n- Prepare case study highlights',
     'Template for running quarterly business reviews with clients.', cat_template, u1, 'published', ARRAY['template','qbr','client'], 29),

    -- Technical Standards
    ('Git Branching Strategy', 'git-branching-strategy',
     E'# Git Branching Strategy\n\n## Branch Types\n- `main` — production, protected\n- `develop` — integration branch\n- `feature/*` — new features\n- `fix/*` — bug fixes\n- `release/*` — release prep\n\n## Rules\n1. All PRs require 1 approval.\n2. Squash merge to develop.\n3. Release branches merge to main with tag.',
     'Git workflow and branching conventions for the team.', cat_tech, u1, 'published', ARRAY['git','engineering','standards'], 55),

    ('Database Migration Standards', 'database-migration-standards',
     E'# Database Migration Standards\n\n## Naming\n`YYYYMMDD_description.sql`\n\n## Rules\n1. Always use `IF NOT EXISTS` / `ON CONFLICT`.\n2. Include rollback comments.\n3. Never drop columns in production — mark deprecated.\n4. Add RLS policies for every new table.\n5. Test locally with `supabase db reset`.',
     'Standards for writing Supabase migrations.', cat_tech, u1, 'published', ARRAY['database','migration','standards'], 31),

    -- Best Practices
    ('Effective Meeting Guidelines', 'effective-meeting-guidelines',
     E'# Effective Meeting Guidelines\n\n## Before\n- Define purpose & agenda\n- Share materials 24h in advance\n- Invite only necessary participants\n\n## During\n- Start on time, end 5 min early\n- Assign a note-taker\n- Use the IDS framework for issues\n\n## After\n- Send takeaways within 2 hours\n- Convert action items to tasks',
     'Best practices for productive meetings.', cat_bp, u1, 'published', ARRAY['meetings','productivity','best-practices'], 48)
  ON CONFLICT (slug) DO NOTHING;
END $$;

-- 3. Knowledge sources
INSERT INTO public.knowledge_sources (name, source_type, config, is_active, created_by) VALUES
  ('Manual Uploads',    'upload',        '{"max_size_mb":50,"allowed_types":["pdf","docx","md","txt"]}'::jsonb, true,  (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Google Drive Sync', 'google_drive',  '{"folder_id":"","auto_sync":false}'::jsonb,                          false, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Meeting Transcripts', 'meeting',     '{"auto_import":true,"min_duration_minutes":15}'::jsonb,              true,  (SELECT id FROM auth.users ORDER BY created_at LIMIT 1))
ON CONFLICT DO NOTHING;

-- 4. Common knowledge items
INSERT INTO public.common_knowledge (title, content, category, tags, is_active, created_by) VALUES
  ('Company elevator pitch',
   'SJ Innovation builds an AI-powered operations platform for mid-market agencies and consultancies. We help teams manage strategy, execution, and knowledge in one place.',
   'general', ARRAY['pitch','company'], true, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Support hours',
   'Support is available Monday through Friday, 9 AM to 6 PM Eastern. Emergency issues: page the on-call engineer via PagerDuty.',
   'support', ARRAY['support','hours'], true, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)),
  ('Product positioning',
   'Control Tower is the only platform that combines EOS tools, project management, business development CRM, and AI agents in a single interface purpose-built for professional services firms.',
   'product', ARRAY['positioning','product'], true, (SELECT id FROM auth.users ORDER BY created_at LIMIT 1))
ON CONFLICT DO NOTHING;

-- <<< END: 04-knowledge.sql

-- >>> BEGIN: 05-projects.sql

-- ============================================================
-- SEED: Projects Module
-- Statuses, projects, members, milestones, comments, risks,
-- billing, invoices
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  cl_acme UUID := (SELECT id FROM clients WHERE email = 'john.doe@example.com' LIMIT 1);
  cl_tech UUID := (SELECT id FROM clients WHERE email = 'jane.smith@techstart.io' LIMIT 1);
  cl_ent  UUID := (SELECT id FROM clients WHERE email = 'mjohnson@enterprise.com' LIMIT 1);
  cl_fin  UUID := (SELECT id FROM clients WHERE email = 'tom@finedge.io' LIMIT 1);
  st_active UUID;
  st_planning UUID;
  st_completed UUID;
  p1 UUID; p2 UUID; p3 UUID; p4 UUID;
BEGIN

-- 1. Project statuses
INSERT INTO project_statuses (name, slug, color, sort_order, is_active, is_default) VALUES
  ('Planning',    'planning',    '#8B5CF6', 1, true, false),
  ('Active',      'active',      '#3B82F6', 2, true, true),
  ('On Hold',     'on-hold',     '#F59E0B', 3, true, false),
  ('Completed',   'completed',   '#10B981', 4, true, false),
  ('Cancelled',   'cancelled',   '#EF4444', 5, true, false)
ON CONFLICT (slug) DO NOTHING;

SELECT id INTO st_active    FROM project_statuses WHERE slug = 'active'    LIMIT 1;
SELECT id INTO st_planning  FROM project_statuses WHERE slug = 'planning'  LIMIT 1;
SELECT id INTO st_completed FROM project_statuses WHERE slug = 'completed' LIMIT 1;

-- 2. Projects
INSERT INTO projects (name, slug, description, status_id, client_id, owner_id, start_date, end_date, budget, currency, created_by) VALUES
  ('Acme Corp — Platform Rollout', 'acme-platform-rollout',
   'Full platform deployment for Acme Corp including SSO, knowledge base, and EOS setup.',
   st_active, cl_acme, u1, '2026-01-06', '2026-03-31', 45000, 'USD', u1),

  ('TechStart AI Integration', 'techstart-ai-integration',
   'Custom AI agent configuration and knowledge base setup for TechStart team.',
   st_active, cl_tech, u1, '2026-01-20', '2026-02-28', 18000, 'USD', u1),

  ('Enterprise Solutions — QBR Prep', 'enterprise-qbr-prep',
   'Prepare quarterly business review materials and dashboards.',
   st_planning, cl_ent, u1, '2026-02-01', '2026-02-15', 5000, 'USD', u1),

  ('FinEdge — Proof of Concept', 'finedge-poc',
   'Build a proof-of-concept demo with productivity analytics for FinEdge.',
   st_planning, cl_fin, u1, '2026-02-10', '2026-03-10', 12000, 'USD', u1)
ON CONFLICT (slug) DO NOTHING;

SELECT id INTO p1 FROM projects WHERE slug = 'acme-platform-rollout' LIMIT 1;
SELECT id INTO p2 FROM projects WHERE slug = 'techstart-ai-integration' LIMIT 1;
SELECT id INTO p3 FROM projects WHERE slug = 'enterprise-qbr-prep' LIMIT 1;
SELECT id INTO p4 FROM projects WHERE slug = 'finedge-poc' LIMIT 1;

-- 3. Project members
IF p1 IS NOT NULL THEN
  INSERT INTO project_members (project_id, user_id, role) VALUES
    (p1, u1, 'owner') ON CONFLICT DO NOTHING;
END IF;
IF p2 IS NOT NULL THEN
  INSERT INTO project_members (project_id, user_id, role) VALUES
    (p2, u1, 'owner') ON CONFLICT DO NOTHING;
END IF;

-- 4. Milestones
IF p1 IS NOT NULL THEN
  INSERT INTO project_milestones (project_id, title, description, due_date, status, sort_order, created_by) VALUES
    (p1, 'SSO Configuration Complete',       'Microsoft Entra SSO live for Acme.',            '2026-01-31', 'in_progress', 1, u1),
    (p1, 'Knowledge Base Populated',         '50+ articles migrated from Acme wiki.',         '2026-02-14', 'pending',     2, u1),
    (p1, 'EOS Setup & Training',             'VTO, scorecards, and L10 configured.',          '2026-02-28', 'pending',     3, u1),
    (p1, 'Go-Live & Handoff',               'Full team onboarded, support transition.',       '2026-03-31', 'pending',     4, u1);
END IF;
IF p2 IS NOT NULL THEN
  INSERT INTO project_milestones (project_id, title, description, due_date, status, sort_order, created_by) VALUES
    (p2, 'Agent Configuration',              'Custom AI agents deployed and tested.',          '2026-02-07', 'pending', 1, u1),
    (p2, 'Knowledge Base Import',            'TechStart docs imported and embedded.',          '2026-02-14', 'pending', 2, u1),
    (p2, 'User Acceptance Testing',          'TechStart team validates all features.',         '2026-02-21', 'pending', 3, u1),
    (p2, 'Production Launch',                'Go live with TechStart team.',                   '2026-02-28', 'pending', 4, u1);
END IF;

-- 5. Project comments
IF p1 IS NOT NULL THEN
  INSERT INTO project_comments (project_id, user_id, content) VALUES
    (p1, u1, 'Kickoff call went well. Acme IT team is responsive. SSO should be straightforward.'),
    (p1, u1, 'Received Acme''s wiki export (142 articles). Will start migration next week.');
END IF;

-- 6. Project risks
IF p1 IS NOT NULL THEN
  INSERT INTO project_risks (project_id, title, description, severity, status, mitigation, reported_by) VALUES
    (p1, 'SSO certificate expiry', 'Acme''s SAML cert expires in 60 days. Need renewal process.', 'medium', 'open', 'Calendar reminder + auto-renewal setup.', u1),
    (p1, 'Wiki migration data quality', 'Some Acme wiki articles have broken formatting.', 'low', 'mitigated', 'Added markdown cleanup script to migration pipeline.', u1);
END IF;

-- 7. Project billing
IF p1 IS NOT NULL THEN
  INSERT INTO project_billing (project_id, billing_type, rate, total_budget, currency, payment_terms)
  VALUES (p1, 'fixed', NULL, 45000, 'USD', 'Net 30')
  ON CONFLICT (project_id) DO NOTHING;
END IF;
IF p2 IS NOT NULL THEN
  INSERT INTO project_billing (project_id, billing_type, rate, total_budget, currency, payment_terms)
  VALUES (p2, 'hourly', 150, 18000, 'USD', 'Net 15')
  ON CONFLICT (project_id) DO NOTHING;
END IF;

-- 8. Invoices
IF p1 IS NOT NULL THEN
  INSERT INTO project_invoices (project_id, invoice_number, amount, status, due_date, notes, created_by) VALUES
    (p1, 'INV-2026-001', 15000, 'paid',  '2026-01-31', 'Phase 1 deposit — SSO & setup.', u1),
    (p1, 'INV-2026-002', 15000, 'sent',  '2026-02-28', 'Phase 2 — Knowledge Base migration.', u1),
    (p1, 'INV-2026-003', 15000, 'draft', '2026-03-31', 'Phase 3 — EOS setup & go-live.', u1);
END IF;

END $$;

-- <<< END: 05-projects.sql

-- >>> BEGIN: 05b-project-client-access.sql

-- ============================================================
-- SEED: Project Client Access (client portal demo)
-- One demo access for Acme Corp — Platform Rollout.
-- Password: Demo123!
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  p_acme UUID := (SELECT id FROM projects WHERE slug = 'acme-platform-rollout' LIMIT 1);
  m1 UUID;
  acc_id UUID;
  -- Precomputed PBKDF2-SHA256 hash for password "Demo123!" (salt: a1b2c3d4e5f607182930a1b2c3d4e5f6, 100k iterations)
  demo_hash TEXT := 'a1b2c3d4e5f607182930a1b2c3d4e5f6:04b49d1335f5cc6ccb452a9f37512021c48dc40337a5241fc85866cde14c33a7';
  -- Fixed token for stable demo URL: /projects/acme-platform-rollout/client-portal/<token>
  demo_token UUID := 'a1b2c3d4-e5f6-4111-a111-111111111111';
BEGIN

IF p_acme IS NULL THEN
  RAISE NOTICE '05b-project-client-access: No project acme-platform-rollout found. Run 05-projects.sql first.';
  RETURN;
END IF;

-- 1. project_client_access (idempotent: one row per project+email)
INSERT INTO project_client_access (
  project_id, client_email, client_name, password_hash, access_token,
  project_slug, is_active, created_by
) VALUES (
  p_acme,
  'john.doe@example.com',
  'John Doe',
  demo_hash,
  demo_token,
  'acme-platform-rollout',
  true,
  u1
)
ON CONFLICT (project_id, client_email) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  access_token = EXCLUDED.access_token,
  project_slug = EXCLUDED.project_slug,
  is_active = true,
  updated_at = NOW();

SELECT id INTO acc_id FROM project_client_access WHERE project_id = p_acme AND client_email = 'john.doe@example.com' LIMIT 1;

-- 2. project_client_comments (PM comments visible to client) — insert only if none exist
SELECT id INTO m1 FROM project_milestones WHERE project_id = p_acme ORDER BY sort_order LIMIT 1;
IF m1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM project_client_comments WHERE project_id = p_acme LIMIT 1) THEN
  INSERT INTO project_client_comments (project_id, milestone_id, comment_text, is_visible, created_by) VALUES
    (p_acme, m1, 'SSO configuration is on track. We will complete Entra setup by end of month.', true, u1),
    (p_acme, NULL, 'Kickoff summary: Timeline agreed with Acme IT. Next sync Tuesday.', true, u1);
END IF;

-- 3. client_feedback (client-submitted feedback) — insert only if none exist for this project
IF acc_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM client_feedback WHERE project_id = p_acme LIMIT 1) THEN
  INSERT INTO client_feedback (project_id, client_access_id, rating, feedback_text, week_number, year) VALUES
    (p_acme, acc_id, 5, 'Smooth kickoff and clear communication. Looking forward to SSO go-live.', 5, 2026),
    (p_acme, acc_id, 4, 'Milestone updates are helpful. Would be great to see more detail on wiki migration.', 6, 2026);
END IF;

RAISE NOTICE '05b-project-client-access: Demo client portal ready. Password: Demo123!';
END $$;

-- <<< END: 05b-project-client-access.sql

-- >>> BEGIN: 05c-project-module-settings.sql

-- ============================================================
-- SEED: Project module settings (project_modules)
-- Enables project detail tabs: Tasks, Integrations, Client Portal,
-- Checklist, Risks, Docs & Meetings, Billing.
-- ============================================================

INSERT INTO public.system_settings (category, key, value, description) VALUES
  ('project_modules', 'tasks',           'true'::jsonb, 'Toggle for project detail tab: tasks'),
  ('project_modules', 'integrations',   'true'::jsonb, 'Toggle for project detail tab: integrations'),
  ('project_modules', 'client_portal',  'true'::jsonb, 'Toggle for project detail tab: client_portal'),
  ('project_modules', 'checklist',      'true'::jsonb, 'Toggle for project detail tab: checklist'),
  ('project_modules', 'risks',         'true'::jsonb, 'Toggle for project detail tab: risks'),
  ('project_modules', 'files',         'true'::jsonb, 'Toggle for project detail tab: files'),
  ('project_modules', 'finance',       'true'::jsonb, 'Toggle for project detail tab: finance')
ON CONFLICT (category, key) DO NOTHING;

-- <<< END: 05c-project-module-settings.sql

-- >>> BEGIN: 06-business-dev.sql

-- ============================================================
-- SEED: Business Development Module
-- Contacts, deals, deal activities, deal comments,
-- lead follow-ups, contact communications, scheduled emails
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  cl_acme UUID := (SELECT id FROM clients WHERE email = 'john.doe@example.com' LIMIT 1);
  cl_tech UUID := (SELECT id FROM clients WHERE email = 'jane.smith@techstart.io' LIMIT 1);
  cl_fin  UUID := (SELECT id FROM clients WHERE email = 'tom@finedge.io' LIMIT 1);
  cl_health UUID := (SELECT id FROM clients WHERE email = 'lisa@healthsync.com' LIMIT 1);
  ct1 UUID; ct2 UUID; ct3 UUID; ct4 UUID; ct5 UUID; ct6 UUID;
  d1 UUID; d2 UUID; d3 UUID; d4 UUID; d5 UUID;
BEGIN

-- 1. Contacts
INSERT INTO contacts (first_name, last_name, email, phone, company, title, linkedin_url, client_id, source, tags, notes, created_by) VALUES
  ('John',    'Doe',     'john.doe@example.com',       '+1-555-0101', 'Acme Corp',            'CTO',             'https://linkedin.com/in/johndoe',       cl_acme,  'referral',  ARRAY['vip','technical'], 'Primary technical contact.',     u1),
  ('Jane',    'Smith',   'jane.smith@techstart.io',    '+1-555-0102', 'TechStart Inc',        'CEO',             'https://linkedin.com/in/janesmith',     cl_tech,  'inbound',   ARRAY['decision-maker'],  'Very interested in AI features.', u1),
  ('Michael', 'Johnson', 'mjohnson@enterprise.com',    '+1-555-0103', 'Enterprise Solutions',  'VP Operations',   'https://linkedin.com/in/mjohnson',      NULL,     'conference', ARRAY['enterprise'],     'Met at SaaStr 2025.',            u1),
  ('Tom',     'Bradley', 'tom@finedge.io',             '+1-555-0202', 'FinEdge Solutions',     'Head of Product', 'https://linkedin.com/in/tombradley',    cl_fin,   'cold',      ARRAY['fintech'],        'Fintech startup, Series A.',      u1),
  ('Lisa',    'Nguyen',  'lisa@healthsync.com',        '+1-555-0203', 'HealthSync Inc',        'COO',             'https://linkedin.com/in/lisanguyen',    cl_health,'cold',      ARRAY['healthcare'],     'Healthcare SaaS, evaluating.',    u1),
  ('David',   'Kim',     'david.kim@cloudbase.dev',    '+1-555-0301', 'CloudBase',             'Engineering Lead','https://linkedin.com/in/davidkim',      NULL,     'linkedin',  ARRAY['saas','devtools'],'Responded to LinkedIn outreach.', u1)
ON CONFLICT DO NOTHING;

SELECT id INTO ct1 FROM contacts WHERE email = 'john.doe@example.com' LIMIT 1;
SELECT id INTO ct2 FROM contacts WHERE email = 'jane.smith@techstart.io' LIMIT 1;
SELECT id INTO ct3 FROM contacts WHERE email = 'mjohnson@enterprise.com' LIMIT 1;
SELECT id INTO ct4 FROM contacts WHERE email = 'tom@finedge.io' LIMIT 1;
SELECT id INTO ct5 FROM contacts WHERE email = 'lisa@healthsync.com' LIMIT 1;
SELECT id INTO ct6 FROM contacts WHERE email = 'david.kim@cloudbase.dev' LIMIT 1;

-- 2. Deals
INSERT INTO deals (title, slug, description, stage, value, currency, probability, client_id, contact_id, owner_id, expected_close_date, source, tags, created_by) VALUES
  ('Acme Corp — Annual License',     'acme-annual-license',
   'Annual platform license renewal for Acme Corp.',
   'won', 54000, 'USD', 100, cl_acme, ct1, u1, '2026-01-15', 'renewal', ARRAY['enterprise','annual'], u1),

  ('TechStart — AI Package',         'techstart-ai-package',
   'AI agent setup + knowledge base + 6-month support.',
   'proposal', 36000, 'USD', 70, cl_tech, ct2, u1, '2026-02-28', 'inbound', ARRAY['ai','startup'], u1),

  ('FinEdge — POC Engagement',       'finedge-poc',
   'Paid proof-of-concept to evaluate productivity analytics.',
   'discovery', 12000, 'USD', 40, cl_fin, ct4, u1, '2026-03-15', 'outbound', ARRAY['fintech','poc'], u1),

  ('HealthSync — Platform Evaluation', 'healthsync-eval',
   'HealthSync evaluating platform for operations management.',
   'lead', 48000, 'USD', 15, cl_health, ct5, u1, '2026-04-30', 'cold', ARRAY['healthcare'], u1),

  ('CloudBase — DevTools Integration', 'cloudbase-devtools',
   'Potential integration partnership with CloudBase.',
   'discovery', 24000, 'USD', 30, NULL, ct6, u1, '2026-03-31', 'linkedin', ARRAY['partnership','devtools'], u1)
ON CONFLICT (slug) DO NOTHING;

SELECT id INTO d1 FROM deals WHERE slug = 'acme-annual-license' LIMIT 1;
SELECT id INTO d2 FROM deals WHERE slug = 'techstart-ai-package' LIMIT 1;
SELECT id INTO d3 FROM deals WHERE slug = 'finedge-poc' LIMIT 1;
SELECT id INTO d4 FROM deals WHERE slug = 'healthsync-eval' LIMIT 1;
SELECT id INTO d5 FROM deals WHERE slug = 'cloudbase-devtools' LIMIT 1;

-- 3. Deal activities
IF d1 IS NOT NULL THEN
  INSERT INTO deal_activities (deal_id, user_id, activity_type, content, metadata) VALUES
    (d1, u1, 'stage_change', 'Moved from proposal to won.',          '{"from":"proposal","to":"won"}'::jsonb),
    (d1, u1, 'note',         'Contract signed. License starts Jan 1.', '{}'::jsonb);
END IF;
IF d2 IS NOT NULL THEN
  INSERT INTO deal_activities (deal_id, user_id, activity_type, content, metadata) VALUES
    (d2, u1, 'meeting',      'Product demo with Jane Smith.',         '{"meeting_type":"demo"}'::jsonb),
    (d2, u1, 'email',        'Sent proposal PDF and pricing sheet.', '{}'::jsonb),
    (d2, u1, 'stage_change', 'Moved from discovery to proposal.',   '{"from":"discovery","to":"proposal"}'::jsonb);
END IF;
IF d3 IS NOT NULL THEN
  INSERT INTO deal_activities (deal_id, user_id, activity_type, content, metadata) VALUES
    (d3, u1, 'call',         'Intro call with Tom Bradley. Interested in productivity analytics.', '{"duration_minutes":30}'::jsonb),
    (d3, u1, 'stage_change', 'Moved from lead to discovery.',       '{"from":"lead","to":"discovery"}'::jsonb);
END IF;

-- 4. Deal comments
IF d2 IS NOT NULL THEN
  INSERT INTO deal_comments (deal_id, user_id, content) VALUES
    (d2, u1, 'Jane wants a custom agent for their API docs. Should be straightforward with our framework.'),
    (d2, u1, 'Pricing approved internally. Waiting for TechStart legal review.');
END IF;

-- 5. Lead follow-up contacts
INSERT INTO lead_followup_contacts (contact_id, status, priority, next_follow_up, follow_up_notes, assigned_to) VALUES
  (ct5, 'contacted', 'high',   '2026-02-05', 'Sent intro email. Schedule discovery call.', u1),
  (ct6, 'interested', 'medium', '2026-02-10', 'Responded positively. Wants to see demo.', u1),
  (ct3, 'not_interested', 'low', NULL, 'Not evaluating new tools this quarter. Revisit Q2.', u1)
ON CONFLICT (contact_id) DO NOTHING;

-- 6. Contact communications
INSERT INTO contact_communications (contact_id, channel, direction, subject, content, user_id) VALUES
  (ct2, 'email',    'outbound', 'Proposal: TechStart AI Package',      'Hi Jane, please find attached our proposal for the AI agent setup...', u1),
  (ct2, 'meeting',  'outbound', 'Product Demo',                        'Walked through knowledge base, AI agents, and productivity module.', u1),
  (ct4, 'phone',    'outbound', 'Intro Call',                          'Discussed FinEdge needs around productivity analytics and team metrics.', u1),
  (ct5, 'email',    'outbound', 'Introduction: SJ Innovation Platform', 'Hi Lisa, I wanted to introduce our AI-powered operations platform...', u1),
  (ct5, 'email',    'inbound',  'Re: Introduction',                    'Thanks for reaching out. We are evaluating solutions for Q2. Let us schedule a call.', u1),
  (ct6, 'linkedin', 'outbound', 'LinkedIn connection request',         'Hi David, I noticed CloudBase and thought there might be synergy...', u1),
  (ct6, 'linkedin', 'inbound',  'Re: Connection',                      'Thanks! Would love to learn more. Can you send a demo link?', u1);

-- 7. Scheduled emails
INSERT INTO scheduled_emails (to_email, subject, body, scheduled_for, status, deal_id, contact_id, created_by) VALUES
  ('tom@finedge.io', 'Follow-up: POC Next Steps',
   'Hi Tom, following up on our call. I have put together a POC scope document...',
   NOW() + INTERVAL '1 day', 'pending', d3, ct4, u1),
  ('lisa@healthsync.com', 'Discovery Call Scheduling',
   'Hi Lisa, great to hear you are interested. Here are some available times...',
   NOW() + INTERVAL '2 days', 'pending', d4, ct5, u1);

END $$;

-- <<< END: 06-business-dev.sql

-- >>> BEGIN: 07b-productivity-base.sql

-- ============================================================
-- SEED: Productivity Base Tables (Path B - EmployeeProductivity)
-- Populates Employee, ActionItem, EmployeeProductivity for demo
-- Run after 07-productivity.sql and after migration 20260203_productivity_base_tables.sql
-- Skips silently if Path B tables (public."Employee") do not exist.
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  emp_email TEXT;
  emp_name TEXT;
  path_b_exists BOOLEAN;
BEGIN
  -- Only run if Path B migration has created public."Employee"
  SELECT EXISTS (
    SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'Employee'
  ) INTO path_b_exists;

  IF NOT path_b_exists THEN
    RAISE NOTICE 'Seed 07b-productivity-base: public."Employee" not found — run migration 20260203_productivity_base_tables.sql first. Skipping.';
    RETURN;
  END IF;

  -- Get first user's email and name for Employee
  SELECT email, COALESCE(raw_user_meta_data->>'full_name', 'Admin User')
    INTO emp_email, emp_name
    FROM auth.users WHERE id = u1 LIMIT 1;

  -- 1. Insert current user as Employee if not exists
  INSERT INTO public."Employee" (name, email, title, role, department, location, status)
  VALUES (emp_name, emp_email, 'Admin', 'admin', 'Engineering', 'New York, NY', 'active')
  ON CONFLICT (email) DO UPDATE SET
    name = EXCLUDED.name,
    title = EXCLUDED.title,
    department = EXCLUDED.department,
    location = EXCLUDED.location;

  -- 2. Insert demo employees (must exist before EmployeeProductivity)
  INSERT INTO public."Employee" (name, email, title, role, department, location, status)
  VALUES
    ('Shahed Islam',   'shahed@sjinnovation.com',  'Senior Developer',      'developer', 'Engineering',    'New York, NY',      'active'),
    ('Abesh Rahman',   'abesh@sjinnovation.com',   'Full Stack Developer',  'developer', 'Engineering',    'Dhaka, BD',         'active'),
    ('Omkar',          'omkar@sjinnovation.com',   'Frontend Developer',    'developer', 'Engineering',    'Dhaka, BD',         'active'),
    ('Sarah Chen',     'sarah@sjinnovation.com',   'Business Development',  'developer', 'Sales & BD',     'San Francisco, CA', 'active'),
    ('Marcus Williams','marcus@sjinnovation.com',  'Operations Manager',    'manager',   'Operations',     'New York, NY',      'active')
  ON CONFLICT (email) DO NOTHING;

  -- 3. EmployeeProductivity (ISO week format YYYY-W##)
  INSERT INTO public."EmployeeProductivity" (id, week, email, name, department, location, productive_time_hr, productivity_percentage, present_days)
  VALUES
    (gen_random_uuid()::text, '2026-W02', 'shahed@sjinnovation.com',  'Shahed Islam',   'Engineering',    'New York, NY',      '36', 85.7, 5),
    (gen_random_uuid()::text, '2026-W02', 'abesh@sjinnovation.com',   'Abesh Rahman',   'Engineering',    'Dhaka, BD',         '34', 85.0, 5),
    (gen_random_uuid()::text, '2026-W02', 'omkar@sjinnovation.com',   'Omkar',          'Engineering',    'Dhaka, BD',         '30', 78.9, 5),
    (gen_random_uuid()::text, '2026-W02', 'sarah@sjinnovation.com',   'Sarah Chen',     'Sales & BD',     'San Francisco, CA', '32', 80.0, 5),
    (gen_random_uuid()::text, '2026-W02', 'marcus@sjinnovation.com',  'Marcus Williams','Operations',     'New York, NY',      '20', 50.0, 5),
    (gen_random_uuid()::text, '2026-W03', 'shahed@sjinnovation.com',  'Shahed Islam',   'Engineering',    'New York, NY',      '38', 86.4, 5),
    (gen_random_uuid()::text, '2026-W03', 'abesh@sjinnovation.com',   'Abesh Rahman',   'Engineering',    'Dhaka, BD',         '35', 87.5, 5),
    (gen_random_uuid()::text, '2026-W03', 'omkar@sjinnovation.com',   'Omkar',          'Engineering',    'Dhaka, BD',         '28', 77.8, 4),
    (gen_random_uuid()::text, '2026-W03', 'sarah@sjinnovation.com',   'Sarah Chen',     'Sales & BD',     'San Francisco, CA', '35', 83.3, 5),
    (gen_random_uuid()::text, '2026-W03', 'marcus@sjinnovation.com',  'Marcus Williams','Operations',     'New York, NY',      '22', 55.0, 5),
    (gen_random_uuid()::text, '2026-W04', 'shahed@sjinnovation.com',  'Shahed Islam',   'Engineering',    'New York, NY',      '40', 88.9, 5),
    (gen_random_uuid()::text, '2026-W04', 'abesh@sjinnovation.com',   'Abesh Rahman',   'Engineering',    'Dhaka, BD',         '36', 87.8, 5),
    (gen_random_uuid()::text, '2026-W04', 'omkar@sjinnovation.com',   'Omkar',          'Engineering',    'Dhaka, BD',         '33', 82.5, 5),
    (gen_random_uuid()::text, '2026-W04', 'sarah@sjinnovation.com',   'Sarah Chen',     'Sales & BD',     'San Francisco, CA', '30', 78.9, 5),
    (gen_random_uuid()::text, '2026-W04', 'marcus@sjinnovation.com',  'Marcus Williams','Operations',     'New York, NY',      '24', 60.0, 5),
    (gen_random_uuid()::text, '2026-W05', 'shahed@sjinnovation.com',  'Shahed Islam',   'Engineering',    'New York, NY',      '38', 88.4, 5),
    (gen_random_uuid()::text, '2026-W05', 'abesh@sjinnovation.com',   'Abesh Rahman',   'Engineering',    'Dhaka, BD',         '35', 87.5, 5),
    (gen_random_uuid()::text, '2026-W05', 'omkar@sjinnovation.com',   'Omkar',          'Engineering',    'Dhaka, BD',         '34', 85.0, 5),
    (gen_random_uuid()::text, '2026-W05', 'sarah@sjinnovation.com',   'Sarah Chen',     'Sales & BD',     'San Francisco, CA', '33', 82.5, 5)
  ON CONFLICT (email, week) DO NOTHING;

  -- 4. Action items (sample)
  INSERT INTO public."ActionItem" (id, email, summary, status, priority, week)
  VALUES
    ('act-1', 'omkar@sjinnovation.com', 'Complete onboarding docs', 'completed', 'medium', '2026-W03'),
    ('act-2', 'marcus@sjinnovation.com', 'Q1 planning session', 'pending', 'high', '2026-W05')
  ON CONFLICT (id) DO NOTHING;

END $$;

-- <<< END: 07b-productivity-base.sql

-- >>> BEGIN: 07-productivity.sql

-- ============================================================
-- SEED: Productivity Module
-- Departments, pods, pod members, employee profiles,
-- productivity records, leave events, process docs, alerts
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  dept_eng UUID;
  dept_sales UUID;
  dept_ops UUID;
  pod_frontend UUID;
  pod_backend UUID;
  pod_growth UUID;
  cat_eng UUID;
  cat_hr UUID;
  cat_sales UUID;
BEGIN

-- 1. Departments
INSERT INTO departments (name, description, manager_id, is_active) VALUES
  ('Engineering',     'Software development and technical operations.',    u1, true),
  ('Sales & BD',      'Revenue generation, partnerships, and growth.',     u1, true),
  ('Operations & HR', 'People, finance, and internal processes.',          u1, true)
ON CONFLICT (name) DO NOTHING;

SELECT id INTO dept_eng   FROM departments WHERE name = 'Engineering' LIMIT 1;
SELECT id INTO dept_sales FROM departments WHERE name = 'Sales & BD' LIMIT 1;
SELECT id INTO dept_ops   FROM departments WHERE name = 'Operations & HR' LIMIT 1;

-- 2. Pods
INSERT INTO pods (name, department_id, description, lead_id, is_active) VALUES
  ('Frontend Pod',    dept_eng,   'React/TypeScript UI development.',   u1, true),
  ('Backend Pod',     dept_eng,   'Supabase, edge functions, API.',     u1, true),
  ('Growth Pod',      dept_sales, 'Lead gen, outreach, and demos.',     u1, true)
ON CONFLICT DO NOTHING;

SELECT id INTO pod_frontend FROM pods WHERE name = 'Frontend Pod' LIMIT 1;
SELECT id INTO pod_backend  FROM pods WHERE name = 'Backend Pod'  LIMIT 1;
SELECT id INTO pod_growth   FROM pods WHERE name = 'Growth Pod'   LIMIT 1;

-- 3. Pod members
INSERT INTO pod_members (pod_id, user_id, role) VALUES
  (pod_frontend, u1, 'lead'),
  (pod_backend,  u1, 'member')
ON CONFLICT DO NOTHING;

-- 4. Employee profiles (map first user + create placeholder entries)
INSERT INTO employee_profiles (user_id, email, full_name, department_id, title, hire_date, location, employment_type, is_active) VALUES
  (u1, (SELECT email FROM auth.users WHERE id = u1), (SELECT COALESCE(raw_user_meta_data->>'full_name', 'Admin User') FROM auth.users WHERE id = u1), dept_eng, 'CEO & Lead Developer', '2024-06-01', 'New York, NY', 'full-time', true)
ON CONFLICT (email) DO NOTHING;

-- Additional employee profiles (no auth.users mapping, for demo data display)
INSERT INTO employee_profiles (email, full_name, department_id, title, hire_date, location, employment_type, is_active) VALUES
  ('shahed@sjinnovation.com',  'Shahed Islam',   dept_eng,   'Senior Developer',      '2024-09-01', 'New York, NY', 'full-time', true),
  ('abesh@sjinnovation.com',   'Abesh Rahman',   dept_eng,   'Full Stack Developer',  '2024-11-01', 'Dhaka, BD',    'full-time', true),
  ('zia@sjinnovation.com',     'Zia Ahmed',      dept_eng,   'Frontend Developer',    '2025-01-15', 'Dhaka, BD',    'full-time', true),
  ('sarah@sjinnovation.com',   'Sarah Chen',     dept_sales, 'Business Development',  '2025-03-01', 'San Francisco, CA', 'full-time', true),
  ('marcus@sjinnovation.com',  'Marcus Williams', dept_ops,  'Operations Manager',    '2025-02-01', 'New York, NY', 'full-time', true)
ON CONFLICT (email) DO NOTHING;

-- 5. Productivity records (4 weeks of data for 5 employees) — idempotent: skip if row exists
INSERT INTO productivity_records (employee_email, week_start, week_number, year, total_hours, billable_hours, tasks_completed, tasks_assigned, meetings_attended, utilization_pct, efficiency_score, attendance_status, department, location) VALUES
  -- Week of Jan 6
  ('shahed@sjinnovation.com',  '2026-01-05', 2, 2026, 42, 36, 8, 10, 4, 85.7, 80.0, 'present', 'Engineering', 'New York, NY'),
  ('abesh@sjinnovation.com',   '2026-01-05', 2, 2026, 40, 34, 7,  9, 3, 85.0, 77.8, 'present', 'Engineering', 'Dhaka, BD'),
  ('zia@sjinnovation.com',     '2026-01-05', 2, 2026, 38, 30, 6,  8, 2, 78.9, 75.0, 'present', 'Engineering', 'Dhaka, BD'),
  ('sarah@sjinnovation.com',   '2026-01-05', 2, 2026, 40, 32, 5,  6, 8, 80.0, 83.3, 'present', 'Sales & BD',  'San Francisco, CA'),
  ('marcus@sjinnovation.com',  '2026-01-05', 2, 2026, 40, 20, 4,  5, 6, 50.0, 80.0, 'present', 'Operations & HR', 'New York, NY'),

  -- Week of Jan 13
  ('shahed@sjinnovation.com',  '2026-01-12', 3, 2026, 44, 38, 9, 11, 5, 86.4, 81.8, 'present', 'Engineering', 'New York, NY'),
  ('abesh@sjinnovation.com',   '2026-01-12', 3, 2026, 40, 35, 8, 10, 3, 87.5, 80.0, 'present', 'Engineering', 'Dhaka, BD'),
  ('zia@sjinnovation.com',     '2026-01-12', 3, 2026, 36, 28, 5,  7, 2, 77.8, 71.4, 'partial', 'Engineering', 'Dhaka, BD'),
  ('sarah@sjinnovation.com',   '2026-01-12', 3, 2026, 42, 35, 6,  7, 9, 83.3, 85.7, 'present', 'Sales & BD',  'San Francisco, CA'),
  ('marcus@sjinnovation.com',  '2026-01-12', 3, 2026, 40, 22, 5,  6, 7, 55.0, 83.3, 'present', 'Operations & HR', 'New York, NY'),

  -- Week of Jan 20
  ('shahed@sjinnovation.com',  '2026-01-19', 4, 2026, 45, 40, 10, 12, 4, 88.9, 83.3, 'present', 'Engineering', 'New York, NY'),
  ('abesh@sjinnovation.com',   '2026-01-19', 4, 2026, 41, 36, 9, 10, 4, 87.8, 90.0, 'present', 'Engineering', 'Dhaka, BD'),
  ('zia@sjinnovation.com',     '2026-01-19', 4, 2026, 40, 33, 7,  9, 3, 82.5, 77.8, 'present', 'Engineering', 'Dhaka, BD'),
  ('sarah@sjinnovation.com',   '2026-01-19', 4, 2026, 38, 30, 4,  5, 7, 78.9, 80.0, 'present', 'Sales & BD',  'San Francisco, CA'),
  ('marcus@sjinnovation.com',  '2026-01-19', 4, 2026, 40, 24, 6,  7, 5, 60.0, 85.7, 'present', 'Operations & HR', 'New York, NY'),

  -- Week of Jan 27
  ('shahed@sjinnovation.com',  '2026-01-26', 5, 2026, 43, 38, 11, 13, 5, 88.4, 84.6, 'present', 'Engineering', 'New York, NY'),
  ('abesh@sjinnovation.com',   '2026-01-26', 5, 2026, 40, 35, 8,  9, 3, 87.5, 88.9, 'present', 'Engineering', 'Dhaka, BD'),
  ('zia@sjinnovation.com',     '2026-01-26', 5, 2026, 40, 34, 8, 10, 3, 85.0, 80.0, 'present', 'Engineering', 'Dhaka, BD'),
  ('sarah@sjinnovation.com',   '2026-01-26', 5, 2026, 40, 33, 5,  6, 8, 82.5, 83.3, 'present', 'Sales & BD',  'San Francisco, CA'),
  ('marcus@sjinnovation.com',  '2026-01-26', 5, 2026, 0,  0,  0,  0, 0, 0.0,   0.0, 'leave',   'Operations & HR', 'New York, NY')
ON CONFLICT (employee_email, week_start) DO NOTHING;

-- 6. Leave events
INSERT INTO leave_events (employee_email, leave_type, start_date, end_date, is_half_day, notes, approved_by, status) VALUES
  ('marcus@sjinnovation.com',  'pto',     '2026-01-26', '2026-01-30', false, 'Family vacation.',           'admin@sjinnovation.com', 'approved'),
  ('zia@sjinnovation.com',     'sick',    '2026-01-14', '2026-01-14', true,  'Felt unwell, half day off.', 'admin@sjinnovation.com', 'approved'),
  ('sarah@sjinnovation.com',   'personal','2026-02-14', '2026-02-14', false, 'Personal appointment.',      'admin@sjinnovation.com', 'approved'),
  ('abesh@sjinnovation.com',   'holiday', '2026-02-21', '2026-02-21', false, 'National holiday (Shahid Day).', NULL, 'approved');

-- 7. Process categories
INSERT INTO process_categories (name, slug, description, icon, sort_order, is_active) VALUES
  ('Engineering Processes', 'engineering-processes', 'Software development workflows and standards.', 'Code',    1, true),
  ('HR & People',           'hr-people',            'Hiring, onboarding, and people management.',    'Users',   2, true),
  ('Sales Processes',       'sales-processes',       'Sales workflows, qualification, and closing.',  'Target',  3, true),
  ('Client Delivery',       'client-delivery',       'Client project delivery workflows.',            'Package', 4, true)
ON CONFLICT (slug) DO NOTHING;

SELECT id INTO cat_eng   FROM process_categories WHERE slug = 'engineering-processes' LIMIT 1;
SELECT id INTO cat_hr    FROM process_categories WHERE slug = 'hr-people' LIMIT 1;
SELECT id INTO cat_sales FROM process_categories WHERE slug = 'sales-processes' LIMIT 1;

-- 8. Process documents — idempotent: skip if (category_id, slug) exists
INSERT INTO process_documents (category_id, title, slug, content, version, status, tags, created_by, updated_by) VALUES
  (cat_eng, 'Code Review Process', 'code-review-process',
   E'# Code Review Process\n\n## Steps\n1. Developer creates PR with description.\n2. Assign reviewer within 2 hours.\n3. Reviewer provides feedback within 4 hours.\n4. Address comments, re-request review.\n5. Merge after approval.\n\n## Standards\n- Max 400 lines per PR.\n- Include tests for new features.\n- No console.log in production code.',
   1, 'published', ARRAY['engineering','code-review'], u1, u1),

  (cat_eng, 'Deployment Checklist', 'deployment-checklist',
   E'# Deployment Checklist\n\n- [ ] All tests pass locally\n- [ ] PR approved and merged to develop\n- [ ] Staging deploy verified\n- [ ] Database migration reviewed\n- [ ] Feature flags configured\n- [ ] Monitoring alerts verified\n- [ ] Release notes updated',
   1, 'published', ARRAY['engineering','deployment'], u1, u1),

  (cat_hr, 'New Hire Onboarding', 'new-hire-onboarding',
   E'# New Hire Onboarding\n\n## Day 1\n- IT setup (laptop, accounts, Slack)\n- Meet the team\n- Review company handbook\n\n## Week 1\n- Shadow senior team member\n- Complete security training\n- Set up development environment\n\n## Month 1\n- Complete first assigned task\n- First 1:1 with manager\n- 30-day feedback session',
   1, 'published', ARRAY['hr','onboarding'], u1, u1),

  (cat_sales, 'Lead Qualification Framework', 'lead-qualification',
   E'# Lead Qualification Framework (BANT)\n\n## Budget\n- Can they afford our solution?\n- Budget range: $20K–$100K annually.\n\n## Authority\n- Are we talking to the decision-maker?\n- Identify economic buyer vs. champion.\n\n## Need\n- Pain points alignment with our modules.\n- Current tools and gaps.\n\n## Timeline\n- When do they need a solution?\n- Buying cycle length.',
   1, 'published', ARRAY['sales','qualification'], u1, u1)
ON CONFLICT (category_id, slug) DO NOTHING;

-- 9. Productivity alerts
INSERT INTO productivity_alerts (employee_email, alert_type, severity, title, description, week_start, is_read) VALUES
  ('marcus@sjinnovation.com', 'absence_pattern',    'medium', 'Extended Leave',           'Marcus has been on leave for the full week. Ensure handoff is covered.', '2026-01-26', false),
  ('zia@sjinnovation.com',    'declining_trend',    'low',    'Utilization Dip',          'Zia''s utilization dropped from 82.5% to 77.8% last week. Monitor.',   '2026-01-12', true),
  ('shahed@sjinnovation.com', 'high_performer',     'low',    'Consistently High Output', 'Shahed has maintained 85%+ utilization for 4 consecutive weeks.',       '2026-01-26', false),
  ('abesh@sjinnovation.com',  'high_performer',     'low',    'Task Completion Improving','Abesh''s task completion rate improved from 77% to 89% over 4 weeks.', '2026-01-26', false);

END $$;

-- <<< END: 07-productivity.sql

-- >>> BEGIN: 08-ai-agents.sql

-- ============================================================
-- SEED: AI Agents Module
-- Providers, models, agents (extend existing), chat history,
-- usage logs
-- ============================================================

DO $$
DECLARE
  u1 UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  prov_openai UUID;
  prov_anthropic UUID;
  prov_gemini UUID;
  model_gpt4 UUID;
  model_claude UUID;
  model_embed UUID;
  agent_email UUID;
  agent_meeting UUID;
  agent_ops UUID;
  session1 UUID := gen_random_uuid();
  session2 UUID := gen_random_uuid();
BEGIN

-- 1. AI Providers (description column may or may not exist depending on migration)
-- Try with description first, fall back to without
BEGIN
  INSERT INTO ai_providers (name, slug, description, api_key_secret_name, base_url, enabled) VALUES
    ('OpenAI',    'openai',    'GPT-4, GPT-3.5, and embedding models.',       'OPENAI_API_KEY',    'https://api.openai.com/v1',      true),
    ('Anthropic', 'anthropic', 'Claude Opus, Sonnet, and Haiku models.',      'ANTHROPIC_API_KEY', 'https://api.anthropic.com/v1',    true),
    ('Google',    'google',    'Gemini Pro and embedding models.',             'GOOGLE_API_KEY',    'https://generativelanguage.googleapis.com', false)
  ON CONFLICT (slug) DO NOTHING;
EXCEPTION WHEN undefined_column THEN
  INSERT INTO ai_providers (name, slug, api_key_secret_name, base_url, enabled) VALUES
    ('OpenAI',    'openai',    'OPENAI_API_KEY',    'https://api.openai.com/v1',      true),
    ('Anthropic', 'anthropic', 'ANTHROPIC_API_KEY', 'https://api.anthropic.com/v1',    true),
    ('Google',    'google',    'GOOGLE_API_KEY',    'https://generativelanguage.googleapis.com', false)
  ON CONFLICT (slug) DO NOTHING;
END;

SELECT id INTO prov_openai    FROM ai_providers WHERE slug = 'openai' LIMIT 1;
SELECT id INTO prov_anthropic FROM ai_providers WHERE slug = 'anthropic' LIMIT 1;
SELECT id INTO prov_gemini    FROM ai_providers WHERE slug = 'google' LIMIT 1;

-- 2. AI Models
INSERT INTO ai_models (provider_id, model_id, name, category, enabled, is_default, context_window, input_cost_per_1k, output_cost_per_1k) VALUES
  (prov_openai,    'gpt-4o',                    'GPT-4o',              'chat',      true, false, 128000, 0.005,  0.015),
  (prov_openai,    'gpt-4o-mini',               'GPT-4o Mini',         'chat',      true, false, 128000, 0.00015, 0.0006),
  (prov_openai,    'text-embedding-3-small',     'Embedding 3 Small',  'embedding', true, true,  8191,   0.00002, 0),
  (prov_anthropic, 'claude-sonnet-4-20250514',   'Claude Sonnet 4',    'chat',      true, true,  200000, 0.003,  0.015),
  (prov_anthropic, 'claude-haiku-3-5-20241022',  'Claude 3.5 Haiku',   'chat',      true, false, 200000, 0.001,  0.005),
  (prov_gemini,    'gemini-2.0-flash',           'Gemini 2.0 Flash',   'chat',      false, false, 1000000, 0.00035, 0.0015)
ON CONFLICT DO NOTHING;

SELECT id INTO model_gpt4  FROM ai_models WHERE model_id = 'gpt-4o' LIMIT 1;
SELECT id INTO model_claude FROM ai_models WHERE model_id = 'claude-sonnet-4-20250514' LIMIT 1;
SELECT id INTO model_embed  FROM ai_models WHERE model_id = 'text-embedding-3-small' LIMIT 1;

-- 3. Additional AI agents (3 already exist from test-data; add more)
INSERT INTO ai_agents (name, slug, description, system_prompt, category, is_enabled, memory_enabled, data_sources, required_role) VALUES
  ('Operations Advisor', 'operations-advisor',
   'Analyzes team productivity data and suggests operational improvements.',
   'You are an operations advisor for a professional services firm. You have access to productivity metrics, attendance data, and team structures. Provide data-driven recommendations for improving team efficiency, workload balance, and operational processes. Be specific and actionable.',
   'operations', true, true, '["productivity_records","departments","pods"]'::jsonb, 'admin'),

  ('Deal Coach', 'deal-coach',
   'Helps sales team with deal strategy, email drafts, and objection handling.',
   'You are a B2B sales coach specializing in SaaS sales to mid-market companies. Help with deal strategy, email drafts, discovery call prep, and objection handling. Use the MEDDPICC framework when analyzing deals. Be direct and practical.',
   'sales', true, true, '["deals","contacts","deal_activities"]'::jsonb, 'user'),

  ('Knowledge Search', 'knowledge-search',
   'Semantic search across company knowledge base articles and documents.',
   'You are a knowledge assistant with access to the company knowledge base. Answer questions by searching relevant articles and documents. Always cite your sources. If you cannot find relevant information, say so clearly.',
   'knowledge', true, false, '["knowledge_entries","knowledge_files","common_knowledge"]'::jsonb, 'user'),

  ('EOS Coach', 'eos-coach',
   'Guides teams through EOS processes — L10s, rocks, IDS, and accountability.',
   'You are an EOS (Entrepreneurial Operating System) implementation coach. Help teams run effective L10 meetings, set quarterly rocks, use the IDS process for issues, and maintain accountability charts. Reference EOS best practices from Traction by Gino Wickman.',
   'eos', true, true, '["eos_vto","okrs","eos_issues","eos_scorecards"]'::jsonb, 'user'),

  ('Project Analyst', 'project-analyst',
   'Analyzes project health, risks, and provides status summaries.',
   'You are a project management analyst. Review project data including milestones, budgets, risks, and team assignments. Provide clear status summaries, highlight risks, and suggest mitigation strategies. Use earned value management concepts when discussing budget.',
   'projects', true, false, '["projects","project_milestones","project_risks","project_billing"]'::jsonb, 'user')
ON CONFLICT (slug) DO NOTHING;

SELECT id INTO agent_email   FROM ai_agents WHERE slug = 'email-draft-assistant' LIMIT 1;
SELECT id INTO agent_meeting FROM ai_agents WHERE slug = 'meeting-summary' LIMIT 1;
SELECT id INTO agent_ops     FROM ai_agents WHERE slug = 'operations-advisor' LIMIT 1;

-- 4. Chat history (sample conversations)
IF agent_email IS NOT NULL THEN
  INSERT INTO ai_chat_history (session_id, user_id, agent_id, role, content) VALUES
    (session1, u1, agent_email, 'user',      'Help me draft a follow-up email to Tom Bradley at FinEdge after our discovery call. He is interested in productivity analytics.'),
    (session1, u1, agent_email, 'assistant', E'Subject: Great Speaking with You — Next Steps for FinEdge\n\nHi Tom,\n\nThank you for taking the time to speak with us today. It was great learning about FinEdge''s goals around team productivity analytics.\n\nBased on our conversation, I believe our Productivity module would be a strong fit for your needs. Here''s what I suggest as next steps:\n\n1. **Proof of Concept** — We can set up a focused POC with your team''s data\n2. **Technical Deep-Dive** — A 30-minute session with our engineering team\n3. **Pricing Discussion** — I''ll send over our POC pricing sheet\n\nWould Thursday at 2 PM ET work for the technical session?\n\nBest regards'),
    (session1, u1, agent_email, 'user',      'That looks good. Make it a bit shorter and more casual.'),
    (session1, u1, agent_email, 'assistant', E'Subject: Following Up — FinEdge + SJ Innovation\n\nHey Tom,\n\nGreat chatting today! Really enjoyed learning about what you''re building at FinEdge.\n\nI think our productivity analytics would be a solid fit. Quick next steps:\n- POC with your team''s data\n- 30-min technical walkthrough\n- Pricing details\n\nFree Thursday at 2 PM ET for a deeper dive?\n\nCheers');
END IF;

IF agent_ops IS NOT NULL THEN
  INSERT INTO ai_chat_history (session_id, user_id, agent_id, role, content) VALUES
    (session2, u1, agent_ops, 'user',      'What are the productivity trends for the engineering team over the last 4 weeks?'),
    (session2, u1, agent_ops, 'assistant', E'Based on the last 4 weeks of data for the Engineering department:\n\n**Utilization Trends:**\n- Shahed: 85.7% → 86.4% → 88.9% → 88.4% (steady upward)\n- Abesh: 85.0% → 87.5% → 87.8% → 87.5% (stable high)\n- Zia: 78.9% → 77.8% → 82.5% → 85.0% (recovering after dip)\n\n**Key Observations:**\n1. The team averaged 85.3% utilization this week, up from 83.2% in week 1\n2. Zia had a partial attendance week (Jan 12) but has recovered well\n3. Task completion rates are improving across the board\n\n**Recommendations:**\n- Zia is trending positively — the reduced meeting load (2/week vs Shahed''s 5) seems to be helping focus time\n- Consider redistributing some of Shahed''s 13 assigned tasks — he''s carrying the heaviest load');
END IF;

-- 5. Usage logs
IF model_claude IS NOT NULL THEN
  INSERT INTO ai_usage_logs (user_id, model_id, function_name, input_tokens, output_tokens, estimated_cost) VALUES
    (u1, model_claude, 'agent_chat',        1200, 800,  0.015),
    (u1, model_claude, 'agent_chat',        900,  600,  0.012),
    (u1, model_claude, 'meeting_summarize', 3500, 500,  0.018);
END IF;
IF model_embed IS NOT NULL THEN
  INSERT INTO ai_usage_logs (user_id, model_id, function_name, input_tokens, output_tokens, embedding_tokens, estimated_cost) VALUES
    (u1, model_embed, 'embed_knowledge', 0, 0, 5000, 0.0001),
    (u1, model_embed, 'embed_knowledge', 0, 0, 3200, 0.0001);
END IF;

END $$;

-- <<< END: 08-ai-agents.sql

-- >>> BEGIN: 09-feedback-bugs.sql

-- ============================================================
-- SEED: Feedback bug reports (Sales & CRM triage)
-- Three bug reports for the Feedback dashboard. Idempotent.
-- Run after 00-platform-core (requires auth.users).
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.feedback
    WHERE subject = 'Companies page displays contacts by name instead of company listing'
    LIMIT 1
  ) THEN
    INSERT INTO public.feedback (user_id, type, subject, message, status, module) VALUES
    (
      (SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
      'bug',
      'Companies page displays contacts by name instead of company listing',
      'When navigating to Sales & CRM > Companies, the page displays individual contact names instead of grouping and sorting by company. Expected behavior: the Companies view should list unique companies with their associated contacts, sorted alphabetically by company name. Currently it shows the clients table rows sorted by contact name, which makes it look identical to a contacts list.',
      'pending',
      'Sales & CRM'
    ),
    (
      (SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
      'bug',
      'Contacts page shows mismatched or incorrect data',
      'The Contacts view under Sales & CRM is displaying data that does not match correctly. Contact records appear to have mismatched information. The listing should accurately show each contact with their correct associated details (name, email, phone, company, title, lead status).',
      'pending',
      'Sales & CRM'
    ),
    (
      (SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
      'bug',
      'Client detail page missing information and showing unnecessary Avg Project Value metric',
      'Two issues on the Client detail page: (1) Remove the "Avg Project Value" stat card from the Clients listing page (src/pages/Clients.tsx lines 173-185) -- this dollar metric is not needed. (2) The Client detail page (src/pages/ClientDetail.tsx) is missing significant information compared to the main Control Tower dashboard. It currently only shows email, phone, company, created/updated dates, notes, and related meetings. It should match the richness of the main dashboard view with additional context like projects, deals, invoices, status, and activity history.',
      'pending',
      'Sales & CRM'
    );
  END IF;
END $$;

-- <<< END: 09-feedback-bugs.sql

-- >>> BEGIN: 10-demo-role-data.sql

-- ============================================================
-- SEED: Demo Role Data — PM & IC project/task assignments
-- Ensures PM and IC dashboards show data out of the box.
-- ============================================================

DO $$
DECLARE
  u_pm UUID := (SELECT id FROM auth.users WHERE email = 'demo@collabai.software' LIMIT 1);
  u_ic UUID := (SELECT id FROM auth.users WHERE email = 'ic@collabai.software'   LIMIT 1);
  p_techstart UUID := (SELECT id FROM projects WHERE slug = 'techstart-ai-integration' LIMIT 1);
  p_qbr      UUID := (SELECT id FROM projects WHERE slug = 'enterprise-qbr-prep'      LIMIT 1);
  p_acme     UUID := (SELECT id FROM projects WHERE slug = 'acme-platform-rollout'     LIMIT 1);
  p_finedge  UUID := (SELECT id FROM projects WHERE slug = 'finedge-poc'               LIMIT 1);
BEGIN
  IF u_pm IS NULL THEN
    RAISE NOTICE 'PM user (demo@collabai.software) not found — skipping.';
    RETURN;
  END IF;
  IF u_ic IS NULL THEN
    RAISE NOTICE 'IC user (ic@collabai.software) not found — skipping.';
    RETURN;
  END IF;

  -- ───────────────────────────────────────────────
  -- 1. Assign PM as owner of 2 projects
  -- ───────────────────────────────────────────────
  UPDATE projects SET owner_id = u_pm WHERE id = p_techstart;
  UPDATE projects SET owner_id = u_pm WHERE id = p_qbr;

  INSERT INTO project_members (project_id, user_id, role) VALUES
    (p_techstart, u_pm, 'owner'),
    (p_qbr,      u_pm, 'owner')
  ON CONFLICT DO NOTHING;

  -- ───────────────────────────────────────────────
  -- 2. Assign IC as member on 2 projects
  -- ───────────────────────────────────────────────
  INSERT INTO project_members (project_id, user_id, role) VALUES
    (p_acme,      u_ic, 'member'),
    (p_techstart, u_ic, 'member')
  ON CONFLICT DO NOTHING;

  -- ───────────────────────────────────────────────
  -- 3. Reassign some tasks to PM (~6)
  -- ───────────────────────────────────────────────
  UPDATE tasks SET assigned_to = u_pm
  WHERE slug IN (
    'implement-sso-entra',
    'onboard-acme-corp',
    'techstart-training',
    'qbr-enterprise-solutions',
    'setup-monitoring-alerts',
    'csv-export-productivity'
  );

  -- ───────────────────────────────────────────────
  -- 4. Reassign some tasks to IC (~6)
  -- ───────────────────────────────────────────────
  UPDATE tasks SET assigned_to = u_ic
  WHERE slug IN (
    'fix-datepicker-tz',
    'api-rate-limit-docs',
    'upgrade-react-router-v7',
    'acme-billing-fix',
    'renew-ssl-certs',
    'followup-finedge'
  );

  RAISE NOTICE 'Demo role data seeded for PM (%) and IC (%)', u_pm, u_ic;
END $$;

-- <<< END: 10-demo-role-data.sql

-- >>> BEGIN: 11-demo-bd-data.sql

-- ============================================================
-- SEED: Demo BD Role Data — Business Development dashboard
-- Creates a BD user role preference and assigns deals/contacts
-- so the BD dashboard shows data out of the box.
-- ============================================================

DO $$
DECLARE
  u_bd UUID := (SELECT id FROM auth.users WHERE email = 'bd@collabai.software' LIMIT 1);
  u_fallback UUID := (SELECT id FROM auth.users ORDER BY created_at LIMIT 1);
  u_target UUID;
  ct_hot1 UUID; ct_hot2 UUID; ct_hot3 UUID;
BEGIN
  -- Use BD-specific user if exists, otherwise fall back to first user
  u_target := COALESCE(u_bd, u_fallback);

  IF u_target IS NULL THEN
    RAISE NOTICE 'No users found — skipping BD seed.';
    RETURN;
  END IF;

  -- ───────────────────────────────────────────────
  -- 1. Set agency_role = 'bd' for the BD user
  -- ───────────────────────────────────────────────
  INSERT INTO user_role_preferences (user_id, role, agency_role, is_eos_user)
  VALUES (u_target, 'user', 'bd', false)
  ON CONFLICT (user_id, role) DO UPDATE SET agency_role = 'bd';

  -- ───────────────────────────────────────────────
  -- 2. Assign existing deals to BD user as owner
  -- ───────────────────────────────────────────────
  UPDATE deals SET owner_id = u_target
  WHERE slug IN (
    'techstart-ai-package',
    'finedge-poc',
    'healthsync-eval',
    'cloudbase-devtools'
  );

  -- ───────────────────────────────────────────────
  -- 3. Mark key contacts as lead follow-ups
  -- ───────────────────────────────────────────────
  UPDATE contacts SET
    is_lead_follow_up = true,
    lead_temperature = 'hot',
    lead_score = 78,
    engagement_score = 30,
    deal_potential_score = 25,
    followup_status = 'active',
    followup_interval_days = 5,
    last_contact_date = now() - interval '3 days',
    next_followup_date = now() + interval '2 days'
  WHERE email = 'jane.smith@techstart.io';

  UPDATE contacts SET
    is_lead_follow_up = true,
    lead_temperature = 'warm',
    lead_score = 52,
    engagement_score = 15,
    deal_potential_score = 20,
    followup_status = 'active',
    followup_interval_days = 7,
    last_contact_date = now() - interval '6 days',
    next_followup_date = now() + interval '1 day'
  WHERE email = 'tom@finedge.io';

  UPDATE contacts SET
    is_lead_follow_up = true,
    lead_temperature = 'warm',
    lead_score = 45,
    engagement_score = 10,
    deal_potential_score = 15,
    followup_status = 'pending',
    followup_interval_days = 14,
    last_contact_date = now() - interval '10 days',
    next_followup_date = now() + interval '4 days'
  WHERE email = 'lisa@healthsync.com';

  UPDATE contacts SET
    is_lead_follow_up = true,
    lead_temperature = 'hot',
    lead_score = 65,
    engagement_score = 25,
    deal_potential_score = 20,
    followup_status = 'active',
    followup_interval_days = 3,
    last_contact_date = now() - interval '1 day',
    next_followup_date = now() + interval '2 days'
  WHERE email = 'david.kim@cloudbase.dev';

  -- ───────────────────────────────────────────────
  -- 4. Add more deal activities for recent context
  -- ───────────────────────────────────────────────
  INSERT INTO deal_activities (deal_id, user_id, activity_type, content, created_at)
  SELECT d.id, u_target, 'note', 'BD follow-up: Sent proposal deck and scheduling demo call.', now() - interval '2 days'
  FROM deals d WHERE d.slug = 'techstart-ai-package'
  ON CONFLICT DO NOTHING;

  INSERT INTO deal_activities (deal_id, user_id, activity_type, content, created_at)
  SELECT d.id, u_target, 'call', 'Discovery call completed — positive feedback on analytics module.', now() - interval '4 days'
  FROM deals d WHERE d.slug = 'finedge-poc'
  ON CONFLICT DO NOTHING;

  INSERT INTO deal_activities (deal_id, user_id, activity_type, content, created_at)
  SELECT d.id, u_target, 'email', 'Intro email sent with product overview and case studies.', now() - interval '8 days'
  FROM deals d WHERE d.slug = 'healthsync-eval'
  ON CONFLICT DO NOTHING;

  INSERT INTO deal_activities (deal_id, user_id, activity_type, content, created_at)
  SELECT d.id, u_target, 'meeting', 'Partnership exploration meeting — alignment on integration goals.', now() - interval '1 day'
  FROM deals d WHERE d.slug = 'cloudbase-devtools'
  ON CONFLICT DO NOTHING;

  RAISE NOTICE 'BD demo data seeded for user %', u_target;
END $$;

-- <<< END: 11-demo-bd-data.sql

-- >>> BEGIN: 11-demo-refresh.sql

-- ============================================================
-- SEED 11: Refresh Demo Data
-- Calls refresh_demo_data() to populate relative-date data
-- for owner/PM/IC dashboards. Safe to re-run anytime.
-- ============================================================
SELECT public.refresh_demo_data();

-- <<< END: 11-demo-refresh.sql
