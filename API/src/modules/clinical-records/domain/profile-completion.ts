export const completionFields = [
  "bloodType",
  "heightCm",
  "weightKg",
  "insuranceProvider",
  "emergencyContact",
  "allergies",
  "medicalHistory",
  "familyHistory",
  "surgicalHistory",
  "chronicConditions",
  "currentMedications",
  "validatedAllergies",
  "validatedAntecedents",
  "professionalVitals",
] as const;
export type CompletionField = (typeof completionFields)[number];
export type CompletionRule = {
  field: CompletionField;
  label: string;
  actor: "patient" | "professional";
};
export type CompletionPolicy = {
  rules: CompletionRule[];
  rewardEnabled: boolean;
  benefitId?: string;
  campaignId?: string;
  threshold?: number;
  validUntil?: string;
};
export function calculateCompletion(
  rules: CompletionRule[],
  present: Partial<Record<CompletionField, boolean>>,
) {
  const missing = rules.filter((rule) => present[rule.field] !== true);
  return {
    configured: rules.length > 0,
    percent: rules.length
      ? Math.round(((rules.length - missing.length) / rules.length) * 10000) /
        100
      : null,
    completed: rules.length - missing.length,
    total: rules.length,
    missing,
  };
}
