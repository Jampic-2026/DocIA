import { ConflictException, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { Incident } from "../../domain/incident";
import { IncidentsRepository } from "../../domain/ports/incidents.repository";

const incidentColumns = `id,module,incident_type AS "incidentType",
  severity::text,description,status,resolution,
  resolved_at AS "resolvedAt",created_at AS "createdAt"`;

@Injectable()
export class PostgresIncidentsRepository implements IncidentsRepository {
  constructor(private readonly database: DatabaseService) {}

  list(user: RequestUser): Promise<Incident[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<Incident>(
        `SELECT ${incidentColumns} FROM incidents
         WHERE reported_by_user_id=$1
         ORDER BY created_at DESC LIMIT 100`,
        [user.id],
      );
      return result.rows;
    });
  }

  create(
    user: RequestUser,
    input: {
      module: string;
      incidentType: string;
      severity: string;
      description: string;
    },
  ): Promise<Incident> {
    return this.database.transactionAsUser(user, async (client) => {
      const patient = await client.query<{ id: string }>(
        `SELECT patient.id FROM patients patient
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1 LIMIT 1`,
        [user.id],
      );
      const result = await client.query<Incident>(
        `INSERT INTO incidents
          (reported_by_user_id,patient_id,module,incident_type,severity,description)
         VALUES($1,$2,$3,$4,$5::risk_level,$6)
         RETURNING ${incidentColumns}`,
        [
          user.id,
          patient.rows[0]?.id ?? null,
          input.module,
          input.incidentType,
          input.severity,
          input.description.trim(),
        ],
      );
      return result.rows[0];
    });
  }

  close(user: RequestUser, id: string): Promise<Incident> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<Incident>(
        `UPDATE incidents SET status='closed'
         WHERE id=$1 AND reported_by_user_id=$2
           AND status IN('open','pending')
         RETURNING ${incidentColumns}`,
        [id, user.id],
      );
      if (!result.rows[0]) {
        throw new ConflictException(
          "El incidente no existe o ya está siendo atendido.",
        );
      }
      return result.rows[0];
    });
  }
}
