import { z } from "zod";
import { buildDatabaseUrl } from "./database-url";
import { resolvePublicUrls } from "./public-urls";

const rawEnvSchema = z
  .object({
    NODE_ENV: z
      .enum(["development", "test", "production"])
      .default("development"),
    PORT: z.coerce.number().int().positive().default(3000),
    HOST: z.string().default("0.0.0.0"),
    API_PREFIX: z
      .string()
      .regex(/^[a-zA-Z0-9_-]+(?:\/[a-zA-Z0-9_-]+)*$/)
      .default("api/v1"),
    PUBLIC_WEB_URL: z.string().url().optional(),
    WEB_ROUTING_MODE: z.enum(["hash", "path"]).default("path"),

    DATABASE_URL: z.string().url().optional(),
    DB_HOST: z.string().default("localhost"),
    DB_PORT: z.coerce.number().int().positive().default(5432),
    DB_NAME: z.string().min(1).default("jampic_local"),
    DB_USER: z.string().min(1).default("postgres"),
    DB_PASSWORD: z.string().default("postgres"),
    DB_SSL: z.enum(["disable", "prefer", "require"]).default("disable"),
    DB_APPLY_LOCAL_SEEDS: z.enum(["true", "false"]).default("false"),
    DB_ENFORCE_RLS_ROLE: z.enum(["true", "false"]).default("true"),

    JWT_ACCESS_SECRET: z.string().min(32),
    JWT_REFRESH_SECRET: z.string().min(32),
    JWT_ACCESS_EXPIRES_IN: z.string().default("15m"),
    JWT_REFRESH_EXPIRES_IN: z.string().default("7d"),
    MFA_ENCRYPTION_KEY: z.string().min(32).optional(),
    SMS_ENABLED: z.enum(["true", "false"]).default("false"),
    SMS_API_URL: z.string().url().optional(),
    SMS_API_TOKEN: z.string().min(8).optional(),
    SMS_SENDER: z.string().min(1).default("Doc IA"),
    FCM_ENABLED: z.enum(["true", "false"]).default("false"),
    FCM_PROJECT_ID: z.string().min(3).optional(),
    FCM_CLIENT_EMAIL: z.string().email().optional(),
    FCM_PRIVATE_KEY: z.string().min(20).optional(),
    FCM_SERVICE_ACCOUNT_PATH: z.string().min(1).optional(),
    CORS_ORIGINS: z.string().optional(),
    PRESCRIPTION_SIGNING_SECRET: z.string().min(32).optional(),
    STORAGE_PROVIDER: z.enum(["local", "gcs"]).default("local"),
    STORAGE_ROOT: z.string().min(1).default("storage"),
    GCS_BUCKET_NAME: z.string().min(3).optional(),
    GOOGLE_APPLICATION_CREDENTIALS: z.string().min(1).optional(),
    STORAGE_SIGNING_SECRET: z.string().min(32).optional(),
    STORAGE_SIGNED_URL_EXPIRES_SECONDS: z.coerce
      .number()
      .int()
      .min(60)
      .max(3600)
      .default(300),
    STORAGE_MAX_FILE_SIZE_MB: z.coerce
      .number()
      .int()
      .min(1)
      .max(50)
      .default(10),
    STORAGE_DAILY_UPLOAD_MB: z.coerce
      .number()
      .int()
      .min(10)
      .max(2000)
      .default(100),
    PUBLIC_API_URL: z.string().url().default("http://localhost:3000"),
    EXTERNAL_HTTP_TIMEOUT_MS: z.coerce
      .number()
      .int()
      .min(1000)
      .max(60000)
      .default(15000),

    STRIPE_ENABLED: z.enum(["true", "false"]).default("false"),
    STRIPE_SECRET_KEY: z.string().startsWith("sk_").optional(),
    STRIPE_WEBHOOK_SECRET: z.string().startsWith("whsec_").optional(),
    STRIPE_PAYMENT_RETURN_URL: z
      .string()
      .url()
      .default("http://localhost:5173/payments/return"),

    EMAIL_ENABLED: z.enum(["true", "false"]).default("false"),
    EMAIL_PROVIDER: z.enum(["resend"]).default("resend"),
    RESEND_API_KEY: z.string().startsWith("re_").optional(),
    EMAIL_FROM: z.string().min(3).optional(),
    PASSWORD_RESET_URL: z
      .string()
      .url()
      .default("http://localhost:5173/password-reset"),
    REGISTRATION_URL: z
      .string()
      .url()
      .default("http://localhost:5173/register/complete"),

    AI_ENABLED: z.enum(["true", "false"]).default("false"),
    AI_PROVIDER: z.enum(["openai"]).default("openai"),
    OPENAI_API_KEY: z.string().min(20).optional(),
    OPENAI_MODEL: z.string().min(1).optional(),
    OPENAI_PROJECT_ID: z.string().min(1).optional(),
    OPENAI_ORGANIZATION_ID: z.string().min(1).optional(),

    MAPS_ENABLED: z.enum(["true", "false"]).default("false"),
    MAPS_PROVIDER: z.enum(["google"]).default("google"),
    GOOGLE_MAPS_SERVER_API_KEY: z.string().min(20).optional(),

    TELEMEDICINE_ENABLED: z.enum(["true", "false"]).default("false"),
    TELEMEDICINE_PROVIDER: z.enum(["google_meet"]).default("google_meet"),
    GOOGLE_OAUTH_CLIENT_ID: z.string().min(10).optional(),
    GOOGLE_OAUTH_CLIENT_SECRET: z.string().min(10).optional(),
    GOOGLE_OAUTH_REDIRECT_URI: z.string().url().optional(),
    GOOGLE_OAUTH_TOKEN_ENCRYPTION_KEY: z.string().min(32).optional(),
  })
  .superRefine((env, context) => {
    const isLocalUrl = (value: string) => {
      try {
        const url = new URL(value);
        return (
          url.protocol !== "https:" ||
          ["localhost", "127.0.0.1", "::1", "[::1]"].includes(url.hostname)
        );
      } catch {
        return true;
      }
    };
    if (env.NODE_ENV === "production") {
      if (!env.CORS_ORIGINS?.trim()) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["CORS_ORIGINS"],
          message: "CORS_ORIGINS es obligatoria en producción.",
        });
      }
      const productionUrls: Array<[string, string | undefined, boolean]> = [
        ["PUBLIC_API_URL", env.PUBLIC_API_URL, true],
        ["PUBLIC_WEB_URL", env.PUBLIC_WEB_URL, true],
        [
          "STRIPE_PAYMENT_RETURN_URL",
          env.STRIPE_PAYMENT_RETURN_URL,
          env.STRIPE_ENABLED === "true",
        ],
        [
          "PASSWORD_RESET_URL",
          env.PASSWORD_RESET_URL,
          env.EMAIL_ENABLED === "true",
        ],
        [
          "REGISTRATION_URL",
          env.REGISTRATION_URL,
          env.EMAIL_ENABLED === "true",
        ],
        [
          "GOOGLE_OAUTH_REDIRECT_URI",
          env.GOOGLE_OAUTH_REDIRECT_URI,
          Boolean(env.GOOGLE_OAUTH_REDIRECT_URI),
        ],
      ];
      for (const [key, value, required] of productionUrls) {
        if (required && value && isLocalUrl(value)) {
          context.addIssue({
            code: z.ZodIssueCode.custom,
            path: [key],
            message: `${key} debe usar HTTPS público y no puede apuntar a localhost en producción.`,
          });
        }
        if (value && ["PUBLIC_API_URL", "PUBLIC_WEB_URL"].includes(key)) {
          let valid = false;
          try {
            const url = new URL(value);
            valid = url.origin === value && !url.hostname.includes("*");
          } catch {
            /* The schema reports malformed URLs without echoing values. */
          }
          if (!valid) {
            context.addIssue({
              code: z.ZodIssueCode.custom,
              path: [key],
              message: `${key} debe ser un origen exacto, sin rutas, comodines ni credenciales.`,
            });
          }
        }
      }
      for (const origin of env.CORS_ORIGINS?.split(",").filter(Boolean) ?? []) {
        let valid = false;
        try {
          const url = new URL(origin);
          valid =
            !isLocalUrl(origin) &&
            url.origin === origin &&
            !url.hostname.includes("*") &&
            !url.username &&
            !url.password;
        } catch {
          /* Invalid origins must fail without echoing their contents. */
        }
        if (!valid)
          context.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["CORS_ORIGINS"],
            message:
              "CORS_ORIGINS debe contener orígenes HTTPS exactos, sin rutas ni credenciales.",
          });
      }
    }
    if (env.NODE_ENV === "production" && !env.STORAGE_SIGNING_SECRET)
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["STORAGE_SIGNING_SECRET"],
        message: "STORAGE_SIGNING_SECRET es obligatoria en producción.",
      });
    if (env.STORAGE_PROVIDER === "gcs" && !env.GCS_BUCKET_NAME) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["GCS_BUCKET_NAME"],
        message: "GCS_BUCKET_NAME es obligatoria cuando STORAGE_PROVIDER=gcs.",
      });
    }
    if (
      env.NODE_ENV === "production" &&
      env.STORAGE_PROVIDER === "gcs" &&
      !env.GOOGLE_APPLICATION_CREDENTIALS
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["GOOGLE_APPLICATION_CREDENTIALS"],
        message:
          "GOOGLE_APPLICATION_CREDENTIALS es obligatoria en producción con STORAGE_PROVIDER=gcs cuando la API corre en VPS.",
      });
    }
    if (env.NODE_ENV === "production" && !env.MFA_ENCRYPTION_KEY)
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["MFA_ENCRYPTION_KEY"],
        message: "MFA_ENCRYPTION_KEY es obligatoria en producción.",
      });
    if (
      env.SMS_ENABLED === "true" &&
      (!env.SMS_API_URL || !env.SMS_API_TOKEN)
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["SMS_API_URL"],
        message:
          "SMS_API_URL y SMS_API_TOKEN son obligatorios cuando SMS_ENABLED=true.",
      });
    }
    if (env.FCM_ENABLED === "true") {
      if (!env.FCM_PROJECT_ID) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["FCM_PROJECT_ID"],
          message: "FCM_PROJECT_ID es obligatoria cuando FCM_ENABLED=true.",
        });
      }
      if (
        (env.FCM_CLIENT_EMAIL && !env.FCM_PRIVATE_KEY) ||
        (!env.FCM_CLIENT_EMAIL && env.FCM_PRIVATE_KEY)
      ) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["FCM_CLIENT_EMAIL"],
          message:
            "FCM_CLIENT_EMAIL y FCM_PRIVATE_KEY deben configurarse juntas.",
        });
      }
    }
    if (env.EMAIL_ENABLED === "true") {
      if (!env.RESEND_API_KEY) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["RESEND_API_KEY"],
          message: "RESEND_API_KEY es obligatoria cuando EMAIL_ENABLED=true.",
        });
      }
      if (!env.EMAIL_FROM) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["EMAIL_FROM"],
          message: "EMAIL_FROM es obligatorio cuando EMAIL_ENABLED=true.",
        });
      }
    }
    if (env.AI_ENABLED === "true") {
      if (!env.OPENAI_API_KEY) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["OPENAI_API_KEY"],
          message: "OPENAI_API_KEY es obligatoria cuando AI_ENABLED=true.",
        });
      }
      if (!env.OPENAI_MODEL) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["OPENAI_MODEL"],
          message: "OPENAI_MODEL es obligatorio cuando AI_ENABLED=true.",
        });
      }
    }
    if (env.MAPS_ENABLED === "true" && !env.GOOGLE_MAPS_SERVER_API_KEY) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["GOOGLE_MAPS_SERVER_API_KEY"],
        message:
          "GOOGLE_MAPS_SERVER_API_KEY es obligatoria cuando MAPS_ENABLED=true.",
      });
    }
    if (env.STRIPE_ENABLED === "true" && !env.STRIPE_SECRET_KEY) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["STRIPE_SECRET_KEY"],
        message: "STRIPE_SECRET_KEY es obligatoria cuando STRIPE_ENABLED=true.",
      });
    }
    if (env.NODE_ENV === "production" && env.STRIPE_ENABLED === "true") {
      if (!env.STRIPE_SECRET_KEY?.startsWith("sk_live_")) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["STRIPE_SECRET_KEY"],
          message:
            "STRIPE_SECRET_KEY debe ser una clave live en producción cuando STRIPE_ENABLED=true.",
        });
      }
      if (!env.STRIPE_WEBHOOK_SECRET) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["STRIPE_WEBHOOK_SECRET"],
          message:
            "STRIPE_WEBHOOK_SECRET es obligatoria en producción cuando STRIPE_ENABLED=true.",
        });
      }
    }
    if (env.TELEMEDICINE_ENABLED === "true") {
      const required = [
        "GOOGLE_OAUTH_CLIENT_ID",
        "GOOGLE_OAUTH_CLIENT_SECRET",
        "GOOGLE_OAUTH_TOKEN_ENCRYPTION_KEY",
      ] as const;
      for (const key of required) {
        if (!env[key]) {
          context.addIssue({
            code: z.ZodIssueCode.custom,
            path: [key],
            message: `${key} es obligatoria cuando TELEMEDICINE_ENABLED=true.`,
          });
        }
      }
    }
  });

export function validateEnv(config: Record<string, unknown>) {
  const resolved = resolvePublicUrls(config);
  const parsed = rawEnvSchema.safeParse({ ...config, ...resolved });

  if (!parsed.success) {
    throw new Error(parsed.error.message);
  }

  return {
    ...parsed.data,
    DATABASE_URL: buildDatabaseUrl(parsed.data),
  };
}
