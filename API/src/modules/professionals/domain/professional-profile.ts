export type ProfessionalProfile = {
  id: string;
  professionalType: string;
  licenseNumber: string | null;
  bio: string | null;
  academicBackground: string | null;
  publicCertifications: string[];
  yearsExperience: number | null;
  verificationStatus: string;
  publicProfileEnabled: boolean;
  pendingSpecialtyId: string | null;
  specialties: Array<{ id: string; name: string; isPrimary: boolean }>;
  documents: Array<{
    id: string;
    documentType: string;
    fileUrl: string;
    status: string;
    observation: string | null;
    createdAt: Date;
  }>;
};
