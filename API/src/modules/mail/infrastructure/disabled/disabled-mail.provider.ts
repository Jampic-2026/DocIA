import { Injectable } from "@nestjs/common";
import { MailProvider } from "../../domain/ports/mail-provider";

@Injectable()
export class DisabledMailProvider implements MailProvider {
  sendNotification(): Promise<void> {
    return Promise.reject(new Error("El envío de correo está deshabilitado."));
  }
  async sendRegistrationVerification(): Promise<void> {
    return Promise.resolve();
  }
  async sendPasswordReset(): Promise<void> {
    return Promise.resolve();
  }
}
