import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { PrescriptionsService } from "../../application/prescriptions.service";
import { CreatePrescriptionDto } from "./dto/create-prescription.dto";
import { IssuePrescriptionDto } from "./dto/issue-prescription.dto";

@Permissions(PermissionCodes.prescriptionsRead)
@Controller("prescriptions")
export class PrescriptionsController {
  constructor(private readonly prescriptionsService: PrescriptionsService) {}

  @Get("prescriptions")
  prescriptions(@CurrentUser() user: RequestUser) {
    return this.prescriptionsService.listForUser(user);
  }

  @Post("prescriptions")
  @Permissions(PermissionCodes.prescriptionsManage)
  create(
    @CurrentUser() user: RequestUser,
    @Body() input: CreatePrescriptionDto,
  ) {
    return this.prescriptionsService.createDraft(user, input);
  }

  @Patch("prescriptions/:id/issue")
  @Permissions(PermissionCodes.prescriptionsManage)
  issue(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: IssuePrescriptionDto,
  ) {
    return this.prescriptionsService.issue(user, id, input.expiresAt, {
      fingerprint: input.allergyFingerprint,
      reason: input.allergyReviewReason,
    });
  }
  @Get("prescriptions/:id/safety-review")
  @Permissions(PermissionCodes.prescriptionsManage)
  safetyReview(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.prescriptionsService.safetyReview(user, id);
  }

  @Get("prescription-items")
  prescriptionItems(@CurrentUser() user: RequestUser) {
    return this.prescriptionsService.itemsForUser(user);
  }
}
