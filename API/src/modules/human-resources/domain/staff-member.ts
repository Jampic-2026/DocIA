export type StaffMember = {
  academicBackground?: string | null;
  certifications?: string[];
  professionalId: string;
  fullName: string;
  professionalType: string;
  specialty: string | null;
  verificationStatus: string;
  employeeCode: string | null;
  contractType: string | null;
  employmentStatus: string | null;
  hiredAt: Date | null;
};
