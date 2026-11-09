import { RequestUser } from "../../../../common/types/request-user";
import { Appointment } from "../appointment";

export const APPOINTMENTS_REPOSITORY = Symbol("APPOINTMENTS_REPOSITORY");
export type AppointmentResource =
  "appointment_status_history" | "clinical_notes" | "diagnoses" | "treatments";

export interface AppointmentsRepository {
  markNoShow(
    user: RequestUser,
    appointmentId: string,
    reason: string,
  ): Promise<Appointment>;
  listForUser(user: RequestUser): Promise<Appointment[]>;
  create(
    user: RequestUser,
    input: {
      professionalId: string;
      serviceId?: string;
      patientId?: string;
      specialtyId: string;
      modality: Appointment["modality"];
      startAt: Date;
      endAt: Date;
      reason?: string;
    },
  ): Promise<Appointment>;
  cancel(
    user: RequestUser,
    appointmentId: string,
    reason?: string,
  ): Promise<Appointment>;
  reschedule(
    user: RequestUser,
    appointmentId: string,
    startAt: Date,
    endAt: Date,
  ): Promise<Appointment>;
  participantUserIds(
    user: RequestUser,
    appointmentId: string,
  ): Promise<{
    patientUserId?: string;
    professionalUserId?: string;
    alertUserIds?: string[];
  }>;
  listCareActions(user: RequestUser): Promise<{
    followups: unknown[];
    referrals: unknown[];
    ratings: unknown[];
  }>;
  rate(
    user: RequestUser,
    appointmentId: string,
    rating: number,
    comment?: string,
    publicComment?: boolean,
  ): Promise<void>;
  createReferral(
    user: RequestUser,
    input: {
      patientId: string;
      specialtyId: string;
      reason: string;
      priority: string;
      referralType: string;
      validUntil?: Date;
    },
  ): Promise<string>;
  resource(
    user: RequestUser,
    resource: AppointmentResource,
  ): Promise<unknown[]>;
}
