const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs"),
  path = require("node:path"),
  os = require("node:os");
const { inventory, entries } = require("../audit-api-env.cjs");
const project = path.resolve(__dirname, "../..");
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "docia-env-inventory-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const file of [
    "API/.env.example",
    "API/src/config/env.validation.ts",
    "config/api-env-contract.json",
  ]) {
    const target = path.join(root, file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(path.join(project, file), target);
  }
  return root;
}
test("all original example variables and all runtime schema variables have a destination", () => {
  const report = inventory(project);
  assert.equal(report.originalContractVariables, 66);
  assert.equal(report.totalVariables, 68);
  assert.equal(
    report.variables.find((v) => v.key === "FCM_SERVICE_ACCOUNT_PATH")
      .classification,
    "private-runtime",
  );
  assert.equal(
    report.variables.find((v) => v.key === "PORT").effectiveValue,
    "3100",
  );
});
test("commented explanations do not hide the active example assignment", () =>
  assert.deepEqual(
    entries(
      "# STORAGE_PROVIDER=gcs describes an alternative\nSTORAGE_PROVIDER=local\n",
    ),
    [{ key: "STORAGE_PROVIDER", optional: false, example: "local" }],
  ));
test("missing original variable fails even without sibling repositories", (t) => {
  const root = fixture(t),
    file = path.join(root, "API/.env.example");
  fs.writeFileSync(
    file,
    fs.readFileSync(file, "utf8").replace(/^DB_PASSWORD=.*\r?\n/m, ""),
  );
  assert.throws(() => inventory(root), /DB_PASSWORD/);
});
test("changing an original example default is detected without disclosing its value", (t) => {
  const root = fixture(t),
    file = path.join(root, "API/.env.example");
  fs.writeFileSync(
    file,
    fs
      .readFileSync(file, "utf8")
      .replace(/^DB_PASSWORD=.*$/m, "DB_PASSWORD=synthetic-private-marker"),
  );
  assert.throws(
    () => inventory(root),
    (e) =>
      e.message.includes("DB_PASSWORD") &&
      !e.message.includes("synthetic-private-marker"),
  );
});
test("a runtime variable missing from the example fails the audit", (t) => {
  const root = fixture(t),
    file = path.join(root, "API/src/config/env.validation.ts");
  fs.appendFileSync(file, "\n    UNDOCUMENTED_PROVIDER_TOKEN: z.string(),\n");
  assert.throws(() => inventory(root), /UNDOCUMENTED_PROVIDER_TOKEN/);
});
