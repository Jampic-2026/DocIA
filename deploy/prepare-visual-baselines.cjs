// Local only: export public application source from the preserved original commits.
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const snapshot = require("../docs/SOURCE-SNAPSHOT.json");
const temporary = path.join(root, ".validation");
fs.mkdirSync(temporary, { recursive: true });
for (const [app, destination] of [
  ["APP-MVP", "baseline-flutter"],
  ["Landing", "baseline-landing"],
]) {
  const original = path.resolve(root, "..", app);
  const target = path.join(temporary, destination);
  if (!fs.existsSync(original))
    throw Error(`La carpeta original ${app} debe estar junto al monorepo.`);
  if (fs.existsSync(target))
    throw Error(`Ya existe ${destination}; se conserva sin sobrescribir.`);
  const commit = snapshot.repositories[app].head;
  const tree = execFileSync("git", ["-C", original, "ls-tree", "-rz", commit])
    .toString()
    .split("\0")
    .filter(Boolean);
  const files = tree
    .map((line) => line.slice(line.indexOf("\t") + 1))
    .filter(
      (file) =>
        !file.startsWith("deploy/") &&
        !file.startsWith(".github/") &&
        !file.startsWith("public/downloads/") &&
        !/^\.(?:git|env)/.test(file) &&
        !/(?:^|\/)(?:key\.properties|local\.properties)$|\.(?:jks|keystore|p12|pfx|key)$/.test(
          file,
        ),
    );
  const archive = path.join(temporary, destination + ".tar");
  execFileSync("git", [
    "-C",
    original,
    "archive",
    "--format=tar",
    "-o",
    archive,
    commit,
    "--",
    ...files,
  ]);
  fs.mkdirSync(target);
  execFileSync("tar", ["-xf", archive, "-C", target]);
  console.log(`${app}: baseline pública preparada desde ${commit}.`);
}
