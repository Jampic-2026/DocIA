export type ProfessionalAvailability = {
  weekday: number;
  startTime: string;
  endTime: string;
  modality: "telemedicine" | "home_visit" | "in_person";
};

export type ProfessionalDirectoryEntry = {
  bookableSlots: {
    startAt: string;
    endAt: string;
    modality: ProfessionalAvailability["modality"];
  }[];
  requiresReferral: boolean;
  publicDetails: {
    bio: string | null;
    academicBackground: string | null;
    certifications: string[];
    verifiedAt: Date | null;
    isSpecialist: boolean;
    reviews: unknown[];
  };
  id: string;
  fullName: string;
  specialtyId: string;
  specialty: string;
  yearsExperience: number;
  averageRating: number;
  ratingCount: number;
  availability: ProfessionalAvailability[];
};
