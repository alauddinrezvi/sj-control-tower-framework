# Database Migrations

This directory contains **242 SQL migration files** that create the full SJ Control Tower database schema (tables, RLS policies, functions, triggers, indexes).

## Quick Setup (New Supabase Project)

### 1. Prerequisites

- [Supabase account](https://supabase.com) with a new project created
- Node.js 18+ and `npm install` completed
- `.env` configured with your project credentials (`VITE_SUPABASE_PROJECT_ID`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`)

### 2. Apply Migrations (create all tables)

**Windows (recommended):**

```powershell
npm run db:setup
```

**macOS / Linux:**

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npm run migrations:run
```

This runs `supabase db push` and applies all 242 migrations in timestamp order.

### 3. Create Admin User

1. Start the app: `npm run dev`
2. Sign up at http://localhost:8080
3. In Supabase Dashboard → SQL Editor, grant admin:

```sql
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role FROM auth.users WHERE email = 'your@email.com'
ON CONFLICT (user_id, role) DO NOTHING;
```

### 4. Load Dummy Data

One consolidated seed file: **`supabase/seed/dummy-data.sql`**

**Option A — Supabase SQL Editor (easiest):**

1. Open Supabase Dashboard → SQL Editor
2. Paste the full contents of `supabase/seed/dummy-data.sql`
3. Click Run

**Option B — CLI (requires `DATABASE_URL` in `.env`):**

```powershell
npm run db:seed
```

Dummy data includes: clients, tasks, EOS/OKRs, meetings, knowledge base entries, projects, deals, productivity records, AI agents, and notifications.

---

## Migration File Structure

```
supabase/
├── migrations/           # 242 schema migrations (this folder)
│   ├── 20251231002141_*.sql   # Foundation: profiles, roles, clients, meetings, knowledge
│   ├── 20260201_*.sql         # App modules, RBAC extensions
│   ├── 20260623120000_automation_engine.sql
│   ├── 20260629120000_graphify_core.sql
│   └── ...
├── seed/
│   ├── dummy-data.sql    # Single consolidated dummy data file
│   ├── 00-platform-core.sql   # Individual module seeds (used to build dummy-data.sql)
│   └── ...
└── seed.sql              # Auto-loaded on `supabase db reset` (local dev)
```

### Naming Conventions

- `YYYYMMDDHHMMSS_<description>.sql` — descriptive migrations
- `YYYYMMDDHHMMSS_<uuid>.sql` — Lovable-generated migrations

### Typical Migration Pattern

```sql
CREATE TABLE IF NOT EXISTS public.my_table (...);
CREATE INDEX IF NOT EXISTS idx_my_table_... ON public.my_table(...);
ALTER TABLE public.my_table ENABLE ROW LEVEL SECURITY;
CREATE POLICY "..." ON public.my_table FOR SELECT TO authenticated USING (...);
NOTIFY pgrst, 'reload schema';
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| Remote migration versions not found | `npm run migrations:repair` |
| Table already exists | `npm run migrations:mark-applied` then `npm run migrations:run` |
| Seed aborted: no auth users | Sign up a user first, then re-run seed |
| Project not linked | `npx supabase link --project-ref YOUR_PROJECT_REF` |

---

## Regenerate TypeScript Types

After applying migrations:

```bash
npx supabase gen types typescript --project-id YOUR_PROJECT_REF > src/integrations/supabase/types.ts
```

---

**Database:** PostgreSQL 15 via Supabase  
**Tables:** ~206 tables + 13 views  
**Last updated:** 2026-07-02
