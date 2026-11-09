export const clinicalExportCategories = [
  "vitalSigns",
  "encounters",
  "conditions",
  "medicationRequests",
  "clinicalRecords",
] as const;
export type ClinicalExportCategory = (typeof clinicalExportCategories)[number];
