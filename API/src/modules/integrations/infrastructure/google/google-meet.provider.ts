import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";
import { DatabaseService } from "../../../../database/database.service";
import { MeetProvider, MeetSpace } from "../../domain/ports/meet-provider";

type StoredToken = {
  access_token_encrypted: string;
  refresh_token_encrypted: string | null;
  expires_at: Date;
};

@Injectable()
export class GoogleMeetProvider implements MeetProvider {
  private readonly clientId: string;
  private readonly clientSecret: string;
  private readonly redirectUri: string;
  private readonly encryptionKey: Buffer;
  private readonly enabled: boolean;
  private readonly timeoutMs: number;

  constructor(
    config: ConfigService,
    private readonly database: DatabaseService,
  ) {
    this.enabled = config.get<boolean>("telemedicine.enabled") ?? false;
    this.timeoutMs = config.get<number>("externalHttpTimeoutMs", 15000);
    this.clientId = config.get<string>("telemedicine.google.clientId") ?? "";
    this.clientSecret =
      config.get<string>("telemedicine.google.clientSecret") ?? "";
    this.redirectUri =
      config.get<string>("telemedicine.google.redirectUri") ?? "";
    this.encryptionKey = createHash("sha256")
      .update(
        config.get<string>("telemedicine.google.tokenEncryptionKey") ?? "",
      )
      .digest();
  }

  async createAuthorizationUrl(userId: string) {
    this.assertConfigured();
    const state = randomBytes(32).toString("base64url");
    const stateHash = createHash("sha256").update(state).digest("hex");
    await this.database.query(
      `INSERT INTO oauth_authorization_states(provider,state_hash,created_by_user_id,expires_at)
       VALUES('google_meet',$1,$2,now()+interval '10 minutes')`,
      [stateHash, userId],
    );
    const query = new URLSearchParams({
      client_id: this.clientId,
      redirect_uri: this.redirectUri,
      response_type: "code",
      access_type: "offline",
      prompt: "consent",
      scope: "https://www.googleapis.com/auth/meetings.space.created",
      state,
    });
    return `https://accounts.google.com/o/oauth2/v2/auth?${query.toString()}`;
  }

