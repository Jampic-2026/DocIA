import { RequestUser } from "../../../../common/types/request-user";
import { Prescription } from "../prescription";

export const PRESCRIPTIONS_REPOSITORY = Symbol("PRESCRIPTIONS_REPOSITORY");

export interface PrescriptionsRepository {
  listForUser(user: RequestUser): Promise<Prescription[]>;
  createDraft(
    user: RequestUser,
    input: {
      patientId: string;
      appointmentId: string;
      items: Array<{
        medicationName: string;
        dose?: string;
        frequency?: string;
        duration?: string;
        instructions?: string;
      }>;
    },
  ): Promise<Prescription>;
  safetyReview(
    user: RequestUser,
    id: string,
  ): Promise<{
    allergies: Array<{ substance: string; reaction: string | null }>;
    fingerprint: string;
  }>;
  issue(
    user: RequestUser,
    id: string,
    expiresAt: Date,
    review?: { fingerprint?: string; reason?: string },
  ): Promise<Prescription>;
}
