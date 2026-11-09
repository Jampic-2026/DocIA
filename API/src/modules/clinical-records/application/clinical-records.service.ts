import { Inject, Injectable, NotFoundException } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  CLINICAL_RECORDS_REPOSITORY,
  ClinicalResource,
  ClinicalRecordsRepository,
} from "../domain/ports/clinical-records.repository";
import { UpdateClinicalProfileDto } from "../interfaces/http/dto/update-clinical-profile.dto";
import { CreateVitalSignDto } from "../interfaces/http/dto/create-vital-sign.dto";
import { CreateProfessionalVitalsDto } from "../interfaces/http/dto/create-professional-vitals.dto";
import { CreateClinicalDocumentDto } from "../interfaces/http/dto/create-clinical-document.dto";
import { BadRequestException } from "@nestjs/common";
import { ValidateClinicalItemDto } from "../interfaces/http/dto/validate-clinical-item.dto";
import { CreateClinicalCorrectionDto } from "../interfaces/http/dto/create-clinical-correction.dto";
import { ResolveClinicalCorrectionDto } from "../interfaces/http/dto/resolve-clinical-correction.dto";
import { NotificationsService } from "../../notifications/application/notifications.service";
import { CloseConsultationDto } from "../interfaces/http/dto/close-consultation.dto";
import { CompletionPolicy } from "../domain/profile-completion";

@Injectable()
export class ClinicalRecordsService {
  completionPolicy(user: RequestUser) {
    return this.repository.completionPolicy(user);
  }
  saveCompletionPolicy(user: RequestUser, policy: CompletionPolicy) {
    return this.repository.saveCompletionPolicy(user, policy);
  }
  completion(user: RequestUser, patientId?: string) {
    return this.repository.completion(user, patientId);
  }
  constructor(
    @Inject(CLINICAL_RECORDS_REPOSITORY)
    private readonly repository: ClinicalRecordsRepository,
    private readonly notifications: NotificationsService,
  ) {}

  trends(user: RequestUser, patientId?: string, days = 90) {
    if (!Number.isInteger(days) || days < 1 || days > 730) {
      throw new BadRequestException("El rango debe estar entre 1 y 730 días.");
    }
    return this.repository.getTrends(user, patientId, days);
  }

  async createProfessionalVitalSign(
    user: RequestUser,
    patientId: string,
    input: CreateProfessionalVitalsDto,
  ) {
    if (Boolean(input.appointmentId) === Boolean(input.emergencyId))
      throw new BadRequestException(
        "Vincula exactamente una cita o emergencia activa.",
      );
    if (input.systolicPressure <= input.diastolicPressure)
      throw new BadRequestException(
        "La presión sistólica debe superar la diastólica.",
      );
    const record = await this.repository.createProfessionalVitalSign(
      user,
      patientId,
      {
        ...input,
        respiratoryRate: input.respiratoryRate ?? null,
        glucoseMgDl: input.glucoseMgDl ?? null,
        weightKg: input.weightKg ?? null,
        heightCm: input.heightCm ?? null,
        notes: input.notes?.trim() ?? null,
      },
    );
    return { ...record, recordedAt: record.recordedAt.toISOString() };
  }

  exportRecord(
    user: RequestUser,
    patientId?: string,
    format: "jampic" | "fhir" = "jampic",
    categories?: string[],
  ) {
    return this.repository.exportRecord(user, patientId, format, categories);
  }
  async resource(user: RequestUser, resource: ClinicalResource) {
    return { items: await this.repository.resource(user, resource) };
  }

  async ownProfile(user: RequestUser, patientId?: string) {
    const profile = await this.repository.getOwnProfile(user, patientId);
    if (!profile) {
      throw new NotFoundException("La cuenta no tiene un perfil de paciente.");
    }
    return profile;
  }

  async ownHistory(user: RequestUser, patientId?: string) {
    const records = await this.repository.listOwnHistory(user, patientId);
    return {
      items: records.map((record) => ({
        ...record,
        recordedAt: record.recordedAt.toISOString(),
      })),
    };
  }

  async updateOwnProfile(
    user: RequestUser,
    input: UpdateClinicalProfileDto,
    patientId?: string,
  ) {
    await this.repository.updateOwnProfile(user, input, patientId);
    return this.ownProfile(user, patientId);
  }

  async ownVitalSigns(user: RequestUser) {
    const records = await this.repository.listOwnVitalSigns(user);
    return {
      items: records.map((record) => ({
        ...record,
        recordedAt: record.recordedAt.toISOString(),
      })),
    };
  }

  async createOwnVitalSign(user: RequestUser, input: CreateVitalSignDto) {
    const values = Object.entries(input).filter(
      ([key, value]) => key !== "notes" && value != null,
    );
    if (values.length === 0) {
      throw new BadRequestException("Registra al menos un signo vital.");
    }
    const record = await this.repository.createOwnVitalSign(user, {
      systolicPressure: input.systolicPressure ?? null,
      diastolicPressure: input.diastolicPressure ?? null,
      heartRate: input.heartRate ?? null,
      temperatureC: input.temperatureC ?? null,
      oxygenSaturation: input.oxygenSaturation ?? null,
      respiratoryRate: input.respiratoryRate ?? null,
      glucoseMgDl: input.glucoseMgDl ?? null,
      weightKg: input.weightKg ?? null,
      heightCm: input.heightCm ?? null,
      notes: input.notes?.trim() || null,
    });
    return { ...record, recordedAt: record.recordedAt.toISOString() };
  }

