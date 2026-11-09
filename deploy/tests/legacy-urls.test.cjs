const { test } = require("node:test");
const assert = require("node:assert/strict");
const { validateOverrides } = require("../check-legacy-urls.cjs");
const sites = {
  PUBLIC_API_URL: "https://api.doc-ia.cloud",
  PUBLIC_WEB_URL: "https://app.doc-ia.cloud",
  PUBLIC_LANDING_URL: "https://doc-ia.cloud",
  API_PREFIX: "api/v1",
};
test("accepts current origins and equivalent hash routes", () =>
  assert.doesNotThrow(() =>
    validateOverrides(
      {
        ...sites,
        PASSWORD_RESET_URL: "https://app.doc-ia.cloud/#/password-reset",
        REGISTRATION_URL: "https://app.doc-ia.cloud/#/register/complete",
        GOOGLE_OAUTH_REDIRECT_URI:
          "https://api.doc-ia.cloud/api/v1/integrations/google/callback",
      },
      sites,
    ),
  ));
test("retains explicitly configured path routing", () =>
  assert.doesNotThrow(() =>
    validateOverrides(
      {
        WEB_ROUTING_MODE: "path",
        PASSWORD_RESET_URL: "https://app.doc-ia.cloud/password-reset",
        STRIPE_PAYMENT_RETURN_URL: "https://app.doc-ia.cloud/payments/return",
      },
      sites,
    ),
  ));
for (const key of [
  "PUBLIC_API_URL",
  "PASSWORD_RESET_URL",
  "REGISTRATION_URL",
  "STRIPE_PAYMENT_RETURN_URL",
  "GOOGLE_OAUTH_REDIRECT_URI",
])
  test(`stops on custom ${key} without exposing its value`, () =>
    assert.throws(
      () =>
        validateOverrides(
          { [key]: "https://custom.invalid/private-token" },
          sites,
        ),
      (error) =>
        error.message.includes(key) &&
        !error.message.includes("private-token") &&
        !error.message.includes("custom.invalid"),
    ));
test("does not silently change the API prefix", () =>
  assert.throws(
    () => validateOverrides({ API_PREFIX: "api/v2" }, sites),
    /API_PREFIX/,
  ));
