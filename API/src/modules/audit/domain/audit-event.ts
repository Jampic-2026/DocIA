export type AuditEvent = {
  id: string;
  module: string;
  action: string;
  entityType: string | null;
  actorName: string | null;
  actorRole: string | null;
  reason: string | null;
  createdAt: Date;
};
