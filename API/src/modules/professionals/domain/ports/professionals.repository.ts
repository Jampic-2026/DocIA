import { RequestUser } from "../../../../common/types/request-user";
import { ProfessionalDirectoryEntry } from "../professional-directory-entry";
import { ProfessionalSchedule } from "../professional-schedule";
import { ProfessionalProfile } from "../professional-profile";
import {
  SaveWorkShift,
  ShiftQuery,
  StaffAvailabilityQuery,
} from "../work-shift";

export const PROFESSIONALS_REPOSITORY = Symbol("PROFESSIONALS_REPOSITORY");
export type ProfessionalResource =
  | "specialties"
  | "professional_specialties"
  | "work_shifts"
  | "work_shift_history";

export interface ProfessionalsRepository {
  listShifts(user: RequestUser, query: ShiftQuery): Promise<unknown[]>;
  saveShift(
    user: RequestUser,
    input: SaveWorkShift,
    id?: string,
  ): Promise<unknown>;
  availableStaff(
    user: RequestUser,
    query: StaffAvailabilityQuery,
  ): Promise<unknown[]>;
  listDirectory(user: RequestUser): Promise<ProfessionalDirectoryEntry[]>;
  getOwnSchedule(user: RequestUser): Promise<ProfessionalSchedule>;
  createAvailability(
    user: RequestUser,
    input: {
      weekday: number;
      startTime: string;
      endTime: string;
      modality: "telemedicine" | "home_visit" | "in_person";
    },
  ): Promise<void>;
  removeAvailability(user: RequestUser, id: string): Promise<void>;
  createTimeBlock(
    user: RequestUser,
    input: {
      startAt: Date;
      endAt: Date;
      reason?: string;
    },
  ): Promise<void>;
  removeTimeBlock(user: RequestUser, id: string): Promise<void>;
  getOwnProfile(user: RequestUser): Promise<ProfessionalProfile>;
  updateOwnProfile(
    user: RequestUser,
    input: {
      academicBackground?: string;
      publicCertifications?: string[];
      licenseNumber?: string;
      specialtyId?: string;
      bio?: string;
      yearsExperience?: number;
      publicProfileEnabled?: boolean;
    },
  ): Promise<void>;
  createOwnDocument(
    user: RequestUser,
    input: {
      documentType: string;
      fileUrl: string;
    },
  ): Promise<void>;
  resource(
    user: RequestUser,
    resource: ProfessionalResource,
  ): Promise<unknown[]>;
}
