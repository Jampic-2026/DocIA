import { RequestUser } from "../../../../common/types/request-user";
import { AuditEvent } from "../audit-event";

export const AUDIT_REPOSITORY = Symbol("AUDIT_REPOSITORY");

export interface AuditRepository {
  listEvents(user: RequestUser): Promise<AuditEvent[]>;
  listClinicalAccess(user: RequestUser): Promise<unknown[]>;
  listFinancialEvents(user: RequestUser): Promise<unknown[]>;
}
