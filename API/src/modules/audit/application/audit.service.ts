import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  AUDIT_REPOSITORY,
  AuditRepository,
} from "../domain/ports/audit.repository";

@Injectable()
export class AuditService {
  constructor(
    @Inject(AUDIT_REPOSITORY)
    private readonly repository: AuditRepository,
  ) {}

  async events(user: RequestUser) {
    const events = await this.repository.listEvents(user);
    return {
      items: events.map((event) => ({
        ...event,
        createdAt: event.createdAt.toISOString(),
      })),
    };
  }
  async clinicalAccess(user: RequestUser) {
    return { items: await this.repository.listClinicalAccess(user) };
  }
  async financialEvents(user: RequestUser) {
    return { items: await this.repository.listFinancialEvents(user) };
  }
}
