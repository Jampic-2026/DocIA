import {
  Body,
  Controller,
  Delete,
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
import { PatientsService } from "../../application/patients.service";
import { CreateFamilyAuthorizationDto } from "./dto/create-family-authorization.dto";
import { UpdateFamilyAuthorizationDto } from "./dto/update-family-authorization.dto";
import { RedeemGuardianLinkCodeDto } from "./dto/redeem-guardian-link-code.dto";
import { CreateDependentDto } from "./dto/create-dependent.dto";

@Permissions(PermissionCodes.patientsRead)
@Controller("patients")
export class PatientsController {
  constructor(private readonly patientsService: PatientsService) {}

  @Post("dependents")
  @Permissions(PermissionCodes.patientsManage)
  createDependent(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateDependentDto,
  ) {
    return this.patientsService.createDependent(user, input);
  }

  @Get("family")
  family(@CurrentUser() user: RequestUser) {
    return this.patientsService.family(user);
  }

  @Post("family-authorizations")
  @Permissions(PermissionCodes.patientsManage)
  createFamilyAuthorization(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateFamilyAuthorizationDto,
  ) {
    return this.patientsService.createFamilyAuthorization(user, input);
  }

  @Patch("family-authorizations/:id")
  @Permissions(PermissionCodes.patientsManage)
  updateFamilyAuthorization(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpdateFamilyAuthorizationDto,
  ) {
    return this.patientsService.updateFamilyAuthorization(user, id, input);
  }

  @Delete("family-authorizations/:id")
  @Permissions(PermissionCodes.patientsManage)
  revokeFamilyAuthorization(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.patientsService.revokeFamilyAuthorization(user, id);
  }

  @Get("patients")
  patients(@CurrentUser() user: RequestUser) {
    return this.patientsService.forProfessional(user);
  }

  @Post("guardian-link-codes")
  @Permissions(PermissionCodes.patientsManage)
  createGuardianLinkCode(@CurrentUser() user: RequestUser) {
    return this.patientsService.createGuardianLinkCode(user);
  }

  @Post("patient-guardians/redeem")
  @Permissions(PermissionCodes.patientsManage)
  redeemGuardianLinkCode(
    @CurrentUser() user: RequestUser,
    @Body() input: RedeemGuardianLinkCodeDto,
  ) {
    return this.patientsService.redeemGuardianLinkCode(user, input);
  }

  @Get("emergency-contacts")
  emergencyContacts(@CurrentUser() user: RequestUser) {
    return this.patientsService.resource(user, "emergency_contacts");
  }

  @Get("patient-guardians")
  patientGuardians(@CurrentUser() user: RequestUser) {
    return this.patientsService.resource(user, "patient_guardians");
  }

  @Get("family-authorizations")
  familyAuthorizations(@CurrentUser() user: RequestUser) {
    return this.patientsService.resource(user, "family_authorizations");
  }

  @Get("family-authorization-permissions")
  familyAuthorizationPermissions(@CurrentUser() user: RequestUser) {
    return this.patientsService.resource(
      user,
      "family_authorization_permissions",
    );
  }

  @Get("patient-profile-completion")
  patientProfileCompletion(@CurrentUser() user: RequestUser) {
    return this.patientsService.resource(user, "patient_profile_completion");
  }
}
