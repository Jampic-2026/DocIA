export type FamilyMember = {
  id: string;
  patientId: string | null;
  linkKind: "dependent" | "incoming" | "outgoing";
  fullName: string;
  relationship: string;
  age: number | null;
  isDependent: boolean;
  status: string;
  canViewHistory: boolean;
  canBookAppointments: boolean;
  canHandleEmergencies: boolean;
};
