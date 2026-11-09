export type MedicalHistoryRecord = {
  id: string;
  type: string;
  title: string;
  summary: string;
  authorName: string | null;
  specialty: string | null;
  recordedAt: Date;
  validationStatus: string;
};