  async completeAuthorization(code: string, state: string) {
    this.assertConfigured();
    const stateHash = createHash("sha256").update(state).digest("hex");
    const consumed = await this.database.query(
      `UPDATE oauth_authorization_states SET used_at=now()
       WHERE provider='google_meet' AND state_hash=$1
         AND used_at IS NULL AND expires_at>now()
       RETURNING created_by_user_id`,
      [stateHash],
    );
    if (!consumed.rows[0]) {
      throw new BadRequestException("El estado OAuth es inválido o expiró.");
    }
    const response = await this.googleRequest(
      "https://oauth2.googleapis.com/token",
      {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          code,
          client_id: this.clientId,
          client_secret: this.clientSecret,
          redirect_uri: this.redirectUri,
          grant_type: "authorization_code",
        }),
        signal: AbortSignal.timeout(this.timeoutMs),
      },
    );
    const token = (await response.json()) as {
      access_token?: string;
      refresh_token?: string;
      expires_in?: number;
      error_description?: string;
    };
    if (!response.ok || !token.access_token) {
      throw new BadGatewayException(
        token.error_description ?? "Google no pudo completar la autorización.",
      );
    }
    await this.database.query(
      `INSERT INTO external_oauth_credentials
       (provider,access_token_encrypted,refresh_token_encrypted,expires_at,connected_by_user_id)
       VALUES('google_meet',$1,$2,now()+($3||' seconds')::interval,$4)
       ON CONFLICT(provider) DO UPDATE SET
         access_token_encrypted=EXCLUDED.access_token_encrypted,
         refresh_token_encrypted=COALESCE(EXCLUDED.refresh_token_encrypted,
           external_oauth_credentials.refresh_token_encrypted),
         expires_at=EXCLUDED.expires_at,
         connected_by_user_id=EXCLUDED.connected_by_user_id,
         updated_at=now()`,
      [
        this.encrypt(token.access_token),
        token.refresh_token ? this.encrypt(token.refresh_token) : null,
        token.expires_in ?? 3600,
        consumed.rows[0].created_by_user_id,
      ],
    );
    await this.database.transactionWithSettings(
      { "app.user_id": consumed.rows[0].created_by_user_id },
      async (client) => {
        await client.query(
          `INSERT INTO audit_events(actor_user_id,module,action,entity_type,new_values)
           VALUES($1,'integrations','google_meet_connected','external_integration',
             jsonb_build_object('provider','google_meet'))`,
          [consumed.rows[0].created_by_user_id],
        );
      },
    );
  }

  async status() {
    const result = await this.database.query<{
      expires_at: Date;
      connected_by_name: string | null;
    }>(
      `SELECT credential.expires_at,
        NULLIF(concat_ws(' ',person.first_name,person.last_name),'') AS connected_by_name
       FROM external_oauth_credentials credential
       LEFT JOIN persons person ON person.user_id=credential.connected_by_user_id
       WHERE credential.provider='google_meet' LIMIT 1`,
    );
    return {
      connected: Boolean(result.rows[0]),
      expiresAt: result.rows[0]?.expires_at ?? null,
      connectedByName: result.rows[0]?.connected_by_name ?? null,
      redirectUri: this.redirectUri,
    };
  }

  async disconnect() {
    await this.database.query(
      `DELETE FROM external_oauth_credentials WHERE provider='google_meet'`,
    );
  }

  async createSpace(): Promise<MeetSpace> {
    this.assertConfigured();
    const accessToken = await this.validAccessToken();
    const response = await this.googleRequest(
      "https://meet.googleapis.com/v2/spaces",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          config: { accessType: "OPEN", entryPointAccess: "ALL" },
        }),
        signal: AbortSignal.timeout(this.timeoutMs),
      },
    );
    const data = (await response.json()) as {
      name?: string;
      meetingUri?: string;
      meetingCode?: string;
      error?: { message?: string };
    };
    if (!response.ok || !data.name || !data.meetingUri) {
      throw new BadGatewayException(
        data.error?.message ?? "Google Meet no pudo crear la sala.",
      );
    }
    return {
      name: data.name,
      meetingUri: data.meetingUri,
      meetingCode: data.meetingCode,
    };
  }

  async endActiveConference(spaceName: string): Promise<void> {
    this.assertConfigured();
    if (!/^spaces\/[A-Za-z0-9_-]+$/.test(spaceName)) {
      throw new BadRequestException("Identificador de sala no válido.");
    }
    const accessToken = await this.validAccessToken();
    const response = await this.googleRequest(
      `https://meet.googleapis.com/v2/${spaceName}:endActiveConference`,
      {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}` },
        signal: AbortSignal.timeout(this.timeoutMs),
      },
    );
    if (!response.ok) {
      throw new BadGatewayException(
        "Google Meet no pudo finalizar la conferencia.",
      );
    }
  }

  async allowDirectJoin(spaceName: string): Promise<void> {
    this.assertConfigured();
    if (!/^spaces\/[A-Za-z0-9_-]+$/.test(spaceName)) {
      throw new BadRequestException("Identificador de sala no válido.");
    }
    const accessToken = await this.validAccessToken();
    const response = await this.googleRequest(
      `https://meet.googleapis.com/v2/${spaceName}?updateMask=config.accessType,config.entryPointAccess`,
      {
        method: "PATCH",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          config: { accessType: "OPEN", entryPointAccess: "ALL" },
        }),
        signal: AbortSignal.timeout(this.timeoutMs),
      },
    );
    if (!response.ok)
      throw new BadGatewayException(
        "Google Meet no pudo habilitar el ingreso directo a la sala.",
      );
  }

  private async validAccessToken() {
    const result = await this.database.query<StoredToken>(
      `SELECT access_token_encrypted,refresh_token_encrypted,expires_at
       FROM external_oauth_credentials WHERE provider='google_meet' LIMIT 1`,
    );
    const stored = result.rows[0];
    if (!stored) {
      throw new ServiceUnavailableException(
        "Google Meet todavía no fue autorizado por un administrador.",
      );
    }
    if (stored.expires_at.getTime() > Date.now() + 60_000) {
      return this.decrypt(stored.access_token_encrypted);
    }
    if (!stored.refresh_token_encrypted) {
      throw new ServiceUnavailableException(
        "Google Meet requiere una nueva autorización.",
      );
    }
    const response = await this.googleRequest(
      "https://oauth2.googleapis.com/token",
      {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: this.clientId,
          client_secret: this.clientSecret,
          refresh_token: this.decrypt(stored.refresh_token_encrypted),
          grant_type: "refresh_token",
        }),
        signal: AbortSignal.timeout(this.timeoutMs),
      },
    );
    const token = (await response.json()) as {
      access_token?: string;
      expires_in?: number;
      error_description?: string;
    };
    if (!response.ok || !token.access_token) {
      throw new BadGatewayException(
        token.error_description ??
          "No se pudo renovar el acceso a Google Meet.",
      );
    }
    await this.database.query(
      `UPDATE external_oauth_credentials
       SET access_token_encrypted=$1,
         expires_at=now()+($2||' seconds')::interval,updated_at=now()
       WHERE provider='google_meet'`,
      [this.encrypt(token.access_token), token.expires_in ?? 3600],
    );
    return token.access_token;
  }

  private assertConfigured() {
    if (
      !this.enabled ||
      !this.clientId ||
      !this.clientSecret ||
      !this.redirectUri
    ) {
      throw new ServiceUnavailableException("Google Meet no está configurado.");
    }
  }

  private async googleRequest(url: string, init: RequestInit) {
    try {
      return await fetch(url, init);
    } catch {
      throw new BadGatewayException(
        "Google no respondió dentro del tiempo esperado.",
      );
    }
  }

  private encrypt(value: string) {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.encryptionKey, iv);
    const encrypted = Buffer.concat([
      cipher.update(value, "utf8"),
      cipher.final(),
    ]);
    return [iv, cipher.getAuthTag(), encrypted]
      .map((part) => part.toString("base64url"))
      .join(".");
  }

  private decrypt(value: string) {
    const [iv, tag, encrypted] = value
      .split(".")
      .map((part) => Buffer.from(part, "base64url"));
    if (!iv || !tag || !encrypted) {
      throw new ServiceUnavailableException(
        "La credencial de Google está dañada.",
      );
    }
    const decipher = createDecipheriv("aes-256-gcm", this.encryptionKey, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]).toString("utf8");
  }
}
