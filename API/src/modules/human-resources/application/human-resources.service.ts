import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  HUMAN_RESOURCES_REPOSITORY,
  HumanResourcesResource,
  HumanResourcesRepository,
} from "../domain/ports/human-resources.repository";

@Injectable()
export class HumanResourcesService {
  constructor(
    @Inject(HUMAN_RESOURCES_REPOSITORY)
    private readonly repository: HumanResourcesRepository,
  ) {}

  async requirements(user: RequestUser) {
    return { items: await this.repository.requirements(user) };
  }
  configureRequirements(
    user: RequestUser,
    roleCode: string,
    documentTypes: string[],
  ) {
    return this.repository.configureRequirements(user, roleCode, documentTypes);
  }
  async professionalDocuments(user: RequestUser, professionalId: string) {
    return {
      items: await this.repository.professionalDocuments(user, professionalId),
    };
  }
  reviewProfessionalDocument(
    user: RequestUser,
    documentId: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.reviewProfessionalDocument(user, documentId, input);
  }

  submitApplication(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.submitApplication(user, input);
  }

  addApplicationDocument(
    user: RequestUser,
    applicationId: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.addApplicationDocument(user, applicationId, input);
  }

  reviewApplication(
    user: RequestUser,
    applicationId: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.reviewApplication(user, applicationId, input);
  }

  reviewDocument(
    user: RequestUser,
    documentId: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.reviewDocument(user, documentId, input);
  }

  updateEmploymentRecord(
    user: RequestUser,
    recordId: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.updateEmploymentRecord(user, recordId, input);
  }

  createObservation(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.createObservation(user, input);
  }

  report(user: RequestUser) {
    return this.repository.report(user);
  }

  async auditEvents(user: RequestUser) {
    return { items: await this.repository.auditEvents(user) };
  }

  async staff(user: RequestUser) {
    return {
      items: (await this.repository.listStaff(user)).map((item) => ({
        ...item,
        hiredAt: item.hiredAt?.toISOString().slice(0, 10) ?? null,
      })),
    };
  }

  async reviewProfessional(
    user: RequestUser,
    professionalId: string,
    input: {
      status: "approved" | "rejected";
      reason?: string;
      roleCode?: string;
      specialtyId?: string;
    },
  ) {
    await this.repository.reviewProfessional(user, professionalId, input);
    return { professionalId, status: input.status };
  }
  async resource(user: RequestUser, resource: HumanResourcesResource) {
    return { items: await this.repository.resource(user, resource) };
  }
}
