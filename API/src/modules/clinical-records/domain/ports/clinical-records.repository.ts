import { RequestUser } from "../../../../common/types/request-user";
import { CompletionPolicy } from "../profile-completion";
import { ClinicalNote } from "../clinical-note";
import { ClinicalProfile, ClinicalProfileUpdate } from "../clinical-profile";
import { MedicalHistoryRecord } from "../medical-history-record";
import { CreateVitalSign, VitalSignRecord } from "../vital-sign-record";
import { ClinicalDocument, CreateClinicalDocument } from "../clinical-document";
import { ProfessionalPatientRecord } from "../professional-patient-record";
import {
  ClinicalCorrectionRequest,
  CreateClinicalCorrectionRequest,
} from "../clinical-correction-request";

export const CLINICAL_RECORDS_REPOSITORY = Symbol(
  "CLINICAL_RECORDS_REPOSITORY",
);
export type ClinicalResource =
  | "clinical_records"
  | "clinical_record_versions"
  | "allergies"
  | "medical_antecedents";

export interface ClinicalRecordsRepository {
  completionPolicy(user: RequestUser): Promise<CompletionPolicy>;
  saveCompletionPolicy(
    user: RequestUser,
    policy: CompletionPolicy,
  ): Promise<void>;
  completion(user: RequestUser, patientId?: string): Promise<unknown>;
  createProfessionalVitalSign(
    user: RequestUser,
    patientId: string,
    input: CreateVitalSign & { appointmentId?: string; emergencyId?: string },
  ): Promise<VitalSignRecord>;
  getTrends(
    user: RequestUser,
    patientId?: string,
    days?: number,
  ): Promise<unknown>;
  exportRecord(
    user: RequestUser,
    patientId?: string,
    format?: "jampic" | "fhir",
    categories?: string[],
  ): Promise<unknown>;
  resource(user: RequestUser, resource: ClinicalResource): Promise<unknown[]>;
  getOwnProfile(
    user: RequestUser,
    patientId?: string,
  ): Promise<ClinicalProfile | null>;
  updateOwnProfile(
    user: RequestUser,
    input: ClinicalProfileUpdate,
    patientId?: string,
  ): Promise<void>;
  listOwnHistory(
    user: RequestUser,
    patientId?: string,
  ): Promise<MedicalHistoryRecord[]>;
  listOwnVitalSigns(user: RequestUser): Promise<VitalSignRecord[]>;
  createOwnVitalSign(
    user: RequestUser,
    input: CreateVitalSign,
  ): Promise<VitalSignRecord>;
  listOwnDocuments(user: RequestUser): Promise<ClinicalDocument[]>;
  createOwnDocument(
    user: RequestUser,
    input: CreateClinicalDocument,
  ): Promise<ClinicalDocument>;
  getProfessionalPatientRecord(
    user: RequestUser,
    patientId: string,
  ): Promise<ProfessionalPatientRecord | null>;
  validateStatement(
    user: RequestUser,
    patientId: string,
    statementType: "allergy" | "antecedent",
    statementId: string,
    status: "validated" | "rejected",
    notes?: string,
  ): Promise<void>;
  validateDocument(
    user: RequestUser,
    patientId: string,
    documentId: string,
    status: "validated" | "rejected",
    notes?: string,
  ): Promise<void>;
  listCorrectionRequests(
    user: RequestUser,
    operational: boolean,
  ): Promise<ClinicalCorrectionRequest[]>;
  createCorrectionRequest(
    user: RequestUser,
    input: CreateClinicalCorrectionRequest,
  ): Promise<ClinicalCorrectionRequest>;
  resolveCorrectionRequest(
    user: RequestUser,
    requestId: string,
    status: "accepted" | "rejected",
    resolution: string,
  ): Promise<string>;
  createNote(
    user: RequestUser,
    input: {
      appointmentId: string;
      patientId: string;
      subjective: string;
      objective?: string;
      assessment: string;
      plan?: string;
    },
  ): Promise<ClinicalNote>;
  closeConsultation(
    user: RequestUser,
    input: {
      appointmentId: string;
      patientId: string;
      subjective: string;
      objective?: string;
      assessment: string;
      plan?: string;
      diagnosis: string;
      diagnosisType: string;
      treatment?: string;
      treatmentInstructions?: string;
      followupDueAt?: Date;
      followupInstructions?: string;
    },
  ): Promise<ClinicalNote>;
}
