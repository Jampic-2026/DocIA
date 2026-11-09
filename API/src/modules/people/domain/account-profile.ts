export type AccountProfile = {
  personId: string;
  firstName: string;
  lastName: string;
  secondLastName: string | null;
  documentType: string | null;
  documentNumber: string | null;
  birthDate: Date | null;
  nationality: string | null;
  phone: string | null;
  email: string;
  photoUrl: string | null;
  address: {
    municipality: string | null;
    zone: string | null;
    addressLine: string | null;
    reference: string | null;
  } | null;
};
