import { RequestUser } from "../../../../common/types/request-user";
import { FamilyMember } from "../family-member";
import { ProfessionalPatient } from "../professional-patient";
import { CreateDependent } from "../create-dependent";

export const PATIENTS_REPOSITORY = Symbol("PATIENTS_REPOSITORY");
export type PatientResource =
  | "emergency_contacts"
  | "patient_guardians"
  | "family_authorizations"
  | "family_authorization_permissions"
  | "patient_profile_completion";

export interface PatientsRepository {
  createDependent(
    user: RequestUser,
    input: CreateDependent,
  ): Promise<{ patientId: string }>;
  listFamily(user: RequestUser): Promise<FamilyMember[]>;
  listForProfessional(user: RequestUser): Promise<ProfessionalPatient[]>;
  createFamilyAuthorization(
    user: RequestUser,
    input: {
      email: string;
      relationship: string;
      canViewHistory: boolean;
      canBookAppointments: boolean;
      canHandleEmergencies: boolean;
    },
  ): Promise<void>;
  updateFamilyAuthorization(
    user: RequestUser,
    id: string,
    input: {
      relationship?: string;
      canViewHistory: boolean;
      canBookAppointments: boolean;
      canHandleEmergencies: boolean;
    },
  ): Promise<void>;
  revokeFamilyAuthorization(user: RequestUser, id: string): Promise<void>;
  createGuardianLinkCode(user: RequestUser): Promise<{
    code: string;
    expiresAt: Date;
  }>;
  redeemGuardianLinkCode(
    user: RequestUser,
    input: { code: string; relationship: string },
  ): Promise<void>;
  resource(user: RequestUser, resource: PatientResource): Promise<unknown[]>;
}
