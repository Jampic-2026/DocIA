export type ClinicalCorrectionRequest = {
  id: string;
  patientId: string;
  patientName: string;
  entityType: string;
  entityId: string;
  recordTitle: string | null;
  requestedChange: string;
  reason: string;
  status: string;
  resolution: string | null;
  createdAt: Date;
  resolvedAt: Date | null;
};

export type CreateClinicalCorrectionRequest = {
  clinicalRecordId: string;
  requestedChange: string;
  reason: string;
};
