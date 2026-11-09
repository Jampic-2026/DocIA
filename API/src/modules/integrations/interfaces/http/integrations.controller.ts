import {
  BadRequestException,
  Controller,
  Delete,
  Get,
  Query,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { Public } from "../../../../common/decorators/public.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { IntegrationsService } from "../../application/integrations.service";

@Controller("integrations")
export class IntegrationsController {
  constructor(private readonly service: IntegrationsService) {}

  @Get("google/status")
  @Permissions(PermissionCodes.appointmentsRead)
  googleStatus() {
    return this.service.googleStatus();
  }

  @Get("google/authorize")
  @Permissions(PermissionCodes.administrationManage)
  googleAuthorize(@CurrentUser() user: RequestUser) {
    return this.service.googleAuthorization(user);
  }

  @Delete("google")
  @Permissions(PermissionCodes.administrationManage)
  disconnectGoogle(@CurrentUser() user: RequestUser) {
    return this.service.disconnectGoogle(user);
  }

  @Public()
  @Get("google/callback")
  googleCallback(@Query("code") code?: string, @Query("state") state?: string) {
    if (!code || !state) {
      throw new BadRequestException(
        "Google no devolvió el código OAuth requerido.",
      );
    }
    return this.service.googleCallback(code, state);
  }
}
