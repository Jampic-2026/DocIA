export type Appointment = {
  id: string;
  patientId: string;
  patientName: string;
  professionalId: string;
  professionalName: string;
  specialty: string;
  modality: "telemedicine" | "home_visit" | "in_person";
  status:
    | "scheduled"
    | "confirmed"
    | "rescheduled"
    | "cancelled"
    | "in_progress"
    | "completed"
    | "no_show";
  startAt: Date;
  endAt: Date;
  reason: string | null;
};
