import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { AdministrationService } from "../../application/administration.service";
import { UpdateSystemSettingDto } from "./dto/update-system-setting.dto";
import {
  AssignPermissionsDto,
  UpsertBusinessRuleDto,
  UpsertOperatingSiteDto,
  UpsertRoleDto,
} from "./dto/administration.dto";
@Controller("administration")
export class AdministrationController {
  constructor(private readonly service: AdministrationService) {}
  @Get("system-settings")
  @Permissions(PermissionCodes.administrationRead)
  settings(@CurrentUser() user: RequestUser) {
    return this.service.settings(user);
  }
  @Put("system-settings/:key")
  @Permissions(PermissionCodes.administrationManage)
  update(
    @CurrentUser() user: RequestUser,
    @Param("key") key: string,
    @Body() input: UpdateSystemSettingDto,
  ) {
    return this.service.updateSetting(user, key, input);
  }

  @Get("roles")
  @Permissions(PermissionCodes.administrationRead)
  roles(@CurrentUser() user: RequestUser) {
    return this.service.roles(user);
  }

  @Get("permissions")
  @Permissions(PermissionCodes.administrationRead)
  permissions(@CurrentUser() user: RequestUser) {
    return this.service.permissions(user);
  }

  @Post("roles")
  @Permissions(PermissionCodes.administrationManage)
  createRole(@CurrentUser() user: RequestUser, @Body() input: UpsertRoleDto) {
    return this.service.createRole(user, input);
  }

  @Patch("roles/:id")
  @Permissions(PermissionCodes.administrationManage)
  updateRole(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertRoleDto,
  ) {
    return this.service.updateRole(user, id, input);
  }

  @Put("roles/:id/permissions")
  @Permissions(PermissionCodes.administrationManage)
  assignPermissions(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: AssignPermissionsDto,
  ) {
    return this.service.assignPermissions(user, id, input);
  }

  @Get("operating-sites")
  @Permissions(PermissionCodes.administrationRead)
  sites(@CurrentUser() user: RequestUser) {
    return this.service.sites(user);
  }

  @Post("operating-sites")
  @Permissions(PermissionCodes.administrationManage)
  createSite(
    @CurrentUser() user: RequestUser,
    @Body() input: UpsertOperatingSiteDto,
  ) {
    return this.service.createSite(user, input);
  }

  @Patch("operating-sites/:id")
  @Permissions(PermissionCodes.administrationManage)
  updateSite(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertOperatingSiteDto,
  ) {
    return this.service.updateSite(user, id, input);
  }

  @Get("business-rules")
  @Permissions(PermissionCodes.administrationRead)
  rules(@CurrentUser() user: RequestUser) {
    return this.service.rules(user);
  }

  @Post("business-rules")
  @Permissions(PermissionCodes.administrationManage)
  createRule(
    @CurrentUser() user: RequestUser,
    @Body() input: UpsertBusinessRuleDto,
  ) {
    return this.service.createRule(user, input);
  }

  @Patch("business-rules/:id")
  @Permissions(PermissionCodes.administrationManage)
  updateRule(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertBusinessRuleDto,
  ) {
    return this.service.updateRule(user, id, input);
  }

  @Get("reports/operational-summary")
  @Permissions(PermissionCodes.administrationRead)
  report(@CurrentUser() user: RequestUser) {
    return this.service.operationalReport(user);
  }
}
