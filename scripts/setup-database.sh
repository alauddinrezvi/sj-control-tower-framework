#!/usr/bin/env bash
#
# Setup database: link Supabase project, apply migrations, optionally seed dummy data.
# Usage: ./scripts/setup-database.sh [--seed] [--project-ref REF]
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

SEED=false
PROJECT_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed) SEED=true; shift ;;
    --project-ref) PROJECT_REF="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

step() { echo -e "\n${CYAN}==> $1${NC}"; }
ok() { echo -e "${GREEN}OK  $1${NC}"; }
err() { echo -e "${RED}ERR $1${NC}"; }

step "Checking Supabase CLI"
SUPABASE_CMD=""
if [[ -x "$PROJECT_ROOT/node_modules/.bin/supabase" ]]; then
  SUPABASE_CMD="$PROJECT_ROOT/node_modules/.bin/supabase"
elif [[ -f "$PROJECT_ROOT/node_modules/.bin/supabase.cmd" ]]; then
  SUPABASE_CMD="$PROJECT_ROOT/node_modules/.bin/supabase.cmd"
elif command -v npx &> /dev/null; then
  SUPABASE_CMD="npx supabase"
else
  err "Supabase CLI not found. Run: npm install"
  exit 1
fi

version=$($SUPABASE_CMD --version 2>&1 | head -n 1)
ok "Supabase CLI: $version"

if [[ -z "$PROJECT_REF" && -f "$PROJECT_ROOT/.env" ]]; then
  PROJECT_REF=$(grep -E '^VITE_SUPABASE_PROJECT_ID=' "$PROJECT_ROOT/.env" | head -n 1 | cut -d= -f2- | tr -d '"'\''\r')
fi

if [[ -z "$PROJECT_REF" ]]; then
  err "Project ref not found. Pass --project-ref or set VITE_SUPABASE_PROJECT_ID in .env"
  exit 1
fi

step "Linking Supabase project: $PROJECT_REF"
if ! $SUPABASE_CMD link --project-ref "$PROJECT_REF"; then
  err "Failed to link project. Run: npx supabase login"
  exit 1
fi
ok "Project linked"

step "Applying migrations"
if ! $SUPABASE_CMD db push --yes; then
  err "Migration failed"
  echo -e "${YELLOW}Troubleshooting:${NC}"
  echo "  - Run: npm run migrations:repair"
  echo "  - Or:  npm run migrations:mark-applied (if schema already exists)"
  exit 1
fi
ok "Migrations applied"

if [[ "$SEED" == true ]]; then
  step "Seeding dummy data"
  echo "Dummy data requires at least one auth user."
  echo "Sign up via the app first, then run seed in Supabase SQL Editor:"
  echo "  supabase/seed/dummy-data.sql"
  echo ""
  echo "Or run: npm run db:seed (requires DATABASE_URL in .env)"
else
  step "Next steps"
  echo "1. Start the app: npm run dev"
  echo "2. Sign up a user at http://localhost:8080"
  echo "3. Grant admin: INSERT INTO user_roles (user_id, role) VALUES ('<user-id>', 'admin');"
  echo "4. Seed dummy data: npm run db:seed"
  echo "   Or paste supabase/seed/dummy-data.sql into Supabase SQL Editor"
fi

ok "Database setup complete"
