export type ProfessionalPatient = {
  id: string;
  fullName: string;
  age: number | null;
  latestAssessment: string | null;
  lastVisitAt: Date | null;
  appointmentId: string | null;
};
