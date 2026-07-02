# Setup database: link Supabase project, apply migrations, optionally seed dummy data.
# Usage: .\scripts\setup-database.ps1 [-Seed] [-ProjectRef <ref>]

param(
    [switch]$Seed,
    [string]$ProjectRef = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "OK  $Message" -ForegroundColor Green
}

function Write-Err([string]$Message) {
    Write-Host "ERR $Message" -ForegroundColor Red
}

function Get-SupabaseCommand {
    $winBin = Join-Path $ProjectRoot "node_modules\.bin\supabase.cmd"
    $unixBin = Join-Path $ProjectRoot "node_modules\.bin\supabase"
    if (Test-Path $winBin) { return $winBin }
    if (Test-Path $unixBin) { return $unixBin }
    return $null
}

Write-Step "Checking Supabase CLI"
$supabase = Get-SupabaseCommand
if (-not $supabase) {
    Write-Err "Supabase CLI not found. Run: npm install"
    exit 1
}

$prevErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$versionOutput = & $supabase --version 2>&1 | Out-String
$ErrorActionPreference = $prevErrorAction
$version = ($versionOutput -split "`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1).Trim()
Write-Ok "Supabase CLI: $version"

if (-not $ProjectRef) {
    $envFile = Join-Path $ProjectRoot ".env"
    if (Test-Path $envFile) {
        $match = Select-String -Path $envFile -Pattern 'VITE_SUPABASE_PROJECT_ID="?([^"\r\n]+)"?' | Select-Object -First 1
        if ($match) {
            $ProjectRef = $match.Matches[0].Groups[1].Value
        }
    }
}

if (-not $ProjectRef) {
    Write-Err "Project ref not found. Pass -ProjectRef or set VITE_SUPABASE_PROJECT_ID in .env"
    exit 1
}

Write-Step "Linking Supabase project: $ProjectRef"
$ErrorActionPreference = "Continue"
& $supabase link --project-ref $ProjectRef
$linkExit = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($linkExit -ne 0) {
    Write-Err "Failed to link project. Run: npx supabase login"
    exit $linkExit
}
Write-Ok "Project linked"

Write-Step "Applying migrations"
$ErrorActionPreference = "Continue"
$output = & $supabase db push --yes 2>&1 | Out-String
$exitCode = $LASTEXITCODE
$ErrorActionPreference = "Stop"
Write-Host $output
if ($exitCode -ne 0) {
    Write-Err "Migration failed"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Run: npm run migrations:repair"
    Write-Host "  - Or:  npm run migrations:mark-applied (if schema already exists)"
    exit $exitCode
}
Write-Ok "Migrations applied"

if ($Seed) {
    Write-Step "Seeding dummy data"
    Write-Host "Dummy data requires at least one auth user."
    Write-Host "Sign up via the app first, then run seed in Supabase SQL Editor:"
    Write-Host "  supabase/seed/dummy-data.sql"
    Write-Host ""
    Write-Host "Or run: npm run db:seed (requires DATABASE_URL in .env)"
} else {
    Write-Step "Next steps"
    Write-Host "1. Start the app: npm run dev"
    Write-Host "2. Sign up a user at http://localhost:8080"
    Write-Host "3. Grant admin: INSERT INTO user_roles (user_id, role) VALUES ('<user-id>', 'admin');"
    Write-Host "4. Seed dummy data: npm run db:seed"
    Write-Host "   Or paste supabase/seed/dummy-data.sql into Supabase SQL Editor"
}

Write-Ok "Database setup complete"
