import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Resend } from "resend";
import { MailProvider } from "../../domain/ports/mail-provider";

@Injectable()
export class ResendMailProvider implements MailProvider {
  private readonly resend: Resend;
  private readonly from: string;

  constructor(config: ConfigService) {
    this.resend = new Resend(config.getOrThrow<string>("email.resendApiKey"));
    this.from = config.getOrThrow<string>("email.from");
  }

  async sendNotification(input: {
    to: string;
    subject: string;
    body: string;
    idempotencyKey: string;
  }) {
    const { error } = await this.resend.emails.send(
      {
        from: this.from,
        to: [input.to],
        subject: input.subject,
        text: input.body,
        html: `<!doctype html><html lang="es"><body style="font-family:Arial,sans-serif;background:#f6f8fb;padding:32px"><div style="max-width:560px;margin:auto;background:#fff;padding:32px;border-radius:16px"><h1 style="color:#13294b">Doc IA</h1><h2>${this.escapeHtml(input.subject)}</h2><p>${this.escapeHtml(input.body)}</p></div></body></html>`,
      },
      { idempotencyKey: input.idempotencyKey },
    );
    if (error) throw new Error(`Resend rechazó el correo: ${error.message}`);
  }

  async sendPasswordReset(input: {
    to: string;
    resetUrl: string;
    expiresInMinutes: number;
    idempotencyKey: string;
  }): Promise<void> {
    const { error } = await this.resend.emails.send(
      {
        from: this.from,
        to: [input.to],
        subject: "Recupera tu contraseña de Doc IA",
        text:
          `Recibimos una solicitud para cambiar tu contraseña de Doc IA.\n\n` +
          `Abre este enlace: ${input.resetUrl}\n\n` +
          `El enlace vence en ${input.expiresInMinutes} minutos. ` +
          "Si no realizaste esta solicitud, ignora este mensaje.",
        html: this.passwordResetHtml(input),
      },
      { idempotencyKey: input.idempotencyKey },
    );
    if (error) {
      throw new Error(`Resend rechazó el correo: ${error.message}`);
    }
  }
  async sendRegistrationVerification(input: {
    to: string;
    verificationUrl: string;
    expiresInMinutes: number;
    idempotencyKey: string;
  }): Promise<void> {
    const { error } = await this.resend.emails.send(
      {
        from: this.from,
        to: [input.to],
        subject: "Verifica tu correo de Doc IA",
        text: `Verifica tu correo abriendo este enlace: ${input.verificationUrl}\n\nEl enlace vence en ${input.expiresInMinutes} minutos.`,
        html: `<!doctype html><html lang="es"><body style="font-family:Arial,sans-serif;background:#f6f8fb;padding:32px"><div style="max-width:560px;margin:auto;background:#fff;padding:32px;border-radius:16px"><h1 style="color:#13294b">Doc IA</h1><h2>Verifica tu correo</h2><p>Confirma tu dirección para completar el registro.</p><p><a href="${input.verificationUrl}" style="display:inline-block;background:#14b8a6;color:#fff;text-decoration:none;padding:14px 22px;border-radius:10px;font-weight:bold">Verificar mi correo</a></p><p>Este enlace vence en ${input.expiresInMinutes} minutos.</p></div></body></html>`,
      },
      { idempotencyKey: input.idempotencyKey },
    );
    if (error) throw new Error(`Resend rechazó el correo: ${error.message}`);
  }

  private passwordResetHtml(input: {
    resetUrl: string;
    expiresInMinutes: number;
  }) {
    return `<!doctype html>
<html lang="es">
  <body style="margin:0;background:#f6f8fb;font-family:Arial,sans-serif;color:#0f1b2d">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
      <tr><td align="center" style="padding:32px 16px">
        <table role="presentation" width="100%" style="max-width:560px;background:#fff;border-radius:16px">
          <tr><td style="padding:32px">
            <h1 style="margin:0 0 16px;color:#13294b">Doc IA</h1>
            <h2 style="margin:0 0 16px">Recupera tu contraseña</h2>
            <p>Recibimos una solicitud para cambiar la contraseña de tu cuenta.</p>
            <p style="margin:24px 0">
              <a href="${input.resetUrl}" style="display:inline-block;background:#14b8a6;color:#fff;text-decoration:none;padding:14px 22px;border-radius:10px;font-weight:bold">
                Cambiar mi contraseña
              </a>
            </p>
            <p>Este enlace vence en ${input.expiresInMinutes} minutos.</p>
            <p style="color:#5b6b82;font-size:13px">Si no realizaste esta solicitud, puedes ignorar este correo.</p>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
  }

  private escapeHtml(value: string) {
    return value
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }
}
