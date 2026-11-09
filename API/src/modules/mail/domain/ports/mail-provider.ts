export const MAIL_PROVIDER = Symbol("MAIL_PROVIDER");

export interface MailProvider {
  sendNotification(input: {
    to: string;
    subject: string;
    body: string;
    idempotencyKey: string;
  }): Promise<void>;
  sendRegistrationVerification(input: {
    to: string;
    verificationUrl: string;
    expiresInMinutes: number;
    idempotencyKey: string;
  }): Promise<void>;
  sendPasswordReset(input: {
    to: string;
    resetUrl: string;
    expiresInMinutes: number;
    idempotencyKey: string;
  }): Promise<void>;
}
