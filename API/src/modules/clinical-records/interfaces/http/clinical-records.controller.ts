import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { ClinicalRecordsService } from "../../application/clinical-records.service";
import { CreateClinicalNoteDto } from "./dto/create-clinical-note.dto";
import { UpdateClinicalProfileDto } from "./dto/update-clinical-profile.dto";
import { CreateVitalSignDto } from "./dto/create-vital-sign.dto";
import { CreateProfessionalVitalsDto } from "./dto/create-professional-vitals.dto";
import { CreateClinicalDocumentDto } from "./dto/create-clinical-document.dto";
import { ValidateClinicalItemDto } from "./dto/validate-clinical-item.dto";
import { CreateClinicalCorrectionDto } from "./dto/create-clinical-correction.dto";
import { ResolveClinicalCorrectionDto } from "./dto/resolve-clinical-correction.dto";
import { CloseConsultationDto } from "./dto/close-consultation.dto";
import { CompletionPolicyDto } from "./dto/completion-policy.dto";

@Permissions(PermissionCodes.clinicalRecordsRead)
@Controller("clinical-records")
export class ClinicalRecordsController {
  private exportCategories(value?: string) {
    if (value === undefined) return undefined;
    const values = value.split(",");
    if (
      !values.length ||
      values.some(
        (item) =>
          ![
            "vitalSigns",
            "encounters",
            "conditions",
            "medicationRequests",
            "clinicalRecords",
          ].includes(item),
      )
    )
      throw new BadRequestException(
        "Selecciona categor\u00edas cl\u00ednicas v\u00e1lidas.",
      );
    return [...new Set(values)];
  }

  @Get("completion-policy")
  @Permissions()
  completionPolicy(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.completionPolicy(user);
  }

  @Put("completion-policy")
  @Permissions(PermissionCodes.administrationManage)
  saveCompletionPolicy(
    @CurrentUser() user: RequestUser,
    @Body() input: CompletionPolicyDto,
  ) {
    return this.clinicalRecordsService.saveCompletionPolicy(user, input);
  }

  @Post("completion")
  completion(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.completion(user);
  }

  @Post("patients/:patientId/completion")
  patientCompletion(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
  ) {
    return this.clinicalRecordsService.completion(user, patientId);
  }
  constructor(
    private readonly clinicalRecordsService: ClinicalRecordsService,
  ) {}

  @Get("profile")
  profile(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.ownProfile(user);
  }

  @Patch("profile")
  @Permissions(PermissionCodes.patientsManage)
  updateProfile(
    @CurrentUser() user: RequestUser,
    @Body() input: UpdateClinicalProfileDto,
  ) {
    return this.clinicalRecordsService.updateOwnProfile(user, input);
  }

  @Get("history")
  history(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.ownHistory(user);
  }

  @Get("patients/:patientId/history")
  patientHistory(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
  ) {
    return this.clinicalRecordsService.ownHistory(user, patientId);
  }

  @Get("trends")
  trends(@CurrentUser() user: RequestUser, @Query("days") days?: string) {
    return this.clinicalRecordsService.trends(
      user,
      undefined,
      days ? Number(days) : 90,
    );
  }

  @Get("patients/:patientId/trends")
  trendsForPatient(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
    @Query("days") days?: string,
  ) {
    return this.clinicalRecordsService.trends(
      user,
      patientId,
      days ? Number(days) : 90,
    );
  }

  @Get("export")
  exportOwnRecord(
    @CurrentUser() user: RequestUser,
    @Query("format") format?: "jampic" | "fhir",
    @Query("categories") categories?: string,
  ) {
    if (format && !["jampic", "fhir"].includes(format)) {
      throw new BadRequestException("El formato solicitado no es válido.");
    }
    return this.clinicalRecordsService.exportRecord(
      user,
      undefined,
      format,
      this.exportCategories(categories),
    );
  }

  @Get("patients/:patientId/export")
  exportPatientRecord(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
    @Query("format") format?: "jampic" | "fhir",
    @Query("categories") categories?: string,
  ) {
    if (format && !["jampic", "fhir"].includes(format)) {
      throw new BadRequestException("El formato solicitado no es válido.");
    }
    return this.clinicalRecordsService.exportRecord(
      user,
      patientId,
      format,
      this.exportCategories(categories),
    );
  }

