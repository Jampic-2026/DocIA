import { SMS_PROVIDER } from "./domain/ports/sms";
import { HttpSmsProvider } from "./infrastructure/sms/http-sms.provider";
import { Module } from "@nestjs/common";
import { APP_GUARD } from "@nestjs/core";
import { JwtModule } from "@nestjs/jwt";
import { ThrottlerGuard } from "@nestjs/throttler";
import { JwtAuthGuard } from "../../common/guards/jwt-auth.guard";
import { PermissionsGuard } from "../../common/guards/permissions.guard";
import { MailModule } from "../mail/mail.module";
import { AuthService } from "./application/auth.service";
import { AUTH_REPOSITORY } from "./domain/ports/auth.repository";
import { PostgresAuthRepository } from "./infrastructure/persistence/postgres-auth.repository";
import { AuthController } from "./interfaces/http/auth.controller";

@Module({
  imports: [JwtModule.register({}), MailModule],
  controllers: [AuthController],
  providers: [
    { provide: SMS_PROVIDER, useClass: HttpSmsProvider },
    { provide: AUTH_REPOSITORY, useClass: PostgresAuthRepository },
    AuthService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: PermissionsGuard,
    },
  ],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
