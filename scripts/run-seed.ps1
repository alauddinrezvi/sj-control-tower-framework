# Run dummy data seed against linked Supabase database.
# Requires DATABASE_URL or SUPABASE_DB_URL in .env (from Supabase Dashboard > Settings > Database).

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$seedFile = Join-Path $ProjectRoot "supabase\seed\dummy-data.sql"
if (-not (Test-Path $seedFile)) {
    Write-Host "Seed file not found: $seedFile" -ForegroundColor Red
    exit 1
}

$dbUrl = $env:DATABASE_URL
if (-not $dbUrl) {
    $envFile = Join-Path $ProjectRoot ".env"
    if (Test-Path $envFile) {
        foreach ($key in @("DATABASE_URL", "SUPABASE_DB_URL", "DB_URL")) {
            $match = Select-String -Path $envFile -Pattern "^$key=`"?([^`"\r\n]+)`"?" | Select-Object -First 1
            if ($match) {
                $dbUrl = $match.Matches[0].Groups[1].Value
                break
            }
        }
    }
}

if (-not $dbUrl) {
    Write-Host "DATABASE_URL not set." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option A - Supabase SQL Editor (recommended):"
    Write-Host "  1. Open Supabase Dashboard > SQL Editor"
    Write-Host "  2. Paste contents of: supabase/seed/dummy-data.sql"
    Write-Host "  3. Run"
    Write-Host ""
    Write-Host "Option B - psql:"
    Write-Host "  Add DATABASE_URL to .env (Settings > Database > Connection string)"
    Write-Host "  Then run: npm run db:seed"
    exit 0
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Host "psql not found. Use Supabase SQL Editor with supabase/seed/dummy-data.sql" -ForegroundColor Yellow
    exit 1
}

Write-Host "Running seed: $seedFile" -ForegroundColor Cyan
& psql $dbUrl -f $seedFile
if ($LASTEXITCODE -eq 0) {
    Write-Host "Dummy data seeded successfully." -ForegroundColor Green
} else {
    Write-Host "Seed failed. Ensure migrations are applied and at least one auth user exists." -ForegroundColor Red
    exit $LASTEXITCODE
}
