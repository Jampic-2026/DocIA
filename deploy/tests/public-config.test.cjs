const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { validate, parseEnv, render } = require("../public-config.cjs");
const sites = {
  PUBLIC_API_URL: "https://api.example.com",
  PUBLIC_WEB_URL: "https://app.example.com",
  PUBLIC_LANDING_URL: "https://example.com",
  API_PREFIX: "api/v1",
};

test("normalizes origins and reads public dotenv without executing shell interpolation", () => {
  assert.deepEqual(
    validate({ ...sites, PUBLIC_WEB_URL: sites.PUBLIC_WEB_URL + "/" }),
    sites,
  );
  assert.deepEqual(
    parseEnv(
      Object.entries(sites)
        .map(([key, value]) => `${key}="${value}"`)
        .join("\r\n"),
    ),
    sites,
  );
  assert.throws(
    () => parseEnv("PUBLIC_API_URL=$(synthetic-private-value)"),
    /inválida/,
  );
  assert.throws(
    () =>
      parseEnv(
        "PUBLIC_API_URL=https://api.example.com\nPUBLIC_API_URL=https://other.example.com",
      ),
    /inválida/,
  );
});

for (const [name, changes] of Object.entries({
  secrets: { PASSWORD: "synthetic-private-value" },
  credentials: {
    PUBLIC_API_URL: "https://user:synthetic-private-value@api.example.com",
  },
  insecure: { PUBLIC_API_URL: "http://api.example.com" },
  path: { PUBLIC_WEB_URL: "https://app.example.com/unexpected" },
  query: { PUBLIC_WEB_URL: "https://app.example.com/?x=1" },
  wildcard: { PUBLIC_WEB_URL: "https://*.example.com" },
  localhost: { PUBLIC_API_URL: "https://localhost" },
  duplicate: { PUBLIC_WEB_URL: sites.PUBLIC_API_URL },
  injection: { API_PREFIX: "api/v1; synthetic-private-value" },
})) {
  test(`rejects ${name} without disclosing values`, () => {
    assert.throws(
      () => validate({ ...sites, ...changes }),
      (error) => !error.message.includes("synthetic-private-value"),
    );
  });
}

test("changing three origins updates generated frontend, server, TLS, health configuration and CSP together", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "docia-public-"));
  try {
    const changed = {
      PUBLIC_API_URL: "https://next-api.duckdns.org",
      PUBLIC_WEB_URL: "https://next-app.duckdns.org",
      PUBLIC_LANDING_URL: "https://next-landing.duckdns.org",
      API_PREFIX: "v2",
    };
    render(changed, directory);
    const flutter = JSON.parse(
      fs.readFileSync(path.join(directory, "flutter-production.json")),
    );
    assert.equal(flutter.API_BASE_URL, "https://next-api.duckdns.org/v2/");
    assert.match(
      fs.readFileSync(path.join(directory, "landing-production.env"), "utf8"),
      /VITE_WEB_APP_URL=https:\/\/next-app.duckdns.org/,
    );
    const web = fs.readFileSync(path.join(directory, "docia-web.conf"), "utf8");
    assert.match(web, /connect-src 'self' https:\/\/next-api.duckdns.org /);
    assert.match(web, /live\/next-app.duckdns.org\/fullchain.pem/);
    assert.match(web, /current-web\/web/);
    assert.match(
      fs.readFileSync(path.join(directory, "docia-landing.conf"), "utf8"),
      /current-web\/web\/downloads\/DocIA.apk/,
    );
    for (const file of fs.readdirSync(directory))
      assert.doesNotMatch(
        fs.readFileSync(path.join(directory, file), "utf8"),
        /api.example.com|app.example.com|doc-ia.cloud/,
      );
    assert.equal(
      JSON.parse(
        fs.readFileSync(path.join(directory, "github-public-config.json")),
      ).API_PREFIX,
      "v2",
    );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test("invalid CLI input does not echo configuration or credentials", () => {
  const result = spawnSync(
    process.execPath,
    [
      path.resolve(__dirname, "../public-config.cjs"),
      "render",
      "nonexistent-synthetic-private-file.env",
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 1);
  assert.doesNotMatch(result.stdout + result.stderr, /synthetic-private/);
});
