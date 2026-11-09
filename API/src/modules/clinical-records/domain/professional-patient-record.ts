import { ClinicalDocument } from "./clinical-document";
import { VitalSignRecord } from "./vital-sign-record";

export type ClinicalStatement = {
  id: string;
  type: "allergy" | "antecedent";
  category: string;
  description: string;
  detail: string | null;
  validationStatus: string;
};

export type ProfessionalPatientRecord = {
  patientId: string;
  fullName: string;
  birthDate: Date | null;
  bloodType: string | null;
  heightCm: number | null;
  weightKg: number | null;
  insuranceProvider: string | null;
  insuranceNumber: string | null;
  profileNotes: string | null;
  emergencyContact: string | null;
  statements: ClinicalStatement[];
  vitalSigns: VitalSignRecord[];
  documents: ClinicalDocument[];
};