  @Post("clinical-notes")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  createClinicalNote(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateClinicalNoteDto,
  ) {
    return this.clinicalRecordsService.createNote(user, input);
  }

  @Post("consultations/close")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  closeConsultation(
    @CurrentUser() user: RequestUser,
    @Body() input: CloseConsultationDto,
  ) {
    return this.clinicalRecordsService.closeConsultation(user, input);
  }

  @Get("clinical-records")
  clinicalRecords(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.resource(user, "clinical_records");
  }

  @Get("patients/:patientId/record")
  @Permissions(PermissionCodes.clinicalRecordsRead)
  patientRecord(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
  ) {
    return this.clinicalRecordsService.professionalPatientRecord(
      user,
      patientId,
    );
  }

  @Patch("patients/:patientId/statements/:type/:statementId/validation")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  validateStatement(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
    @Param("type") type: "allergy" | "antecedent",
    @Param("statementId", ParseUUIDPipe) statementId: string,
    @Body() input: ValidateClinicalItemDto,
  ) {
    if (!(["allergy", "antecedent"] as string[]).includes(type)) {
      throw new BadRequestException(
        "El tipo de registro clínico no es válido.",
      );
    }
    return this.clinicalRecordsService.validateStatement(
      user,
      patientId,
      type,
      statementId,
      input,
    );
  }

  @Patch("patients/:patientId/documents/:documentId/validation")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  validateDocument(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
    @Param("documentId", ParseUUIDPipe) documentId: string,
    @Body() input: ValidateClinicalItemDto,
  ) {
    return this.clinicalRecordsService.validateDocument(
      user,
      patientId,
      documentId,
      input,
    );
  }

  @Get("clinical-correction-requests")
  clinicalCorrectionRequests(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.correctionRequests(user);
  }

  @Post("clinical-correction-requests")
  @Permissions(PermissionCodes.clinicalRecordsRead)
  createClinicalCorrectionRequest(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateClinicalCorrectionDto,
  ) {
    return this.clinicalRecordsService.createCorrectionRequest(user, input);
  }

  @Patch("clinical-correction-requests/:requestId/resolve")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  resolveClinicalCorrectionRequest(
    @CurrentUser() user: RequestUser,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() input: ResolveClinicalCorrectionDto,
  ) {
    return this.clinicalRecordsService.resolveCorrectionRequest(
      user,
      requestId,
      input,
    );
  }

  @Get("clinical-record-versions")
  clinicalRecordVersions(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.resource(
      user,
      "clinical_record_versions",
    );
  }

  @Get("allergies")
  allergies(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.resource(user, "allergies");
  }

  @Get("medical-antecedents")
  medicalAntecedents(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.resource(user, "medical_antecedents");
  }

  @Get("vital-signs")
  vitalSigns(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.ownVitalSigns(user);
  }

  @Post("vital-signs")
  @Permissions(PermissionCodes.patientsManage)
  createVitalSign(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateVitalSignDto,
  ) {
    return this.clinicalRecordsService.createOwnVitalSign(user, input);
  }

  @Post("patients/:patientId/vital-signs")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  createProfessionalVitalSign(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
    @Body() input: CreateProfessionalVitalsDto,
  ) {
    return this.clinicalRecordsService.createProfessionalVitalSign(
      user,
      patientId,
      input,
    );
  }

  @Get("patients/:patientId/profile")
  patientProfile(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
  ) {
    return this.clinicalRecordsService.ownProfile(user, patientId);
  }

  @Patch("patients/:patientId/profile")
  @Permissions(PermissionCodes.patientsManage)
  updatePatientProfile(
    @CurrentUser() user: RequestUser,
    @Param("patientId", ParseUUIDPipe) patientId: string,
    @Body() input: UpdateClinicalProfileDto,
  ) {
    return this.clinicalRecordsService.updateOwnProfile(user, input, patientId);
  }

  @Get("clinical-documents")
  clinicalDocuments(@CurrentUser() user: RequestUser) {
    return this.clinicalRecordsService.ownDocuments(user);
  }

  @Post("clinical-documents")
  @Permissions(PermissionCodes.patientsManage)
  createClinicalDocument(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateClinicalDocumentDto,
  ) {
    return this.clinicalRecordsService.createOwnDocument(user, input);
  }
}
