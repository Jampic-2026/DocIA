import "dotenv/config";
import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { Client } from "pg";
import { buildDatabaseUrl } from "../src/config/database-url";

const sqlDir = path.resolve(process.cwd(), "db");
const databaseUrl = buildDatabaseUrl(process.env);
const applyLocalSeeds = process.env.DB_APPLY_LOCAL_SEEDS === "true";

const client = new Client({ connectionString: databaseUrl });

function isNumberedSql(file: string) {
  return /^\d{2}_.+\.sql$/i.test(file);
}

function isLocalSeed(file: string) {
  return /_local_/i.test(file);
}

async function main() {
  await client.connect();
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_sql_files (
      filename TEXT PRIMARY KEY,
      checksum TEXT,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    ALTER TABLE schema_sql_files
      ADD COLUMN IF NOT EXISTS checksum TEXT;
  `);

  const files = (await readdir(sqlDir)).filter(isNumberedSql).sort();

  for (const file of files) {
    if (isLocalSeed(file) && !applyLocalSeeds) {
      console.log(
        `Skipping ${file} (set DB_APPLY_LOCAL_SEEDS=true to apply local seeds)`,
      );
      continue;
    }

    const sql = await readFile(path.join(sqlDir, file), "utf8");
    const checksum = createHash("sha256").update(sql).digest("hex");
    const alreadyApplied = await client.query<{ checksum: string | null }>(
      "SELECT checksum FROM schema_sql_files WHERE filename = $1",
      [file],
    );

    if (alreadyApplied.rows[0]?.checksum === checksum) {
      console.log(`Skipping ${file}`);
      continue;
    }

    console.log(
      alreadyApplied.rowCount ? `Reapplying ${file}` : `Applying ${file}`,
    );

    await client.query("BEGIN");
    try {
      await client.query(sql);
      await client.query(
        `INSERT INTO schema_sql_files(filename,checksum)
         VALUES($1,$2)
         ON CONFLICT(filename) DO UPDATE
         SET checksum=EXCLUDED.checksum,applied_at=now()`,
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
