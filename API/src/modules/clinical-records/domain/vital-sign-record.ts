export type VitalSignRecord = {
  id: string;
  source: string;
  systolicPressure: number | null;
  diastolicPressure: number | null;
  heartRate: number | null;
  temperatureC: number | null;
  oxygenSaturation: number | null;
  respiratoryRate: number | null;
  glucoseMgDl: number | null;
  weightKg: number | null;
  heightCm: number | null;
  notes: string | null;
  recordedAt: Date;
};

export type CreateVitalSign = Omit<
  VitalSignRecord,
  "id" | "source" | "recordedAt"
>;
