import * as fs from "node:fs";
import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { PushProvider, PushNotification } from "../../domain/ports/push";
@Injectable()
export class FirebasePushProvider implements PushProvider {
  private readonly logger = new Logger(FirebasePushProvider.name);
  readonly enabled: boolean;
  private readonly appName = "docia-push";
  constructor(private readonly config: ConfigService) {
    this.enabled = this.config.get<boolean>("fcm.enabled") ?? false;

    if (!this.enabled) return;

    const projectId = this.config.get<string>("fcm.projectId") ?? undefined;
    const clientEmail = this.config.get<string>("fcm.clientEmail");
    const privateKey = this.config.get<string>("fcm.privateKey");
    const serviceAccountPath =
      this.config.get<string>("fcm.serviceAccountPath") ??
      process.env.GOOGLE_APPLICATION_CREDENTIALS;

    try {
      let credential;
      if (clientEmail && privateKey) {
        credential = cert({ projectId, clientEmail, privateKey });
      } else if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
        const keyObj = JSON.parse(fs.readFileSync(serviceAccountPath, "utf-8"));
        credential = cert(keyObj);
      } else {
        credential = applicationDefault();
      }

      const existing = getApps().find((app) => app.name === this.appName);
      if (!existing) {
        initializeApp({ credential, projectId }, this.appName);
      }
      this.logger.log(
        `Firebase Cloud Messaging inicializado para el proyecto: ${projectId}`,
      );
    } catch {
      this.logger.error("No se pudo inicializar Firebase Admin.");
    }
  }
  async send(tokens: string[], notification: PushNotification) {
    const app = getApps().find((candidate) => candidate.name === this.appName);
    if (!app) throw new Error("FCM is enabled but unavailable");

    const response = await getMessaging(app).sendEachForMulticast({
      tokens,
      notification: {
        // Evita exponer información clínica en una pantalla bloqueada.
        title: "Doc IA",
        body: "Tienes una nueva actualización. Abre la app para verla.",
      },
      data: {
        eventCode: notification.eventCode,
        relatedEntityType: notification.relatedEntityType ?? "",
        relatedEntityId: notification.relatedEntityId ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "docia_notifications",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((result, index) => ({ result, token: tokens[index] }))
      .filter(({ result }) => {
        const code = result.error?.code;
        return (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        );
      })
      .map(({ token }) => token);
    return {
      invalidTokens,
      transientFailures: response.failureCount - invalidTokens.length,
    };
  }
}
