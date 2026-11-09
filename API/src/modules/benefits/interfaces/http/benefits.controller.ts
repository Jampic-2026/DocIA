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
import { BenefitsService } from "../../application/benefits.service";
import {
  ApplyBenefitDto,
  ReverseBenefitDto,
  SetPartnerBenefitDto,
  UpsertBenefitDto,
  ValidateBenefitDto,
} from "./dto/benefit-operations.dto";

@Permissions(PermissionCodes.benefitsRead)
@Controller("benefits")
export class BenefitsController {
  constructor(private readonly service: BenefitsService) {}

  @Get()
  list(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }

  @Get("usages")
  usages(@CurrentUser() user: RequestUser) {
    return this.service.usages(user);
  }

  @Post()
  @Permissions(PermissionCodes.benefitsManage)
  create(@CurrentUser() user: RequestUser, @Body() input: UpsertBenefitDto) {
    return this.service.create(user, input);
  }

  @Patch(":id")
  @Permissions(PermissionCodes.benefitsManage)
  update(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertBenefitDto,
  ) {
    return this.service.update(user, id, input);
  }

  @Post("apply")
  apply(@CurrentUser() user: RequestUser, @Body() input: ApplyBenefitDto) {
    return this.service.apply(user, input);
  }

  @Get("validations")
  @Permissions(PermissionCodes.benefitsManage)
  validations(@CurrentUser() user: RequestUser) {
    return this.service.validations(user);
  }

  @Patch("validations/:id")
  @Permissions(PermissionCodes.benefitsManage)
  validate(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: ValidateBenefitDto,
  ) {
    return this.service.validate(user, id, input);
  }

  @Patch(":benefitId/partners/:partnerId")
  @Permissions(PermissionCodes.benefitsManage)
  setPartner(
    @CurrentUser() user: RequestUser,
    @Param("benefitId", ParseUUIDPipe) benefitId: string,
    @Param("partnerId", ParseUUIDPipe) partnerId: string,
    @Body() input: SetPartnerBenefitDto,
  ) {
    return this.service.setPartner(user, benefitId, partnerId, input);
  }

  @Patch("usages/:id/reverse")
  @Permissions(PermissionCodes.benefitsManage)
  reverse(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: ReverseBenefitDto,
  ) {
    return this.service.reverse(user, id, input);
  }
}
