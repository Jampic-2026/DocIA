export type SaveWorkShift = {
  professionalId: string;
  startAt: string;
  endAt: string;
  location: string;
  area?: string;
  notes?: string;
  status: "assigned" | "cancelled";
  reason: string;
};
export type ShiftQuery = { from?: string; to?: string };
export type StaffAvailabilityQuery = {
  role?: string;
  location?: string;
  specialtyId?: string;
  availableOnly?: string;
  serviceType?: string;
};
