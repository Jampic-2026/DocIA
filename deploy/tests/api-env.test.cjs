const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { createRequire } = require("node:module");
const path = require("node:path");
const { parse } = createRequire(
  path.resolve(__dirname, "../../API/package.json"),
)("dotenv");
const {
  normalizePrivateEnvironment,
  managedKeys,
} = require("../prepare-api-env.cjs");
const sites = {
  PUBLIC_API_URL: "https://api.doc-ia.cloud",
  PUBLIC_WEB_URL: "https://app.doc-ia.cloud",
  PUBLIC_LANDING_URL: "https://doc-ia.cloud",
  API_PREFIX: "api/v1",
};
test("preserves every private/admin/example variable, including optional and unknown keys", () => {
  const example = fs.readFileSync(
    path.resolve(__dirname, "../../API/.env.example"),
    "utf8",
  );
  const keys = [
    ...example.matchAll(/^\s*(?:#\s*)?(?:export\s+)?([A-Z][A-Z0-9_]*)\s*=/gm),
  ].map((m) => m[1]);
  const values = Object.fromEntries(
    keys.map((key) => [key, `synthetic-${key}`]),
  );
  Object.assign(values, sites, {
    WEB_ROUTING_MODE: "hash",
    PASSWORD_RESET_URL: `${sites.PUBLIC_WEB_URL}/#/password-reset`,
    REGISTRATION_URL: `${sites.PUBLIC_WEB_URL}/#/register/complete`,
    STRIPE_PAYMENT_RETURN_URL: `${sites.PUBLIC_WEB_URL}/#/payments/return`,
    GOOGLE_OAUTH_REDIRECT_URI: `${sites.PUBLIC_API_URL}/api/v1/integrations/google/callback`,
    FUTURE_PROVIDER_TOKEN: "synthetic-unknown",
  });
  const source = Object.entries(values)
    .map(([k, v]) => `${k}='${v}'\r\n`)
    .join("");
  const result = parse(normalizePrivateEnvironment(source, sites, parse));
  for (const [key, value] of Object.entries(values))
    if (!managedKeys.has(key)) assert.equal(result[key], value, key);
  for (const key of managedKeys) assert.equal(result[key], undefined, key);
});
test("preserves hash signs, passwords, multiline keys, CRLF and comments verbatim", () => {
  const privatePart =
    "# private comment\r\nDB_PASSWORD='p#@%: with spaces'\r\nFCM_PRIVATE_KEY=\"first line\r\nsecond line\r\n\"\r\nJWT_ACCESS_SECRET='synthetic-token'\r\n";
  const source = `PUBLIC_API_URL=${sites.PUBLIC_API_URL}\r\nexport API_PREFIX=api/v1\r\n${privatePart}`;
  assert.equal(normalizePrivateEnvironment(source, sites, parse), privatePart);
});
test("stops if removing a public-looking line would modify a multiline private value", () =>
  assert.throws(
    () =>
      normalizePrivateEnvironment(
        `FCM_PRIVATE_KEY=\"first\nPUBLIC_API_URL=${sites.PUBLIC_API_URL}\nlast\"\n`,
        sites,
        parse,
      ),
    /FCM_PRIVATE_KEY/,
  ));
test("custom return routes are not silently replaced", () =>
  assert.throws(
    () =>
      normalizePrivateEnvironment(
        "PASSWORD_RESET_URL=https://custom.invalid/private-value\n",
        sites,
        parse,
      ),
    (error) =>
      error.message.includes("PASSWORD_RESET_URL") &&
      !error.message.includes("private-value"),
  ));
