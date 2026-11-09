import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { IntegrationsRepository } from "../../domain/ports/integrations.repository";
@Injectable()
export class PostgresIntegrationsRepository implements IntegrationsRepository {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}
  logIntegrationAction(user: RequestUser, action: string): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,
           entity_type,new_values)
         VALUES($1,$2,'integrations',$3,'external_integration',
           jsonb_build_object('provider','google_meet'))`,
        [user.id, user.roleCode, action],
      );
    });
  }
}
