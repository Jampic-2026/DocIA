export type ClinicalProfile = {
  patientId: string;
  bloodType: string | null;
  heightCm: number | null;
  weightKg: number | null;
  insuranceProvider: string | null;
  insuranceNumber: string | null;
  profileNotes: string | null;
  allergies: string[];
  chronicConditions: string[];
  currentMedications: string[];
  medicalHistory: string[];
  familyHistory: string[];
  surgicalHistory: string[];
  emergencyContactName: string | null;
  emergencyContactRelationship: string | null;
  emergencyContactPhone: string | null;
  emergencyContactEmail: string | null;
};

export type ClinicalProfileUpdate = {
  bloodType?: string;
  heightCm?: number;
  weightKg?: number;
  insuranceProvider?: string;
  insuranceNumber?: string;
  profileNotes?: string;
  allergies?: string[];
  chronicConditions?: string[];
  currentMedications?: string[];
  medicalHistory?: string[];
  familyHistory?: string[];
  surgicalHistory?: string[];
  emergencyContactName?: string;
  emergencyContactRelationship?: string;
  emergencyContactPhone?: string;
  emergencyContactEmail?: string;
};
