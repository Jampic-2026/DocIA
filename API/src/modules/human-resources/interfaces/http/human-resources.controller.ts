import { Body, Controller, Get, Param, Patch, Post, Put } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { HumanResourcesService } from "../../application/human-resources.service";
import { ReviewProfessionalDto } from "./dto/review-professional.dto";
import {
  AddPersonnelDocumentDto,
  CreatePersonnelObservationDto,
  ReviewPersonnelApplicationDto,
  ReviewPersonnelDocumentDto,
  SubmitPersonnelApplicationDto,
  UpdateEmploymentRecordDto,
  ConfigureProfessionalRequirementsDto,
} from "./dto/human-resources.dto";

@Permissions(PermissionCodes.humanResourcesRead)
@Controller("human-resources")
export class HumanResourcesController {
  constructor(private readonly service: HumanResourcesService) {}

  @Get("document-requirements")
  @Permissions()
  requirements(@CurrentUser() user: RequestUser) {
    return this.service.requirements(user);
  }

  @Put("document-requirements/:roleCode")
  @Permissions(PermissionCodes.humanResourcesManage)
  configureRequirements(
    @CurrentUser() user: RequestUser,
    @Param("roleCode") roleCode: string,
    @Body() input: ConfigureProfessionalRequirementsDto,
  ) {
    return this.service.configureRequirements(
      user,
      roleCode,
      input.documentTypes,
    );
  }

  @Get("professionals/:professionalId/documents")
  professionalDocuments(
    @CurrentUser() user: RequestUser,
    @Param("professionalId") professionalId: string,
  ) {
    return this.service.professionalDocuments(user, professionalId);
  }

  @Patch("professional-documents/:documentId/review")
  @Permissions(PermissionCodes.humanResourcesManage)
  reviewProfessionalDocument(
    @CurrentUser() user: RequestUser,
    @Param("documentId") documentId: string,
    @Body() input: ReviewPersonnelDocumentDto,
  ) {
    return this.service.reviewProfessionalDocument(user, documentId, input);
  }

  @Post("personnel-applications")
  @Permissions()
  submitApplication(
    @CurrentUser() user: RequestUser,
    @Body() input: SubmitPersonnelApplicationDto,
  ) {
    return this.service.submitApplication(user, input);
  }

  @Post("personnel-applications/:applicationId/documents")
  @Permissions()
  addApplicationDocument(
    @CurrentUser() user: RequestUser,
    @Param("applicationId") applicationId: string,
    @Body() input: AddPersonnelDocumentDto,
  ) {
    return this.service.addApplicationDocument(user, applicationId, input);
  }

  @Get("personnel-applications")
  @Permissions()
  personnelApplications(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "personnel_applications");
  }

  @Patch("personnel-applications/:applicationId/review")
  @Permissions(PermissionCodes.humanResourcesManage)
  reviewApplication(
    @CurrentUser() user: RequestUser,
    @Param("applicationId") applicationId: string,
    @Body() input: ReviewPersonnelApplicationDto,
  ) {
    return this.service.reviewApplication(user, applicationId, input);
  }

  @Get("personnel-documents")
  @Permissions()
  personnelDocuments(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "personnel_documents");
  }

  @Patch("personnel-documents/:documentId/review")
  @Permissions(PermissionCodes.humanResourcesManage)
  reviewDocument(
    @CurrentUser() user: RequestUser,
    @Param("documentId") documentId: string,
    @Body() input: ReviewPersonnelDocumentDto,
  ) {
    return this.service.reviewDocument(user, documentId, input);
  }

  @Get("employment-records")
  employmentRecords(@CurrentUser() user: RequestUser) {
    return this.service.staff(user);
  }

  @Patch("employment-records/:recordId")
  @Permissions(PermissionCodes.humanResourcesManage)
  updateEmploymentRecord(
    @CurrentUser() user: RequestUser,
    @Param("recordId") recordId: string,
    @Body() input: UpdateEmploymentRecordDto,
  ) {
    return this.service.updateEmploymentRecord(user, recordId, input);
  }

  @Patch("professionals/:professionalId/verification")
  @Permissions(PermissionCodes.humanResourcesManage)
  reviewProfessional(
    @CurrentUser() user: RequestUser,
    @Param("professionalId") professionalId: string,
    @Body() input: ReviewProfessionalDto,
  ) {
    return this.service.reviewProfessional(user, professionalId, input);
  }

  @Get("personnel-observations")
  personnelObservations(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "personnel_observations");
  }

  @Post("personnel-observations")
  @Permissions(PermissionCodes.humanResourcesManage)
  createObservation(
    @CurrentUser() user: RequestUser,
    @Body() input: CreatePersonnelObservationDto,
  ) {
    return this.service.createObservation(user, input);
  }

  @Get("reports/summary")
  report(@CurrentUser() user: RequestUser) {
    return this.service.report(user);
  }

  @Get("audit-events")
  auditEvents(@CurrentUser() user: RequestUser) {
    return this.service.auditEvents(user);
  }
}
