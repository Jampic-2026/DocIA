/** Isolated schema regression; never loads dotenv or operational connection settings. */
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { Client } from "pg";

const connection = { host: "127.0.0.1", port: 55439, user: "docia_test" };
const root = path.resolve(__dirname, "..");
const owner = new Client({ ...connection, database: "postgres" });
async function main() {
  await owner.connect();
  const directory = (await owner.query("SHOW data_directory")).rows[0]
    .data_directory as string;
  assert.match(directory.replace(/\\/g, "/"), /\/docia-phase12-pg\/?$/);
  const base = (await readdir(path.join(root, "db")))
    .filter((file) => /^0[1-7]_.+\.sql$/.test(file))
    .sort();
  const migrations = (await readdir(path.join(root, "db", "migrations")))
    .filter(
      (file) => Number(file.slice(0, 4)) >= 13 && /^\d{4}_.+\.sql$/.test(file),
    )
    .sort();
  for (const mode of ["fresh", "upgrade"]) {
    const database =
      "docia_phase12_" + mode + "_" + randomUUID().replace(/-/g, "");
    assert.match(database, /^docia_phase12_(fresh|upgrade)_[a-f0-9]{32}$/);
    await owner.query(`CREATE DATABASE "${database}"`);
    const client = new Client({ ...connection, database });
    try {
      await client.connect();
      for (const file of base) {
        const sql =
          mode === "fresh"
            ? await readFile(path.join(root, "db", file), "utf8")
            : execFileSync(
                "C:/Program Files/Git/cmd/git.exe",
                [
                  "-c",
                  `safe.directory=${root.replace(/\\/g, "/")}`,
                  "-C",
                  root,
                  "show",
                  `78900946982789125653dcf24272670464cd4193:db/${file}`,
                ],
                { encoding: "utf8" },
              );
        await client.query(sql);
      }
      for (const file of migrations) {
        await client.query("BEGIN");
        try {
          await client.query(
            await readFile(path.join(root, "db", "migrations", file), "utf8"),
          );
          await client.query("COMMIT");
        } catch (error) {
          await client.query("ROLLBACK");
          throw new Error(`${mode}: ${file}`, { cause: error });
        }
      }
      const defaults = (
        await client.query(
          "SELECT policy FROM profile_completion_policy WHERE singleton",
        )
      ).rows[0].policy;
      assert.deepEqual(defaults, { rules: [], rewardEnabled: false });
      assert.equal(
        (
          await client.query(
            "SELECT count(*)::int AS count FROM professional_document_requirements",
          )
        ).rows[0].count,
        0,
      );
      const flow = execFileSync(
        process.execPath,
        [
          path.join(root, "node_modules", "tsx", "dist", "cli.mjs"),
          path.join(root, "scripts", "verify-professional-flow.ts"),
          database,
        ],
        { cwd: root, encoding: "utf8", timeout: 120000 },
      );
      console.log(flow.trim());
      const phase3 = execFileSync(
        process.execPath,
        [
          path.join(root, "node_modules", "tsx", "dist", "cli.mjs"),
          path.join(root, "scripts", "verify-phase3-flow.ts"),
          database,
        ],
        { cwd: root, encoding: "utf8", timeout: 120000 },
      );
      console.log(phase3.trim());
      console.log(
        `Schema ${mode}: base 01-07 and ${migrations.length} new migrations passed; reward disabled and required-document configuration empty.`,
      );
    } finally {
      await client.end();
      await owner.query(`DROP DATABASE "${database}"`);
    }
  }
}
main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => owner.end());
