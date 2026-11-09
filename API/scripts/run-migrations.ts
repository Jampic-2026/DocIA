import "dotenv/config";
import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { Client } from "pg";
import { buildDatabaseUrl } from "../src/config/database-url";

const migrationsDir = path.resolve(process.cwd(), "db", "migrations");
const databaseUrl = buildDatabaseUrl(process.env);
const client = new Client({ connectionString: databaseUrl });

function isMigrationFile(file: string) {
  return /^\d{4}_.+\.sql$/i.test(file);
}

async function ensureMigrationTable() {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      checksum TEXT NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

async function main() {
  await client.connect();
  await ensureMigrationTable();

  const files = (await readdir(migrationsDir)).filter(isMigrationFile).sort();

  for (const file of files) {
    const sql = await readFile(path.join(migrationsDir, file), "utf8");
    const checksum = createHash("sha256").update(sql).digest("hex");
    const applied = await client.query<{ checksum: string }>(
      "SELECT checksum FROM schema_migrations WHERE filename=$1",
      [file],
    );

    if (applied.rows[0]) {
      if (applied.rows[0].checksum !== checksum) {
        throw new Error(
          `Migration ${file} ya fue aplicada con otro checksum. Crea una migracion nueva en vez de editarla.`,
        );
      }
      console.log(`Skipping ${file}`);
      continue;
    }

    console.log(`Applying ${file}`);
    await client.query("BEGIN");
    try {
      await client.query(sql);
      await client.query(
        `INSERT INTO schema_migrations(filename,checksum)
         VALUES($1,$2)`,
        [file, checksum],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    }
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await client.end();
  });
