import { Controller, Get } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { Body, Param, Patch, Post } from "@nestjs/common";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { EmergenciesService } from "../../application/emergencies.service";
import { CreateEmergencyDto } from "./dto/create-emergency.dto";
import { AssignEmergencyDto } from "./dto/assign-emergency.dto";
import { UpdateEmergencyStatusDto } from "./dto/update-emergency-status.dto";
import {
  DecideEmergencyAssignmentDto,
  RecordEmergencyCareDto,
} from "./dto/emergency-care.dto";

@Permissions(PermissionCodes.emergenciesRead)
@Controller("emergencies")
export class EmergenciesController {
  constructor(private readonly service: EmergenciesService) {}

  @Patch("events/:id/assignment-decision")
  @Permissions(PermissionCodes.emergenciesManage)
  decideAssignment(
    @CurrentUser() user: RequestUser,
    @Param("id") id: string,
    @Body() input: DecideEmergencyAssignmentDto,
  ) {
    return this.service.decideAssignment(user, id, input);
  }

  @Post("events/:id/care-records")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  recordCare(
    @CurrentUser() user: RequestUser,
    @Param("id") id: string,
    @Body() input: RecordEmergencyCareDto,
  ) {
    return this.service.recordCare(user, id, input);
  }

  @Get("events/:id/care-records")
  careHistory(@CurrentUser() user: RequestUser, @Param("id") id: string) {
    return this.service.careHistory(user, id);
  }

  @Get("events")
  events(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }

  @Post("events")
  @Permissions(PermissionCodes.emergenciesManage)
  create(@CurrentUser() user: RequestUser, @Body() input: CreateEmergencyDto) {
    return this.service.create(user, input);
  }

  @Patch("events/:id/cancel")
  @Permissions(PermissionCodes.emergenciesManage)
  cancel(@CurrentUser() user: RequestUser, @Param("id") id: string) {
    return this.service.cancel(user, id);
  }

  @Patch("events/:id/assign")
  @Permissions(PermissionCodes.emergenciesManage)
  assign(
    @CurrentUser() user: RequestUser,
    @Param("id") id: string,
    @Body() input: AssignEmergencyDto,
  ) {
    return this.service.assign(user, id, input);
  }

  @Patch("events/:id/status")
  @Permissions(PermissionCodes.emergenciesManage)
  updateStatus(
    @CurrentUser() user: RequestUser,
    @Param("id") id: string,
    @Body() input: UpdateEmergencyStatusDto,
  ) {
    return this.service.updateStatus(user, id, input);
  }

  @Get("emergency-events")
  emergencyEvents(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }

  @Get("emergency-status-history")
  emergencyStatusHistory(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "emergency-status-history");
  }

  @Get("emergency-triage-answers")
  emergencyTriageAnswers(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "emergency-triage-answers");
  }

  @Get("emergency-care-records")
  emergencyCareRecords(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "emergency-care-records");
  }

  @Get("support-call-requests")
  supportCallRequests(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "support-call-requests");
  }
}
