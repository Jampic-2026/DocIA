export type ClinicalDocument = {
  id: string;
  documentType: string;
  fileUrl: string;
  fileName: string | null;
  mimeType: string | null;
  isRestricted: boolean;
  source: string;
  validationStatus: string;
  createdAt: Date;
};

export type CreateClinicalDocument = {
  documentType: string;
  fileUrl: string;
  fileName?: string;
  mimeType?: string;
  isRestricted?: boolean;
};
