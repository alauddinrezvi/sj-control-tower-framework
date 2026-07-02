import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "..");

function resolveSupabaseCommand() {
  const winBin = path.join(projectRoot, "node_modules", ".bin", "supabase.cmd");
  const unixBin = path.join(projectRoot, "node_modules", ".bin", "supabase");
  if (existsSync(winBin)) return winBin;
  if (existsSync(unixBin)) return unixBin;
  return null;
}

function readProjectRef() {
  const envPath = path.join(projectRoot, ".env");
  if (!existsSync(envPath)) return "";
  const match = readFileSync(envPath, "utf8").match(
    /^VITE_SUPABASE_PROJECT_ID=["']?([^"'\r\n]+)["']?/m,
  );
  return match?.[1] ?? "";
}

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: projectRoot,
    stdio: "inherit",
    shell: process.platform === "win32",
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

const seed = process.argv.includes("--seed");
const projectRefArg = process.argv.find((arg) => arg.startsWith("--project-ref="));
const projectRef = projectRefArg?.split("=")[1] ?? readProjectRef();

const supabase = resolveSupabaseCommand();
if (!supabase) {
  console.error("ERR Supabase CLI not found. Run: npm install");
  process.exit(1);
}

const version = spawnSync(supabase, ["--version"], {
  cwd: projectRoot,
  encoding: "utf8",
  shell: process.platform === "win32",
});
const versionLine = (version.stdout ?? version.stderr ?? "").split("\n")[0].trim();
console.log(`OK  Supabase CLI: ${versionLine}`);

if (!projectRef) {
  console.error("ERR Project ref not found. Set VITE_SUPABASE_PROJECT_ID in .env");
  process.exit(1);
}

console.log(`\n==> Linking Supabase project: ${projectRef}`);
run(supabase, ["link", "--project-ref", projectRef]);

console.log("\n==> Applying migrations");
run(supabase, ["db", "push", "--yes"]);

if (seed) {
  console.log("\n==> Seeding dummy data");
  console.log("Sign up via the app first, then run: npm run db:seed");
  console.log("Or paste supabase/seed/dummy-data.sql into Supabase SQL Editor");
} else {
  console.log("\n==> Next steps");
  console.log("1. npm run dev");
  console.log("2. Sign up at http://localhost:8080");
  console.log("3. Grant admin role in Supabase SQL Editor");
  console.log("4. npm run db:seed");
}

console.log("\nOK  Database setup complete");
