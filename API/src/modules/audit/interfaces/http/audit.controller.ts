import { Controller, Get } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { AuditService } from "../../application/audit.service";

@Permissions(PermissionCodes.auditRead)
@Controller("audit")
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get("audit-events")
  auditEvents(@CurrentUser() user: RequestUser) {
    return this.auditService.events(user);
  }

  @Get("clinical-access-logs")
  clinicalAccessLogs(@CurrentUser() user: RequestUser) {
    return this.auditService.clinicalAccess(user);
  }

  @Get("financial-events")
  financialEvents(@CurrentUser() user: RequestUser) {
    return this.auditService.financialEvents(user);
  }
}
