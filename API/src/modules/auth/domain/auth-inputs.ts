export type ChangePasswordDto = {
  currentPassword: string;
  newPassword: string;
};
export type RefreshTokenDto = {
  refreshToken: string;
};
export type CompleteRegistrationDto = {
  token: string;
  password: string;
  firstName: string;
  lastName: string;
  secondLastName?: string;
  phone?: string;
  birthDate: string;
  documentType?: string;
  documentNumber?: string;
  municipality?: string;
  zone?: string;
  addressLine?: string;
  acceptRequiredConsents: boolean;
  guardianEmail?: string;
  guardianRelationship?: string;
};
export type DisableMfaDto = {
  password: string;
  code: string;
};
