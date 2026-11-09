import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from "@nestjs/common";
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from "class-validator";
import { CurrentUser } from "../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../common/decorators/permissions.decorator";
import { PermissionCodes } from "../../../common/auth/permission-codes";
import { RequestUser } from "../../../common/types/request-user";
import { GuidanceService } from "../application/guidance.service";
export class CallRequestDto {
  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
  @IsOptional() @IsUUID() assessmentId?: string;
  @IsOptional() @IsUUID() emergencyId?: string;
}
export class CallTransitionDto {
  @IsIn(["assign", "start", "reject", "complete", "cancel"]) action!: string;
  @IsOptional() @IsUUID() professionalId?: string;
  @IsOptional() @IsString() @MaxLength(4000) notes?: string;
}
export class OrientationDecisionDto {
  @IsIn(["emergency", "appointment", "call_operator", "declined"])
  decision!: string;
  @IsOptional() @IsUUID() relatedId?: string;
}
export class ApproveRiskPolicyDto {
  @IsInt() @Min(1) revision!: number;
  @IsString() @MinLength(8) @MaxLength(1000) reference!: string;
}
@Controller("guidance")
export class GuidanceController {
  constructor(private readonly service: GuidanceService) {}
  @Get("risk-policy")
  @Permissions(PermissionCodes.aiManage)
  policy(@CurrentUser() user: RequestUser) {
    return this.service.policy(user);
  }
  @Patch("risk-policy")
  @Permissions(PermissionCodes.aiManage)
  savePolicy(@CurrentUser() user: RequestUser, @Body() value: unknown) {
    return this.service.savePolicy(user, value);
  }
  @Post("risk-policy/approve")
  @Permissions(PermissionCodes.aiManage)
  approve(
    @CurrentUser() user: RequestUser,
    @Body() value: ApproveRiskPolicyDto,
  ) {
    return this.service.approvePolicy(user, value.revision, value.reference);
  }
  @Post("assessments/:id/decision")
  @Permissions(PermissionCodes.aiUse)
  decision(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() value: OrientationDecisionDto,
  ) {
    return this.service.decision(user, id, value.decision, value.relatedId);
  }
  @Get("support-calls")
  @Permissions(PermissionCodes.appointmentsRead)
  calls(@CurrentUser() user: RequestUser) {
    return this.service.calls(user);
  }
  @Post("support-calls")
  @Permissions(PermissionCodes.appointmentsRead)
  request(@CurrentUser() user: RequestUser, @Body() value: CallRequestDto) {
    return this.service.requestCall(
      user,
      value.reason,
      value.assessmentId,
      value.emergencyId,
    );
  }
  @Get("support-staff")
  @Permissions(PermissionCodes.emergenciesManage)
  staff(@CurrentUser() user: RequestUser) {
    return this.service.staff(user);
  }
  @Patch("support-calls/:id")
  @Permissions(PermissionCodes.appointmentsRead)
  transition(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() value: CallTransitionDto,
  ) {
    return this.service.transitionCall(
      user,
      id,
      value.action,
      value.professionalId,
      value.notes,
    );
  }
  @Post("support-calls/:id/join")
  @Permissions(PermissionCodes.appointmentsRead)
  join(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.service.joinCall(user, id);
  }
}
