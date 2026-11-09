import { Controller, Post } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { OperationsService } from "../../application/operations.service";

@Controller("operations")
@Permissions(PermissionCodes.administrationManage)
export class OperationsController {
  constructor(private readonly service: OperationsService) {}

  @Post("maintenance/process-daily")
  processDaily(@CurrentUser() user: RequestUser) {
    return this.service.processDailyMaintenance(user);
  }
}
