export type ProfessionalAvailability = {
  id: string;
  weekday: number;
  startTime: string;
  endTime: string;
  modality: "telemedicine" | "home_visit" | "in_person";
};

export type ProfessionalTimeBlock = {
  id: string;
  startAt: Date;
  endAt: Date;
  reason: string | null;
};

export type ProfessionalSchedule = {
  availability: ProfessionalAvailability[];
  timeBlocks: ProfessionalTimeBlock[];
};
