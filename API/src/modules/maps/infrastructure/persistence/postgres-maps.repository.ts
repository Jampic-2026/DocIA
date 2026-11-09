import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { MapsRepository } from "../../domain/ports/maps.repository";
@Injectable()
export class PostgresMapsRepository implements MapsRepository {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}
  logLocationPreview(
    user: RequestUser,
    latitude: number,
    longitude: number,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,
           entity_type,new_values)
         VALUES($1,$2,'maps','location_preview_requested','geolocation',
           jsonb_build_object(
             'latitude',$3::double precision,
             'longitude',$4::double precision
           ))`,
        [user.id, user.roleCode, latitude, longitude],
      );
    });
  }
}
