import { Injectable, BadRequestException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { SmsProvider } from "../../domain/ports/sms";
@Injectable()
export class HttpSmsProvider implements SmsProvider {
  constructor(private readonly config: ConfigService) {}
  async send(to: string, message: string) {
    if (!this.config.get<boolean>("sms.enabled")) {
      if (this.config.get<string>("nodeEnv") === "production")
        throw new BadRequestException("El proveedor SMS no está configurado.");
      return;
    }
    const response = await fetch(this.config.getOrThrow<string>("sms.apiUrl"), {
      method: "POST",
      signal: AbortSignal.timeout(15000),
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${this.config.getOrThrow<string>("sms.apiToken")}`,
      },
      body: JSON.stringify({
        to,
        message,
        sender: this.config.get<string>("sms.sender", "Doc IA"),
      }),
    });
    if (!response.ok)
      throw new BadRequestException("No se pudo enviar el código SMS.");
  }
}
