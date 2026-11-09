export const emergencyTransitions: Record<string, readonly string[]> = {
  received: ["confirming", "validating", "cancelled", "false_alarm"],
  confirming: ["validating", "assigned", "cancelled", "false_alarm"],
  validating: ["assigned", "cancelled", "false_alarm"],
  assigned: ["on_route", "cancelled", "false_alarm"],
  on_route: ["on_site", "cancelled", "false_alarm"],
  on_site: ["in_care", "referred", "closed", "false_alarm"],
  in_care: ["referred", "closed", "false_alarm"],
  referred: ["closed"],
};
export const emergencyTerminalStatuses = ["closed", "cancelled", "false_alarm"];
export function isEmergencyCoordinator(roles: readonly string[]) {
  return roles.some((role) =>
    ["admin", "operator", "clinical_supervisor"].includes(role),
  );
}
export type CreateEmergency = {
  patientId?: string;
  riskLevel: "green" | "yellow" | "red";
  description?: string;
  manualAddress?: string;
  latitude?: number;
  longitude?: number;
};
export type EmergencyCare = {
  careType:
    | "nursing_assessment"
    | "medical_assessment"
    | "intervention"
    | "referral"
    | "closure";
  notes: string;
  symptoms: string[];
  assessment: string;
  procedures?: string;
  referralDestination?: string;
};
