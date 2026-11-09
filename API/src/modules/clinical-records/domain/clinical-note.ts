export type ClinicalNote = {
  id: string;
  appointmentId: string;
  patientId: string;
  professionalId: string;
  subjective: string;
  objective: string | null;
  assessment: string;
  plan: string | null;
  createdAt: Date;
};
