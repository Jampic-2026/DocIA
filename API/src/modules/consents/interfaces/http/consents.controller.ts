import { Controller, Get, Param, Post, Req } from "@nestjs/common";
import { FastifyRequest } from "fastify";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { ConsentsService } from "../../application/consents.service";

@Permissions(PermissionCodes.consentsRead)
@Controller("consents")
export class ConsentsController {
  constructor(private readonly service: ConsentsService) {}

  @Get()
  list(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }

  @Post(":code/accept")
  @Permissions(PermissionCodes.consentsManage)
  accept(
    @CurrentUser() user: RequestUser,
    @Param("code") code: string,
    @Req() request: FastifyRequest,
  ) {
    return this.service.accept(user, code, {
      ipAddress: request.ip,
      userAgent: request.headers["user-agent"],
    });
  }

  @Post(":code/revoke")
  @Permissions(PermissionCodes.consentsManage)
  revoke(@CurrentUser() user: RequestUser, @Param("code") code: string) {
    return this.service.revoke(user, code);
  }
}
