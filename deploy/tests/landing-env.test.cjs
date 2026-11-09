const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const vm = require("node:vm");
const { spawnSync } = require("node:child_process");
const { createRequire } = require("node:module");
const ts = createRequire(
  require("node:path").resolve(__dirname, "../../Landing/package.json"),
)("typescript");
const source = fs.readFileSync(
  path.join(__dirname, "../../Landing/src/config/environment.ts"),
  "utf8",
);
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
}).outputText;
const context = { exports: {}, URL };
vm.runInNewContext(compiled, context);
const { readPublicEnvironment } = context.exports;
const valid = {
  VITE_SITE_URL: "https://example.com",
  VITE_WEB_APP_URL: "https://app.example.com",
};

test("requires explicit production origins and retains relative APK downloads", () => {
  const env = readPublicEnvironment(valid, true);
  assert.equal(env.webApp, valid.VITE_WEB_APP_URL);
  assert.equal(env.androidApk, "/downloads/DocIA.apk");
  assert.throws(() => readPublicEnvironment({}, true), /VITE_SITE_URL/);
  assert.equal(
    readPublicEnvironment({}, false).siteUrl,
    "http://localhost:5173",
  );
});
for (const [key, value] of [
  ["VITE_WEB_APP_URL", "http://localhost:3000"],
  ["VITE_SITE_URL", "https://user:synthetic-private-value@example.com"],
  ["VITE_ANDROID_APK_URL", "//evil.example.com/DocIA.apk"],
]) {
  test(`rejects unsafe ${key} without echoing its value`, () => {
    assert.throws(
      () => readPublicEnvironment({ ...valid, [key]: value }, true),
      (error) => !error.message.includes("synthetic-private-value"),
    );
  });
}
test("CI exports only validated frontend values without credentials", () => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), "docia-landing-env-"),
  );
  try {
    const output = path.join(directory, "env");
    const env = {
      ...process.env,
      GITHUB_ENV: output,
      DOCIA_PUBLIC_CONFIG_JSON: JSON.stringify({
        PUBLIC_API_URL: "https://api.example.com",
        PUBLIC_WEB_URL: "https://app.example.com",
        PUBLIC_LANDING_URL: "https://example.com",
      }),
    };
    const result = spawnSync(
      process.execPath,
      [path.join(__dirname, "../write-landing-config.cjs")],
      { env, encoding: "utf8" },
    );
    assert.equal(result.status, 0, result.stderr);
    assert.match(
      fs.readFileSync(output, "utf8"),
      /VITE_SITE_URL=https:\/\/example.com/,
    );
    assert.doesNotMatch(
      fs.readFileSync(output, "utf8"),
      /PUBLIC_API_URL|PASSWORD|TOKEN/,
    );
    const failed = spawnSync(
      process.execPath,
      [path.join(__dirname, "../write-landing-config.cjs")],
      {
        env: {
          ...env,
          DOCIA_PUBLIC_CONFIG_JSON: '{"PASSWORD":"synthetic-private-value"}',
        },
        encoding: "utf8",
      },
    );
    assert.equal(failed.status, 1);
    assert.doesNotMatch(
      failed.stdout + failed.stderr,
      /synthetic-private-value/,
    );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
