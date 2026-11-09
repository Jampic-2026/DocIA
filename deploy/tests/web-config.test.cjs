const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const script = path.resolve(__dirname, "../write-web-config.cjs");

function validate(config, extraEnv = {}) {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "docia-config-"));
  try {
    fs.mkdirSync(path.join(cwd, "config"), { recursive: true });
    const result = spawnSync(process.execPath, [script], {
      cwd,
      encoding: "utf8",
      env: {
        ...process.env,
        DOCIA_PUBLIC_CONFIG_JSON: "",
        DOCIA_PUBLIC_CONFIG_FILE: "",
        DOCIA_WEB_CONFIG_JSON: JSON.stringify(config),
        ...extraEnv,
      },
    });
    const output = path.join(cwd, "config/ci-production.json");
    return {
      ...result,
      config: fs.existsSync(output)
        ? JSON.parse(fs.readFileSync(output, "utf8"))
        : null,
    };
  } finally {
    fs.rmSync(cwd, { recursive: true, force: true });
  }
}
const valid = {
  APP_ENV: "production",
  API_BASE_URL: "https://api.example.com/api/v1/",
};
test("accepts public HTTPS configuration without requiring Stripe", () => {
  const result = validate(valid);
  assert.equal(result.status, 0);
  assert.deepEqual(result.config, valid);
});

test("derives API_BASE_URL from the common public config and retains only the Stripe public key", () => {
  const result = validate(
    { STRIPE_PUBLISHABLE_KEY: "pk_live_syntheticpublic" },
    {
      DOCIA_PUBLIC_CONFIG_JSON: JSON.stringify({
        PUBLIC_API_URL: "https://next-api.duckdns.org",
        PUBLIC_WEB_URL: "https://next-app.duckdns.org",
        PUBLIC_LANDING_URL: "https://next.duckdns.org",
        API_PREFIX: "api/v2",
      }),
    },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.config, {
    APP_ENV: "production",
    API_BASE_URL: "https://next-api.duckdns.org/api/v2/",
    STRIPE_PUBLISHABLE_KEY: "pk_live_syntheticpublic",
  });
});

test("rejects secrets in the common public variable without leaking them", () => {
  const result = validate(valid, {
    DOCIA_PUBLIC_CONFIG_JSON: '{"PASSWORD":"synthetic-private-value"}',
  });
  assert.equal(result.status, 1);
  assert.doesNotMatch(result.stdout + result.stderr, /synthetic-private-value/);
});
test("rejects backend secrets without printing them", () => {
  const result = validate({
    ...valid,
    JWT_ACCESS_SECRET: "synthetic-private-value",
  });
  assert.equal(result.status, 1);
  assert.equal(result.config, null);
  assert.doesNotMatch(result.stdout + result.stderr, /synthetic-private-value/);
});
for (const [name, config] of Object.entries({
  HTTP: { ...valid, API_BASE_URL: "http://api.example.com/api/v1/" },
  "URL credentials": {
    ...valid,
    API_BASE_URL:
      "https://user:synthetic-private-value@api.example.com/api/v1/",
  },
  "missing trailing slash": {
    ...valid,
    API_BASE_URL: "https://api.example.com/api/v1",
  },
  development: { ...valid, APP_ENV: "development" },
  "Stripe private key": {
    ...valid,
    STRIPE_PUBLISHABLE_KEY: "sk_live_syntheticprivatevalue",
  },
  "Stripe test key": {
    ...valid,
    STRIPE_PUBLISHABLE_KEY: "pk_test_syntheticvalue",
  },
})) {
  test(`rejects ${name}`, () => {
    const result = validate(config);
    assert.equal(result.status, 1);
    assert.equal(result.config, null);
    assert.doesNotMatch(
      result.stdout + result.stderr,
      /synthetic-private-value|sk_live_/,
    );
  });
}
