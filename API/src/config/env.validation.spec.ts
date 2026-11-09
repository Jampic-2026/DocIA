import { validateEnv } from "./env.validation";

const productionEnv = {
  NODE_ENV: "production",
  DATABASE_URL: "postgresql://docia_app:secret@localhost:5432/docia",
  JWT_ACCESS_SECRET: "a".repeat(32),
  JWT_REFRESH_SECRET: "b".repeat(32),
  MFA_ENCRYPTION_KEY: "c".repeat(32),
  STORAGE_SIGNING_SECRET: "d".repeat(32),
  PUBLIC_API_URL: "https://api.example.com",
  CORS_ORIGINS: "https://app.example.com",
  STORAGE_PROVIDER: "local",
  STRIPE_ENABLED: "false",
  EMAIL_ENABLED: "false",
  AI_ENABLED: "false",
  MAPS_ENABLED: "false",
  TELEMEDICINE_ENABLED: "false",
};

describe("validateEnv", () => {
  it("retains an optional dedicated Firebase service account path", () => {
    const configured = validateEnv({
      ...productionEnv,
      FCM_SERVICE_ACCOUNT_PATH: "/var/www/docia/secrets/firebase-test.json",
    });
    expect(configured.FCM_SERVICE_ACCOUNT_PATH).toBe(
      "/var/www/docia/secrets/firebase-test.json",
    );
  });

  it("accepts public HTTPS production URLs", () => {
    expect(() => validateEnv(productionEnv)).not.toThrow();
  });

  it("rejects localhost as the public API URL in production", () => {
    expect(() =>
      validateEnv({
        ...productionEnv,
        PUBLIC_API_URL: "http://localhost:3000",
      }),
    ).toThrow(/PUBLIC_API_URL/);
  });

  it("requires an explicit production CORS allowlist", () => {
    expect(() => validateEnv({ ...productionEnv, CORS_ORIGINS: "" })).toThrow(
      /CORS_ORIGINS/,
    );
  });

  it("rejects Stripe test keys in production", () => {
    expect(() =>
      validateEnv({
        ...productionEnv,
        STRIPE_ENABLED: "true",
        STRIPE_SECRET_KEY: "sk_test_1234567890",
        STRIPE_WEBHOOK_SECRET: "whsec_1234567890",
        STRIPE_PAYMENT_RETURN_URL: "https://app.example.com/payments/return",
      }),
    ).toThrow(/clave live/);
  });

  it("derives production CORS and mail URLs from PUBLIC_WEB_URL", () => {
    const result = validateEnv({
      ...productionEnv,
      PUBLIC_WEB_URL: "https://next-app.duckdns.org",
      CORS_ORIGINS: "",
    });
    expect(result.CORS_ORIGINS).toBe("https://next-app.duckdns.org");
    expect(result.REGISTRATION_URL).toBe(
      "https://next-app.duckdns.org/#/register/complete",
    );
  });

  it("rejects wildcard and credential-bearing CORS origins", () => {
    for (const origin of [
      "*",
      "https://*.example.com",
      "https://app.example.com/path",
      "https://user:secret@app.example.com",
    ]) {
      expect(() =>
        validateEnv({ ...productionEnv, CORS_ORIGINS: origin }),
      ).toThrow(/CORS_ORIGINS/);
    }
  });

  it("rejects paths and credentials in production base URLs", () => {
    for (const value of [
      "https://api.example.com/path",
      "https://user:secret@api.example.com",
      "https://*.example.com",
    ]) {
      expect(() =>
        validateEnv({ ...productionEnv, PUBLIC_API_URL: value }),
      ).toThrow(/PUBLIC_API_URL/);
    }
  });
});
