import { RequestUser } from "../../../../common/types/request-user";
import { StaffMember } from "../staff-member";

export const HUMAN_RESOURCES_REPOSITORY = Symbol("HUMAN_RESOURCES_REPOSITORY");
export type HumanResourcesResource =
  "personnel_applications" | "personnel_documents" | "personnel_observations";

export interface HumanResourcesRepository {
  requirements(user: RequestUser): Promise<unknown[]>;
  configureRequirements(
    user: RequestUser,
    roleCode: string,
    documentTypes: string[],
  ): Promise<unknown>;
  professionalDocuments(
    user: RequestUser,
    professionalId: string,
  ): Promise<unknown[]>;
  reviewProfessionalDocument(
    user: RequestUser,
    documentId: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  submitApplication(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  addApplicationDocument(
    user: RequestUser,
    applicationId: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  reviewApplication(
    user: RequestUser,
    applicationId: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  reviewDocument(
    user: RequestUser,
    documentId: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  updateEmploymentRecord(
    user: RequestUser,
    recordId: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  createObservation(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  report(user: RequestUser): Promise<unknown>;
  auditEvents(user: RequestUser): Promise<unknown[]>;
  listStaff(user: RequestUser): Promise<StaffMember[]>;
  reviewProfessional(
    user: RequestUser,
    professionalId: string,
    input: {
      status: "approved" | "rejected";
      reason?: string;
      roleCode?: string;
      specialtyId?: string;
    },
  ): Promise<void>;
  resource(
    user: RequestUser,
    resource: HumanResourcesResource,
  ): Promise<unknown[]>;
}
