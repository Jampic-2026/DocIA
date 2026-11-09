import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { Public } from "../../../../common/decorators/public.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { AuthService } from "../../application/auth.service";
import { ChangePasswordDto } from "./dto/change-password.dto";
import { LoginDto } from "./dto/login.dto";
import { LogoutDto } from "./dto/logout.dto";
import { RefreshTokenDto } from "./dto/refresh-token.dto";
import {
  CompleteRegistrationDto,
  RequestRegistrationDto,
} from "./dto/registration.dto";
import { RequestPasswordResetDto } from "./dto/request-password-reset.dto";
import { ResetPasswordDto } from "./dto/reset-password.dto";
import {
  ConfirmMfaDto,
  ConfirmPhoneVerificationDto,
  DisableMfaDto,
  RequestPhoneVerificationDto,
  SetupMfaDto,
} from "./dto/security.dto";
import { Throttle } from "@nestjs/throttler";

type RequestMetadata = {
  headers: Record<string, string | string[] | undefined>;
  ip?: string;
};
@Controller("auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}
  @Public()
  @Post("registration/request")
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  requestRegistration(
    @Body() dto: RequestRegistrationDto,
    @Req() request: RequestMetadata,
  ) {
    return this.authService.requestRegistration(dto, {
      userAgent: this.singleHeader(request.headers["user-agent"]),
      ipAddress: request.ip,
    });
  }
  @Public()
  @Post("registration/complete")
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  completeRegistration(@Body() dto: CompleteRegistrationDto) {
    return this.authService.completeRegistration(dto);
  }
  @Public()
  @Post("login")
  @Throttle({ default: { limit: 8, ttl: 60_000 } })
  login(@Body() dto: LoginDto, @Req() request: RequestMetadata) {
    return this.authService.login(dto, {
      userAgent: this.singleHeader(request.headers["user-agent"]),
      ipAddress: request.ip,
    });
  }
  @Public()
  @Post("refresh")
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto);
  }
  @Public() @Post("logout") logout(@Body() dto: LogoutDto) {
    return this.authService.logout(dto);
  }
  @Get("me") me(@CurrentUser() user: RequestUser) {
    return this.authService.me(user);
  }
  @Get("sessions") sessions(@CurrentUser() user: RequestUser) {
    return this.authService.sessions(user);
  }
  @Post("mfa/setup") setupMfa(
    @CurrentUser() user: RequestUser,
    @Body() input: SetupMfaDto,
  ) {
    return this.authService.setupMfa(user, input.password);
  }
  @Post("mfa/confirm") confirmMfa(
    @CurrentUser() user: RequestUser,
    @Body() input: ConfirmMfaDto,
  ) {
    return this.authService.confirmMfa(user, input.code);
  }
  @Post("mfa/disable") disableMfa(
    @CurrentUser() user: RequestUser,
    @Body() input: DisableMfaDto,
  ) {
    return this.authService.disableMfa(user, input);
  }
  @Post("phone-verification/request") requestPhoneVerification(
    @CurrentUser() user: RequestUser,
    @Body() input: RequestPhoneVerificationDto,
  ) {
    return this.authService.requestPhoneVerification(user, input.phone);
  }
  @Post("phone-verification/confirm") confirmPhoneVerification(
    @CurrentUser() user: RequestUser,
    @Body() input: ConfirmPhoneVerificationDto,
  ) {
    return this.authService.confirmPhoneVerification(user, input.code);
  }
  @Patch("password") changePassword(
    @CurrentUser() user: RequestUser,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(user, dto);
  }
  @Patch("sessions/:sessionId/revoke") revokeSession(
    @CurrentUser() user: RequestUser,
    @Param("sessionId", ParseUUIDPipe) sessionId: string,
  ) {
    return this.authService.revokeSession(user, sessionId);
  }
  @Public()
  @Post("password-reset/request")
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  requestPasswordReset(@Body() dto: RequestPasswordResetDto) {
    return this.authService.requestPasswordReset(dto);
  }
  @Public()
  @Post("password-reset/confirm")
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }
  @Get("registration-email-tokens")
  @Permissions(PermissionCodes.usersRead)
  registrationEmailTokens(@CurrentUser() user: RequestUser) {
    return this.authService.administrativeResource(
      user,
      "registration-email-tokens",
    );
  }
  @Get("user-sessions")
  @Permissions(PermissionCodes.sessionsManage)
  userSessions(@CurrentUser() user: RequestUser) {
    return this.authService.administrativeResource(user, "user-sessions");
  }
  private singleHeader(value: string | string[] | undefined) {
    return Array.isArray(value) ? value[0] : value;
  }
}
