import { buildDatabaseUrl } from "./database-url";
import { resolvePublicUrls } from "./public-urls";

export const configuration = () => {
  const urls = resolvePublicUrls(process.env);
  return {
    nodeEnv: process.env.NODE_ENV ?? "development",
    port: Number(process.env.PORT ?? 3000),
    externalHttpTimeoutMs: Number(
      process.env.EXTERNAL_HTTP_TIMEOUT_MS ?? 15000,
    ),
    publicApiUrl: urls.PUBLIC_API_URL,
    publicWebUrl: urls.PUBLIC_WEB_URL,
    apiPrefix: urls.API_PREFIX,
    databaseUrl: buildDatabaseUrl(process.env),
    database: {
      url: buildDatabaseUrl(process.env),
      host: process.env.DB_HOST ?? "localhost",
      port: Number(process.env.DB_PORT ?? 5432),
      name: process.env.DB_NAME ?? "jampic_local",
      user: process.env.DB_USER ?? "postgres",
      ssl: process.env.DB_SSL ?? "disable",
      applyLocalSeeds: process.env.DB_APPLY_LOCAL_SEEDS === "true",
      enforceRlsRole: process.env.DB_ENFORCE_RLS_ROLE !== "false",
    },
    jwt: {
      accessSecret: process.env.JWT_ACCESS_SECRET,
      refreshSecret: process.env.JWT_REFRESH_SECRET,
      accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? "15m",
      refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? "7d",
    },
    security: { mfaEncryptionKey: process.env.MFA_ENCRYPTION_KEY },
    storage: {
      provider: process.env.STORAGE_PROVIDER ?? "local",
      gcsBucketName: process.env.GCS_BUCKET_NAME,
      signingSecret:
        process.env.STORAGE_SIGNING_SECRET ?? process.env.JWT_ACCESS_SECRET,
      signedUrlExpiresSeconds: Number(
        process.env.STORAGE_SIGNED_URL_EXPIRES_SECONDS ?? 300,
      ),
    },
    sms: {
      enabled: process.env.SMS_ENABLED === "true",
      apiUrl: process.env.SMS_API_URL,
      apiToken: process.env.SMS_API_TOKEN,
      sender: process.env.SMS_SENDER ?? "Doc IA",
    },
    fcm: {
      enabled: process.env.FCM_ENABLED === "true",
      projectId: process.env.FCM_PROJECT_ID ?? "cedar-router-479423-p5",
      clientEmail: process.env.FCM_CLIENT_EMAIL,
      privateKey: process.env.FCM_PRIVATE_KEY?.replace(/\\n/g, "\n"),
      serviceAccountPath: process.env.FCM_SERVICE_ACCOUNT_PATH,
    },
    email: {
      enabled: process.env.EMAIL_ENABLED === "true",
      provider: process.env.EMAIL_PROVIDER ?? "resend",
      resendApiKey: process.env.RESEND_API_KEY,
      from: process.env.EMAIL_FROM,
      passwordResetUrl: urls.PASSWORD_RESET_URL,
      registrationUrl: urls.REGISTRATION_URL,
    },
    ai: {
      enabled: process.env.AI_ENABLED === "true",
      provider: process.env.AI_PROVIDER ?? "openai",
      openAi: {
        apiKey: process.env.OPENAI_API_KEY,
        model: process.env.OPENAI_MODEL,
        projectId: process.env.OPENAI_PROJECT_ID,
        organizationId: process.env.OPENAI_ORGANIZATION_ID,
      },
    },
    maps: {
      enabled: process.env.MAPS_ENABLED === "true",
      provider: process.env.MAPS_PROVIDER ?? "google",
      google: {
        serverApiKey: process.env.GOOGLE_MAPS_SERVER_API_KEY,
      },
    },
    stripe: {
      enabled: process.env.STRIPE_ENABLED === "true",
      secretKey: process.env.STRIPE_SECRET_KEY,
      webhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
      paymentReturnUrl: urls.STRIPE_PAYMENT_RETURN_URL,
    },
    telemedicine: {
      enabled: process.env.TELEMEDICINE_ENABLED === "true",
      provider: process.env.TELEMEDICINE_PROVIDER ?? "google_meet",
      google: {
        clientId: process.env.GOOGLE_OAUTH_CLIENT_ID,
        clientSecret: process.env.GOOGLE_OAUTH_CLIENT_SECRET,
        redirectUri: urls.GOOGLE_OAUTH_REDIRECT_URI,
        tokenEncryptionKey: process.env.GOOGLE_OAUTH_TOKEN_ENCRYPTION_KEY,
      },
    },
  };
};
