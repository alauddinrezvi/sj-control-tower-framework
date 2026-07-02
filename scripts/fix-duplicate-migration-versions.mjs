import { readdirSync, renameSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.join(__dirname, "..", "supabase", "migrations");

function parseMigration(filename) {
  const match = filename.match(/^(\d+)_(.+)$/);
  if (!match) return null;
  return { filename, version: match[1], suffix: match[2] };
}

const migrations = readdirSync(migrationsDir)
  .filter((f) => f.endsWith(".sql"))
  .map(parseMigration)
  .filter((m) => m !== null)
  .sort((a, b) => a.filename.localeCompare(b.filename));

const byVersion = new Map();
for (const migration of migrations) {
  const group = byVersion.get(migration.version) ?? [];
  group.push(migration);
  byVersion.set(migration.version, group);
}

const renames = [];

for (const [version, group] of byVersion) {
  if (group.length <= 1) continue;

  group.sort((a, b) => a.filename.localeCompare(b.filename));
  const base = BigInt(version.padEnd(14, "0"));

  for (let i = 1; i < group.length; i += 1) {
    const migration = group[i];
    const newVersion = String(base + BigInt(i)).padStart(14, "0");
    const newFilename = `${newVersion}_${migration.suffix}`;
    if (newFilename !== migration.filename) {
      renames.push({ from: migration.filename, to: newFilename });
    }
  }
}

if (renames.length === 0) {
  console.log("No duplicate migration versions found.");
  process.exit(0);
}

console.log(`Renaming ${renames.length} migration file(s):\n`);
for (const { from, to } of renames) {
  renameSync(path.join(migrationsDir, from), path.join(migrationsDir, to));
  console.log(`  ${from} -> ${to}`);
}

console.log("\nDone.");
