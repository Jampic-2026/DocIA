import { Module } from "@nestjs/common";
import { AuditService } from "./application/audit.service";
import { AUDIT_REPOSITORY } from "./domain/ports/audit.repository";
import { PostgresAuditRepository } from "./infrastructure/persistence/postgres-audit.repository";
import { AuditController } from "./interfaces/http/audit.controller";

@Module({
  controllers: [AuditController],
  providers: [
    AuditService,
    {
      provide: AUDIT_REPOSITORY,
      useClass: PostgresAuditRepository,
    },
  ],
  exports: [AuditService],
})
export class AuditModule {}
