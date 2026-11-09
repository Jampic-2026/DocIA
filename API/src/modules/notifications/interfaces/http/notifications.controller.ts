import { Body, Controller, Get, Param, Patch, Post, Put } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { NotificationsService } from "../../application/notifications.service";
import {
  PushDeviceTokenDto,
  UnregisterPushDeviceDto,
} from "./dto/push-device-token.dto";
import { UpdateNotificationPreferenceDto } from "./dto/update-notification-preference.dto";

@Permissions(PermissionCodes.notificationsRead)
@Controller("notifications")
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }

  @Patch(":id/read")
  markRead(@CurrentUser() user: RequestUser, @Param("id") id: string) {
    return this.service.markRead(user, id);
  }

  @Post("read-all")
  markAllRead(@CurrentUser() user: RequestUser) {
    return this.service.markAllRead(user);
  }

  @Get("preferences")
  preferences(@CurrentUser() user: RequestUser) {
    return this.service.preferences(user);
  }

  @Put("preferences")
  @Permissions(PermissionCodes.notificationsManage)
  updatePreference(
    @CurrentUser() user: RequestUser,
    @Body() input: UpdateNotificationPreferenceDto,
  ) {
    return this.service.updatePreference(user, input);
  }

  @Post("push-devices")
  @Permissions(PermissionCodes.notificationsManage)
  registerPushDevice(
    @CurrentUser() user: RequestUser,
    @Body() input: PushDeviceTokenDto,
  ) {
    return this.service.registerPushDevice(user, input);
  }

  @Post("push-devices/unregister")
  @Permissions(PermissionCodes.notificationsManage)
  unregisterPushDevice(
    @CurrentUser() user: RequestUser,
    @Body() input: UnregisterPushDeviceDto,
  ) {
    return this.service.unregisterPushDevice(user, input.token);
  }
}
