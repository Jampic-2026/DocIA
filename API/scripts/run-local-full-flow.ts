import "dotenv/config";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { Client } from "pg";
import { buildDatabaseUrl } from "../src/config/database-url";

async function main() {
  if (process.env.DB_APPLY_LOCAL_SEEDS !== "true") {
    throw new Error(
      "Defina DB_APPLY_LOCAL_SEEDS=true antes de cargar datos locales de prueba.",
    );
  }

  const sqlPath = path.resolve(
    process.cwd(),
    "db/local_full_flow_test_data.sql",
  );
  const sql = await readFile(sqlPath, "utf8");
  const client = new Client({ connectionString: buildDatabaseUrl(process.env) });

  await client.connect();
  try {
    const result = await client.query(sql);
    const summary = Array.isArray(result)
      ? result.findLast((entry) => entry.command === "SELECT")?.rows[0]
      : result.rows[0];
    console.log("Escenario integral local cargado correctamente.", summary);
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
