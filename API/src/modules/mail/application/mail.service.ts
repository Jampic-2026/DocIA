import { Inject, Injectable } from "@nestjs/common";
import { MAIL_PROVIDER, MailProvider } from "../domain/ports/mail-provider";

@Injectable()
export class MailService {
  constructor(
    @Inject(MAIL_PROVIDER)
    private readonly provider: MailProvider,
  ) {}

  sendNotification(input: {
    to: string;
    subject: string;
    body: string;
    idempotencyKey: string;
  }) {
    return this.provider.sendNotification(input);
  }

  sendPasswordReset(input: {
    to: string;
    resetUrl: string;
    expiresInMinutes: number;
    idempotencyKey: string;
  }) {
    return this.provider.sendPasswordReset(input);
  }
  sendRegistrationVerification(input: {
    to: string;
    verificationUrl: string;
    expiresInMinutes: number;
    idempotencyKey: string;
  }) {
    return this.provider.sendRegistrationVerification(input);
  }
}
