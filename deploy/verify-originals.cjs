const fs = require("node:fs");
const path = require("node:path");
const { createHash } = require("node:crypto");
const { execFileSync } = require("node:child_process");
const parent = path.resolve(__dirname, "../..");
const manifest = require("../docs/SOURCE-SNAPSHOT.json");
const hash = (value) => createHash("sha256").update(value).digest("hex");
let checked = 0;
let failed = false;
for (const [name, snapshot] of Object.entries(manifest.repositories)) {
  const root = path.join(parent, name);
  if (!fs.existsSync(root)) {
    console.log(
      `${name}: copia original ausente; comprobación local no aplicable.`,
    );
    continue;
  }
  for (const [file, expected] of Object.entries(snapshot.files)) {
    if (
      !fs.existsSync(path.join(root, file)) ||
      hash(fs.readFileSync(path.join(root, file))) !== expected
    ) {
      console.error(`${name}/${file}: difiere de la copia inicial.`);
      failed = true;
    }
    checked++;
  }
  const git = (args) =>
    execFileSync("git", ["-C", root, ...args], {
      stdio: ["ignore", "pipe", "ignore"],
    });
  if (git(["rev-parse", "HEAD"]).toString().trim() !== snapshot.head) {
    console.error(`${name}: cambió HEAD.`);
    failed = true;
  }
  // File hashes establish content integrity, including dirty worktree changes present before migration.
}
console.log(`Integridad comprobada: ${checked} archivos originales.`);
if (failed) process.exitCode = 1;
