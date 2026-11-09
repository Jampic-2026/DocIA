import "dotenv/config";
import { Client } from "pg";
import { buildDatabaseUrlFromParts } from "../src/config/database-url";

const targetDatabase = process.env.DB_NAME ?? "jampic_local";
const adminDatabase = process.env.DB_ADMIN_DATABASE ?? "postgres";
const adminDatabaseUrl =
  process.env.DB_ADMIN_URL ??
  buildDatabaseUrlFromParts(process.env, adminDatabase);

function quoteIdentifier(identifier: string) {
  return `"${identifier.replaceAll('"', '""')}"`;
}

async function main() {
  const client = new Client({ connectionString: adminDatabaseUrl });
  await client.connect();

  try {
    const existing = await client.query(
      "SELECT 1 FROM pg_database WHERE datname = $1",
      [targetDatabase],
    );

    if (existing.rowCount) {
      console.log(`Database ${targetDatabase} already exists`);
      return;
    }

    await client.query(`CREATE DATABASE ${quoteIdentifier(targetDatabase)}`);
    console.log(`Database ${targetDatabase} created`);
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
