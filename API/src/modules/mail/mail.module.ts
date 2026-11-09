import { Module } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { MailService } from "./application/mail.service";
import { MAIL_PROVIDER } from "./domain/ports/mail-provider";
import { DisabledMailProvider } from "./infrastructure/disabled/disabled-mail.provider";
import { ResendMailProvider } from "./infrastructure/resend/resend-mail.provider";

@Module({
  providers: [
    MailService,
    {
      provide: MAIL_PROVIDER,
      inject: [ConfigService],
      useFactory: (config: ConfigService) =>
        config.get<boolean>("email.enabled")
          ? new ResendMailProvider(config)
          : new DisabledMailProvider(),
    },
  ],
  exports: [MailService],
})
export class MailModule {}
