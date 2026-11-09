export type PrescriptionItem = {
  id: string;
  medicationName: string;
  dose: string | null;
  frequency: string | null;
  duration: string | null;
  instructions: string | null;
};

export type Prescription = {
  id: string;
  patientId: string;
  patientName: string;
  professionalName: string;
  status: "draft" | "issued" | "cancelled" | "expired";
  issuedAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
  items: PrescriptionItem[];
};
