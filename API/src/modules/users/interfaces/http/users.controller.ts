import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { UsersService } from "../../application/users.service";
import { UpdateUserRolesDto } from "./dto/update-user-roles.dto";
import { UpdateUserStatusDto } from "./dto/update-user-status.dto";
@Controller("users")
export class UsersController {
  constructor(private readonly service: UsersService) {}
  @Get("overview") @Permissions(PermissionCodes.usersRead) overview(
    @CurrentUser() user: RequestUser,
  ) {
    return this.service.overview(user);
  }
  @Patch(":id/status") @Permissions(PermissionCodes.usersUpdate) status(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpdateUserStatusDto,
  ) {
    return this.service.updateStatus(user, id, input.status, input.reason);
  }
  @Patch(":id/roles") @Permissions(PermissionCodes.usersUpdate) roles(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpdateUserRolesDto,
  ) {
    return this.service.updateRoles(user, id, input.roleCodes);
  }
}
