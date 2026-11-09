import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import multipart from "@fastify/multipart";
import rawBody from "fastify-raw-body";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    // Solo acepta X-Forwarded-* del proxy local (por ejemplo Nginx en el VPS).
    new FastifyAdapter({ logger: true, trustProxy: "loopback" }),
  );
  const config = app.get(ConfigService);
  const apiPrefix = config.getOrThrow<string>("API_PREFIX");
  const corsOrigins = config
    .get<string>("CORS_ORIGINS", "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (process.env.NODE_ENV === "production" && corsOrigins.length === 0) {
    throw new Error(
      "CORS_ORIGINS debe contener al menos un origen en producción.",
    );
  }

  await app.register(helmet, {
    crossOriginResourcePolicy: { policy: "cross-origin" },
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: false,
  });
  await app.register(cors, {
    origin: (origin, cb) => {
      if (
        !origin ||
        (corsOrigins.length === 0 && process.env.NODE_ENV !== "production") ||
        corsOrigins.includes(origin) ||
        process.env.NODE_ENV !== "production"
      ) {
        cb(null, true);
        return;
      }
      cb(new Error("No permitido por CORS"), false);
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Authorization", "Content-Type", "Accept", "Range"],
    exposedHeaders: ["Content-Length", "Content-Disposition"],
  });
  await app.register(multipart, {
    limits: {
      files: 1,
      fileSize:
        config.get<number>("STORAGE_MAX_FILE_SIZE_MB", 10) * 1024 * 1024,
    },
  });
  await app.register(rawBody, {
    field: "rawBody",
    global: false,
    encoding: "utf8",
    runFirst: true,
    routes: [`/${apiPrefix}/payments/stripe/webhook`],
  });

  app.setGlobalPrefix(apiPrefix);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = config.get<number>("PORT", 3000);
  await app.listen({ port, host: config.get<string>("HOST", "0.0.0.0") });
}

void bootstrap();
