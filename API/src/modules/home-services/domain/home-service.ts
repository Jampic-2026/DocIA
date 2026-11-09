export type HomeService = {
  id: string;
  patientId: string;
  serviceId: string;
  serviceName: string;
  addressId: string;
  assignedProfessionalId: string | null;
  assignedPartnerId: string | null;
  status: string;
  requestedFor: Date | null;
  clinicalNotes: string | null;
  createdAt: Date;
  updatedAt: Date;
};
