// Read-only comparison against the preserved Git commits, including visual source/assets.
const fs = require("node:fs");
const path = require("node:path");
const { createHash } = require("node:crypto");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const snapshot = require("../docs/SOURCE-SNAPSHOT.json");
const permitted = {
  API: new Set([
    "src/app.module.ts",
    "src/config/configuration.ts",
    "src/config/env.validation.ts",
    "src/config/env.validation.spec.ts",
    "src/config/deployment-env.spec.ts",
    "src/config/public-urls.ts",
    "src/config/public-urls.spec.ts",
    "src/main.ts",
    "src/modules/auth/application/auth.service.ts",
    "src/modules/payments/application/payments.service.ts",
    "src/modules/payments/application/payments.service.spec.ts",
  ]),
  "APP-MVP": new Set([
    "lib/modules/files/infrastructure/api/api_files_repository.dart",
    "lib/core/storage/secure_session_storage.dart",
  ]),
  Landing: new Set([
    "index.html",
    "vite.config.ts",
    "src/config/links.ts",
    "src/config/environment.ts",
  ]),
};
const selected = (app, file) =>
  app === "API"
    ? /^(src\/|scripts\/|db\/|package(?:-lock)?\.json$)/.test(file)
    : app === "APP-MVP"
      ? /^(lib\/|assets\/|web\/|android\/|ios\/|linux\/|macos\/|windows\/|pubspec\.(yaml|lock)$)/.test(
          file,
        )
      : /^(src\/|public\/|globals\.css$|index\.html$|(?:vite|tailwind|postcss)\.config\.|package(?:-lock)?\.json$|tsconfig)/.test(
          file,
        );
const visual = (app, file) =>
  app === "APP-MVP"
    ? /^(lib\/.*(?:\/presentation\/|\/theme\/|\/widgets\/)|lib\/app\/|assets\/|web\/|android\/app\/src\/|ios\/Runner\/)/.test(
        file,
      )
    : app === "Landing" &&
      (/\.(?:tsx|css|svg|png|jpe?g|webp|gif|woff2?|ttf)$/.test(file) ||
        /^(src\/config\/(?:brand|content)\.ts|src\/landing\/ui\.ts)$/.test(
          file,
        ));
const blob = (data) =>
  createHash("sha1").update(`blob ${data.length}\0`).update(data).digest("hex");
const matches = (data, hash) =>
  blob(data) === hash ||
  blob(Buffer.from(data.toString("utf8").replace(/\r\n/g, "\n"))) === hash;
const report = {
  baseline:
    "Git commits recorded in SOURCE-SNAPSHOT.json; not an inspection of the live VPS",
  applications: {},
};
let errors = 0;
for (const [app, record] of Object.entries(snapshot.repositories)) {
  const original = path.resolve(root, "..", app);
  if (!fs.existsSync(original))
    throw Error(`Original repository ${app} is required for this local audit.`);
  const tree = execFileSync(
    "git",
    ["-C", original, "ls-tree", "-rz", record.head],
    { stdio: ["ignore", "pipe", "ignore"] },
  ).toString("utf8");
  const files = new Map(
    tree
      .split("\0")
      .filter(Boolean)
      .map((line) => {
        const at = line.indexOf("\t");
        return [line.slice(at + 1), line.slice(0, at).split(" ")[2]];
      }),
  );
  const result = {
    commit: record.head,
    identical: 0,
    visualFilesIdentical: 0,
    expectedChanges: [],
    expectedAdditions: [],
    expectedRemovals: [],
    unexpected: [],
  };
  for (const [file, hash] of files) {
    if (!selected(app, file)) continue;
    const target = path.join(root, app, file);
    if (app === "Landing" && file === "public/downloads/DocIA_V1.0.1.apk") {
      result.expectedRemovals.push(file);
      continue;
    }
    if (!fs.existsSync(target)) {
      result.unexpected.push({ file, reason: "missing" });
      continue;
    }
    if (matches(fs.readFileSync(target), hash)) {
      result.identical++;
      if (visual(app, file)) result.visualFilesIdentical++;
    } else if (permitted[app].has(file)) result.expectedChanges.push(file);
    else result.unexpected.push({ file, reason: "changed" });
  }
  for (const file of Object.keys(record.files)) {
    if (!selected(app, file) || files.has(file)) continue;
    if (permitted[app].has(file)) result.expectedAdditions.push(file);
    else result.unexpected.push({ file, reason: "added" });
  }
  errors += result.unexpected.length;
  report.applications[app] = result;
  console.log(
    `${app}: ${result.identical} archivos idénticos al commit; ${result.visualFilesIdentical} de interfaz/recursos; ${result.unexpected.length} diferencias inesperadas.`,
  );
}
if (process.argv.includes("--write-report"))
  fs.writeFileSync(
    path.join(root, "docs/PARITY-REPORT.json"),
    JSON.stringify(report, null, 2) + "\n",
  );
if (errors) {
  console.error(JSON.stringify(report, null, 2));
  process.exitCode = 1;
}
