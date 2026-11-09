import { ConfigModule, ConfigService } from "@nestjs/config";
import { Test, TestingModule } from "@nestjs/testing";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { configuration } from "./configuration";
import { validateEnv } from "./env.validation";

describe("isolated deployment environment", () => {
  it("loads public URLs, preserved private values and PM2 overrides into their actual consumers", async () => {
    const directory = mkdtempSync(join(tmpdir(), "docia-env-layering-"));
    const privateValues: Record<string, string> = {
      NODE_ENV: "development",
      PORT: "3000",
      HOST: "0.0.0.0",
      STORAGE_ROOT: "storage",
      STORAGE_PROVIDER: "local",
      DB_HOST: "127.0.0.1",
      DB_PORT: "5432",
      DB_NAME: "synthetic_db",
      DB_USER: "synthetic_runtime",
      DB_PASSWORD: "synthetic#:@% password",
      JWT_ACCESS_SECRET: "a".repeat(40),
      JWT_REFRESH_SECRET: "b".repeat(40),
      MFA_ENCRYPTION_KEY: "c".repeat(40),
      STORAGE_SIGNING_SECRET: "d".repeat(40),
      PRESCRIPTION_SIGNING_SECRET: "e".repeat(40),
      WEB_ROUTING_MODE: "hash",
      CORS_ORIGINS: "https://extra.example.invalid",
      FCM_ENABLED: "false",
      FCM_SERVICE_ACCOUNT_PATH: "/private/synthetic-firebase.json",
      AI_ENABLED: "false",
      EMAIL_ENABLED: "false",
      STRIPE_ENABLED: "false",
      MAPS_ENABLED: "false",
      TELEMEDICINE_ENABLED: "false",
      SMS_ENABLED: "false",
    };
    const publicValues = {
      PUBLIC_API_URL: "https://api.doc-ia.cloud",
      PUBLIC_WEB_URL: "https://app.doc-ia.cloud",
      API_PREFIX: "api/v1",
    };
    const pm2Values = {
      NODE_ENV: "production",
      HOST: "127.0.0.1",
      PORT: "3200",
      STORAGE_ROOT: "/var/www/docia/monorepo/deploy/shared/storage",
    };
    const keys = new Set([
      ...Object.keys(privateValues),
      ...Object.keys(publicValues),
      "DATABASE_URL",
      "PASSWORD_RESET_URL",
      "REGISTRATION_URL",
      "STRIPE_PAYMENT_RETURN_URL",
      "GOOGLE_OAUTH_REDIRECT_URI",
    ]);
    const previous = { ...process.env };
    let module: TestingModule | undefined;
    try {
      for (const key of keys) delete process.env[key];
      Object.assign(process.env, pm2Values);
      const privateFile = join(directory, "api.env");
      const publicFile = join(directory, "PUBLIC_CONFIG.env");
      writeFileSync(
        privateFile,
        Object.entries(privateValues)
          .map(([key, value]) => `${key}='${value}'`)
          .join("\n"),
      );
      writeFileSync(
        publicFile,
        Object.entries(publicValues)
          .map(([key, value]) => `${key}=${value}`)
          .join("\n"),
      );
      module = await Test.createTestingModule({
        imports: [
          ConfigModule.forRoot({
            envFilePath: [publicFile, privateFile],
            load: [configuration],
            validate: validateEnv,
          }),
        ],
      }).compile();
      const config = module.get(ConfigService);
      expect(config.get("PORT")).toBe(3200);
      expect(config.get("HOST")).toBe("127.0.0.1");
      expect(config.get("STORAGE_ROOT")).toBe(pm2Values.STORAGE_ROOT);
      expect(config.get("JWT_ACCESS_SECRET")).toBe(
        privateValues.JWT_ACCESS_SECRET,
      );
      expect(config.get("PRESCRIPTION_SIGNING_SECRET")).toBe(
        privateValues.PRESCRIPTION_SIGNING_SECRET,
      );
      expect(config.get("databaseUrl")).toContain(
        encodeURIComponent(privateValues.DB_PASSWORD),
      );
      expect(config.get("CORS_ORIGINS")).toBe(
        "https://app.doc-ia.cloud,https://extra.example.invalid",
      );
      expect(config.get("email.passwordResetUrl")).toBe(
        "https://app.doc-ia.cloud/#/password-reset",
      );
      expect(config.get("email.registrationUrl")).toBe(
        "https://app.doc-ia.cloud/#/register/complete",
      );
      expect(config.get("stripe.paymentReturnUrl")).toBe(
        "https://app.doc-ia.cloud/#/payments/return",
      );
      expect(config.get("telemedicine.google.redirectUri")).toBe(
        "https://api.doc-ia.cloud/api/v1/integrations/google/callback",
      );
      expect(config.get("fcm.serviceAccountPath")).toBe(
        privateValues.FCM_SERVICE_ACCOUNT_PATH,
      );
    } finally {
      await module?.close();
      for (const key of Object.keys(process.env))
        if (!(key in previous)) delete process.env[key];
      Object.assign(process.env, previous);
      rmSync(directory, { recursive: true, force: true });
    }
  });
});
