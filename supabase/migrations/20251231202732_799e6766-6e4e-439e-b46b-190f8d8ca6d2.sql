-- =============================================
-- DEMO DATA (skips when no auth users exist; uses first user as owner)
-- =============================================

DO $$
DECLARE
  u1 UUID;
BEGIN
  SELECT id INTO u1 FROM auth.users ORDER BY created_at LIMIT 1;
  IF u1 IS NULL THEN
    RAISE NOTICE 'Skipping demo data migration - no auth users yet';
    RETURN;
  END IF;

  UPDATE profiles
  SET full_name = COALESCE(full_name, 'Demo User'),
      avatar_url = COALESCE(avatar_url, 'https://api.dicebear.com/7.x/initials/svg?seed=DU')
  WHERE id = u1;

  IF NOT EXISTS (SELECT 1 FROM clients WHERE email = 'mrichardson@richardson-lawgroup.com') THEN
    INSERT INTO clients (name, email, company, phone, status, metadata, created_by) VALUES
    ('Michael Richardson', 'mrichardson@richardson-lawgroup.com', 'Richardson Law Group LLP', '+1-555-0101', 'active', '{"industry": "Law Firm"}', u1),
    ('Sarah Chen', 'schen@chenandpartners.com', 'Chen & Partners', '+1-555-0102', 'active', '{"industry": "Law Firm"}', u1),
    ('James Thompson', 'jthompson@thompson-legal.com', 'Thompson Legal Associates', '+1-555-0103', 'active', '{"industry": "Law Firm"}', u1),
    ('Jennifer Adams', 'jadams@adams-cpa.com', 'Adams & Associates CPA', '+1-555-0201', 'active', '{"industry": "CPA Firm"}', u1),
    ('William Foster', 'wfoster@fosteraccounting.com', 'Foster Accounting Group', '+1-555-0202', 'active', '{"industry": "Accounting Firm"}', u1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM meetings WHERE title = 'Case Management System Demo') THEN
    INSERT INTO meetings (title, description, scheduled_at, duration_minutes, status, meeting_type, organizer_id, client_id) VALUES
    ('Case Management System Demo', 'Present custom case management solution.', '2025-01-03 10:00:00-05', 90, 'scheduled', 'virtual', u1, (SELECT id FROM clients WHERE company = 'Richardson Law Group LLP' LIMIT 1)),
    ('Tax Workflow Sprint Planning', 'Sprint planning for tax season automation.', '2025-01-06 14:00:00-05', 60, 'scheduled', 'virtual', u1, (SELECT id FROM clients WHERE company = 'Adams & Associates CPA' LIMIT 1)),
    ('Q4 Review', 'Quarterly review.', '2024-12-20 10:00:00-05', 60, 'completed', 'virtual', u1, (SELECT id FROM clients WHERE company = 'Thompson Legal Associates' LIMIT 1));
  END IF;

  INSERT INTO ai_agents (slug, name, description, system_prompt, category, is_enabled, memory_enabled, provider_config) VALUES
  ('legal-research', 'Legal Research Assistant', 'Research case law and legal precedents.', 'You are an expert legal research assistant.', 'legal', true, true, '{"model": "gpt-4", "temperature": 0.3}'),
  ('tax-advisor', 'Tax Research Assistant', 'Research tax regulations and IRS guidance.', 'You are a tax research assistant.', 'accounting', true, true, '{"model": "gpt-4", "temperature": 0.3}'),
  ('client-communicator', 'Client Email Composer', 'Draft professional communications.', 'You are an expert at drafting professional client communications.', 'productivity', true, false, '{"model": "gpt-4", "temperature": 0.5}')
  ON CONFLICT (slug) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM notifications WHERE user_id = u1 AND title = 'Welcome to Control Tower') THEN
    INSERT INTO notifications (user_id, title, message, type, link, is_read) VALUES
    (u1, 'Welcome to Control Tower', 'Your demo workspace is ready.', 'info', '/dashboard', false),
    (u1, 'Meeting in 1 Hour', 'Case Management Demo starts soon', 'warning', '/meetings', false),
    (u1, 'Knowledge Updated', 'New article published', 'info', '/knowledge', true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM feedback WHERE user_id = u1 AND subject = 'Excellent platform') THEN
    INSERT INTO feedback (user_id, type, subject, message, rating, status) VALUES
    (u1, 'general', 'Excellent platform', 'Demo feedback entry.', 5, 'reviewed'),
    (u1, 'feature', 'Mobile App', 'Would love a mobile view.', null, 'pending');
  END IF;
END $$;
