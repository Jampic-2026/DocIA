const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { packageRelease } = require("../package.cjs");
const id = "a".repeat(40) + "-1-1";
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "docia-package-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const write = (file, value) => {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), value);
  };
  write(
    "config/environments/production.env",
    "PUBLIC_API_URL=https://api.example.com\nPUBLIC_WEB_URL=https://app.example.com\nPUBLIC_LANDING_URL=https://landing.example.com\nAPI_PREFIX=api/v1\n",
  );
  write("Landing/dist/index.html", '<script src="/assets/a.js"></script>');
  write("Landing/dist/assets/a.js", "hello");
  return { root, write };
}
test("archive contains only static build, marker, manifest and immutable public config", (t) => {
  const { root, write } = fixture(t);
  write("Landing/.env", "private");
  const archive = packageRelease("landing", root, id);
  const names = execFileSync("tar", ["-tzf", archive], { encoding: "utf8" });
  assert.match(names, /PUBLIC_CONFIG.env/);
  assert.match(names, /docia-assets.sha256/);
  assert.doesNotMatch(names, /(?:^|\/)\.env(?:\r?\n|$)/m);
  assert.match(
    fs.readFileSync(archive.replace(".tar.gz", ".sha256"), "utf8"),
    /^[0-9a-f]{64}\n$/,
  );
});
test("private file inside compiled assets blocks packaging", (t) => {
  const { root, write } = fixture(t);
  write("Landing/dist/.env", "private");
  assert.throws(() => packageRelease("landing", root, id), /privado/);
});
test("APK embedded in old landing is excluded", (t) => {
  const { root, write } = fixture(t);
  write("Landing/dist/downloads/old.apk", "stale");
  const names = execFileSync(
    "tar",
    ["-tzf", packageRelease("landing", root, id)],
    { encoding: "utf8" },
  );
  assert.doesNotMatch(names, /old.apk/);
});
test("missing landing JavaScript blocks publication", (t) => {
  const { root } = fixture(t);
  fs.unlinkSync(path.join(root, "Landing/dist/assets/a.js"));
  assert.throws(() => packageRelease("landing", root, id), /incompleta/);
});
test("invalid release identifier cannot create a path outside releases", (t) => {
  const { root } = fixture(t);
  assert.throws(() => packageRelease("landing", root, "../escape"), /inválido/);
});
test("web cannot be packaged without signed Android metadata", (t) => {
  const { root, write } = fixture(t);
  write("APP-MVP/build/web/index.html", "html");
  write("APP-MVP/build/web/flutter_bootstrap.js", "js");
  assert.throws(() => packageRelease("web", root, id));
});