  async ownDocuments(user: RequestUser) {
    const documents = await this.repository.listOwnDocuments(user);
    return {
      items: documents.map((document) => ({
        ...document,
        createdAt: document.createdAt.toISOString(),
      })),
    };
  }

  async createOwnDocument(user: RequestUser, input: CreateClinicalDocumentDto) {
    const document = await this.repository.createOwnDocument(user, input);
    return { ...document, createdAt: document.createdAt.toISOString() };
  }

  async professionalPatientRecord(user: RequestUser, patientId: string) {
    const record = await this.repository.getProfessionalPatientRecord(
      user,
      patientId,
    );
    if (!record) {
      throw new NotFoundException(
        "El paciente no existe o no está autorizado para este profesional.",
      );
    }
    return {
      ...record,
      birthDate: record.birthDate?.toISOString().slice(0, 10) ?? null,
      vitalSigns: record.vitalSigns.map((vital) => ({
        ...vital,
        recordedAt: vital.recordedAt.toISOString(),
      })),
      documents: record.documents.map((document) => ({
        ...document,
        createdAt: document.createdAt.toISOString(),
      })),
    };
  }

  async validateStatement(
    user: RequestUser,
    patientId: string,
    type: "allergy" | "antecedent",
    statementId: string,
    input: ValidateClinicalItemDto,
  ) {
    await this.repository.validateStatement(
      user,
      patientId,
      type,
      statementId,
      input.status,
      input.notes?.trim(),
    );
    return this.professionalPatientRecord(user, patientId);
  }

  async validateDocument(
    user: RequestUser,
    patientId: string,
    documentId: string,
    input: ValidateClinicalItemDto,
  ) {
    await this.repository.validateDocument(
      user,
      patientId,
      documentId,
      input.status,
      input.notes?.trim(),
    );
    return this.professionalPatientRecord(user, patientId);
  }

  async correctionRequests(user: RequestUser) {
    const operational = user.roles.some((role) =>
      ["admin", "clinical_supervisor"].includes(role),
    );
    const requests = await this.repository.listCorrectionRequests(
      user,
      operational,
    );
    return {
      items: requests.map((request) => ({
        ...request,
        createdAt: request.createdAt.toISOString(),
        resolvedAt: request.resolvedAt?.toISOString() ?? null,
      })),
    };
  }

  async createCorrectionRequest(
    user: RequestUser,
    input: CreateClinicalCorrectionDto,
  ) {
    const request = await this.repository.createCorrectionRequest(user, {
      clinicalRecordId: input.clinicalRecordId,
      requestedChange: input.requestedChange.trim(),
      reason: input.reason.trim(),
    });
    return { ...request, createdAt: request.createdAt.toISOString() };
  }

  async resolveCorrectionRequest(
    user: RequestUser,
    requestId: string,
    input: ResolveClinicalCorrectionDto,
  ) {
    if (
      !user.roles.some((role) =>
        ["admin", "clinical_supervisor"].includes(role),
      )
    ) {
      throw new BadRequestException(
        "La cuenta no puede resolver correcciones clínicas.",
      );
    }
    const patientId = await this.repository.resolveCorrectionRequest(
      user,
      requestId,
      input.status,
      input.resolution.trim(),
    );
    await this.notifications.notifyPatient(user, patientId, {
      eventCode: "clinical_records",
      title: "Solicitud de corrección resuelta",
      body:
        input.status === "accepted"
          ? "La corrección solicitada fue aceptada."
          : "La corrección solicitada fue observada.",
      relatedEntityType: "clinical_correction_request",
      relatedEntityId: requestId,
    });
    return { resolved: true };
  }

  async createNote(
    user: RequestUser,
    input: {
      appointmentId: string;
      patientId: string;
      subjective: string;
      objective?: string;
      assessment: string;
      plan?: string;
    },
  ) {
    const note = await this.repository.createNote(user, input);
    return { ...note, createdAt: note.createdAt.toISOString() };
  }

  async closeConsultation(user: RequestUser, input: CloseConsultationDto) {
    const note = await this.repository.closeConsultation(user, {
      ...input,
      followupDueAt: input.followupDueAt
        ? new Date(input.followupDueAt)
        : undefined,
    });
    await this.notifications.notifyPatient(user, note.patientId, {
      eventCode: "appointments",
      title: "Consulta finalizada",
      body: "El profesional finalizó la atención y actualizó tu expediente.",
      relatedEntityType: "appointment",
      relatedEntityId: note.appointmentId,
    });
    return { ...note, createdAt: note.createdAt.toISOString() };
  }
}
