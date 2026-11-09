import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { QueryResultRow } from "pg";
import { createHash, randomInt } from "node:crypto";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { FamilyMember } from "../../domain/family-member";
import { ProfessionalPatient } from "../../domain/professional-patient";
import { CreateDependent } from "../../domain/create-dependent";
import {
  PatientResource,
  PatientsRepository,
} from "../../domain/ports/patients.repository";

type FamilyRow = QueryResultRow & {
  id: string;
  patient_id: string | null;
  link_kind: "dependent" | "incoming" | "outgoing";
  full_name: string;
  relationship: string;
  age: number | null;
  is_dependent: boolean;
  status: string;
  can_view_history: boolean;
  can_book_appointments: boolean;
  can_handle_emergencies: boolean;
};

type ProfessionalPatientRow = QueryResultRow & {
  id: string;
  full_name: string;
  age: number | null;
  latest_assessment: string | null;
  last_visit_at: Date | null;
  appointment_id: string | null;
};

@Injectable()
export class PostgresPatientsRepository implements PatientsRepository {
  constructor(private readonly database: DatabaseService) {}

  createDependent(
    user: RequestUser,
    input: CreateDependent,
  ): Promise<{ patientId: string }> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{ patient_id: string }>(
        `SELECT app_create_minor_dependent($1,$2,$3,$4,$5,$6,$7,$8) AS patient_id`,
        [
          input.firstName,
          input.lastName,
          input.secondLastName ?? null,
          input.birthDate,
          input.documentType ?? null,
          input.documentNumber ?? null,
          input.relationship,
          input.confirmResponsibility,
        ],
      );
      return { patientId: result.rows[0].patient_id };
    });
  }

  async createGuardianLinkCode(user: RequestUser): Promise<{
    code: string;
    expiresAt: Date;
  }> {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const value = Array.from(
      { length: 8 },
      () => alphabet[randomInt(alphabet.length)],
    ).join("");
    const code = `JMP-${value.slice(0, 4)}-${value.slice(4)}`;
    const codeHash = createHash("sha256").update(code).digest("hex");
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
    await this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{ id: string }>(
        `INSERT INTO guardian_link_codes(
          minor_patient_id,code_hash,generated_by_user_id,expires_at
         ) SELECT patient.id,$2,$1,$3
           FROM patients patient
           JOIN persons person ON person.id=patient.person_id
          WHERE person.user_id=$1
          RETURNING id`,
        [user.id, codeHash, expiresAt],
      );
      if (!result.rowCount) {
        throw new NotFoundException("No se encontró el perfil de paciente.");
      }
    });
    return { code, expiresAt };
  }

  async redeemGuardianLinkCode(
    user: RequestUser,
    input: { code: string; relationship: string },
  ): Promise<void> {
    const digest = createHash("sha256")
      .update(input.code.trim().toUpperCase())
      .digest("hex");
    await this.database.transactionAsUser(user, async (client) => {
      await client.query("SELECT app_redeem_guardian_code($1,$2)", [
        digest,
        input.relationship,
      ]);
    });
  }

  listFamily(user: RequestUser): Promise<FamilyMember[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<FamilyRow>(
        `
        WITH links AS (
          SELECT guardian.id,patient.id AS patient_id,'dependent'::text AS link_kind,person.first_name,person.last_name,person.second_last_name,
            guardian.relationship,person.birth_date,TRUE AS is_dependent,guardian.verification_status::text AS status,
            app_can_patient_action(patient.id,'clinical_records.read') AS can_view_history,
            app_can_patient_action(patient.id,'appointments.manage') AS can_book_appointments,
            app_can_patient_action(patient.id,'emergencies.manage') AS can_handle_emergencies
          FROM patient_guardians guardian JOIN patients patient ON patient.id=guardian.patient_id JOIN persons person ON person.id=patient.person_id
          WHERE guardian.guardian_user_id=$1 AND guardian.revoked_at IS NULL AND guardian.valid_from<=now() AND (guardian.valid_until IS NULL OR guardian.valid_until>now())
          UNION ALL
          SELECT family_auth.id,patient.id,'incoming',person.first_name,person.last_name,person.second_last_name,family_auth.relationship,person.birth_date,FALSE,family_auth.status::text,
            app_can_patient_action(patient.id,'clinical_records.read'),app_can_patient_action(patient.id,'appointments.manage'),app_can_patient_action(patient.id,'emergencies.manage')
          FROM family_authorizations family_auth JOIN patients patient ON patient.id=family_auth.patient_id JOIN persons person ON person.id=patient.person_id
          WHERE family_auth.family_user_id=$1 AND family_auth.status='active' AND family_auth.revoked_at IS NULL AND family_auth.valid_from<=now() AND (family_auth.valid_until IS NULL OR family_auth.valid_until>now())
          UNION ALL
          SELECT family_auth.id,NULL::uuid,'outgoing',person.first_name,person.last_name,person.second_last_name,family_auth.relationship,person.birth_date,FALSE,family_auth.status::text,
            EXISTS(SELECT 1 FROM family_authorization_permissions permission WHERE permission.authorization_id=family_auth.id AND permission.permission_code='clinical_records.read'),
            EXISTS(SELECT 1 FROM family_authorization_permissions permission WHERE permission.authorization_id=family_auth.id AND permission.permission_code='appointments.manage'),
            EXISTS(SELECT 1 FROM family_authorization_permissions permission WHERE permission.authorization_id=family_auth.id AND permission.permission_code='emergencies.manage')
          FROM family_authorizations family_auth JOIN persons person ON person.user_id=family_auth.family_user_id
          WHERE family_auth.granted_by_user_id=$1 AND family_auth.status='active' AND family_auth.revoked_at IS NULL
        )
        SELECT id,patient_id,link_kind,concat_ws(' ',first_name,last_name,second_last_name) AS full_name,relationship,
          CASE WHEN birth_date IS NULL THEN NULL ELSE extract(year FROM age(current_date,birth_date))::int END AS age,
          is_dependent,status,can_view_history,can_book_appointments,can_handle_emergencies FROM links ORDER BY is_dependent DESC,full_name
      `,
        [user.id],
      );
      return result.rows.map((row) => ({
        id: row.id,
        patientId: row.patient_id,
        linkKind: row.link_kind,
        fullName: row.full_name,
        relationship: row.relationship,
        age: row.age,
        isDependent: row.is_dependent,
        status: row.status,
        canViewHistory: row.can_view_history,
        canBookAppointments: row.can_book_appointments,
        canHandleEmergencies: row.can_handle_emergencies,
      }));
    });
  }

  listForProfessional(user: RequestUser): Promise<ProfessionalPatient[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<ProfessionalPatientRow>(
        `
        WITH current_professional AS (
          SELECT id
          FROM professionals
          WHERE user_id = $1
          LIMIT 1
        ),
        related_patients AS (
          SELECT DISTINCT appointment.patient_id
          FROM appointments appointment
          JOIN current_professional professional
            ON professional.id = appointment.professional_id
          WHERE appointment.status NOT IN ('cancelled', 'no_show')
        )
        SELECT
          patient.id,
          concat_ws(
            ' ',
            person.first_name,
            person.last_name,
            person.second_last_name
          ) AS full_name,
          CASE
            WHEN person.birth_date IS NULL THEN NULL
            ELSE EXTRACT(YEAR FROM age(CURRENT_DATE, person.birth_date))::int
          END AS age,
          latest_note.assessment AS latest_assessment,
          latest_visit.start_at AS last_visit_at,
          note_appointment.id AS appointment_id
        FROM related_patients related
        JOIN patients patient ON patient.id = related.patient_id
        JOIN persons person ON person.id = patient.person_id
        LEFT JOIN LATERAL (
          SELECT note.assessment
          FROM clinical_notes note
          JOIN current_professional professional
            ON professional.id = note.professional_id
          WHERE note.patient_id = patient.id
          ORDER BY note.created_at DESC
          LIMIT 1
        ) latest_note ON true
        LEFT JOIN LATERAL (
          SELECT appointment.start_at
          FROM appointments appointment
          JOIN current_professional professional
            ON professional.id = appointment.professional_id
          WHERE appointment.patient_id = patient.id
            AND appointment.status = 'completed'
          ORDER BY appointment.start_at DESC
          LIMIT 1
        ) latest_visit ON true
        LEFT JOIN LATERAL (
          SELECT appointment.id
          FROM appointments appointment
          JOIN current_professional professional
            ON professional.id = appointment.professional_id
          WHERE appointment.patient_id = patient.id
            AND appointment.status IN (
              'scheduled','confirmed','rescheduled','in_progress'
            )
          ORDER BY
            CASE WHEN appointment.status = 'in_progress' THEN 0 ELSE 1 END,
            appointment.start_at ASC
          LIMIT 1
        ) note_appointment ON true
        ORDER BY full_name
        `,
        [user.id],
      );

      return result.rows.map((row) => ({
        id: row.id,
        fullName: row.full_name,
        age: row.age,
        latestAssessment: row.latest_assessment,
        lastVisitAt: row.last_visit_at,
        appointmentId: row.appointment_id,
      }));
    });
  }

  createFamilyAuthorization(
    user: RequestUser,
    input: {
      email: string;
      relationship: string;
      canViewHistory: boolean;
      canBookAppointments: boolean;
      canHandleEmergencies: boolean;
    },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const ownPatient = await client.query<{ id: string }>(
        `SELECT patient.id FROM patients patient
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1 LIMIT 1`,
        [user.id],
      );
      if (!ownPatient.rows[0]) {
        throw new BadRequestException(
          "La cuenta no tiene un perfil de paciente.",
        );
      }
      const relative = await client.query<{ id: string }>(
        `SELECT id FROM app_find_family_account($1) LIMIT 1`,
        [input.email.trim()],
      );
      const familyUser = relative.rows[0];
      if (!familyUser) {
        throw new NotFoundException(
          "No existe una cuenta activa con ese correo.",
        );
      }
      if (familyUser.id === user.id) {
        throw new BadRequestException("No puedes autorizar tu propia cuenta.");
      }

      const authorization = await client.query<{ id: string }>(
        `INSERT INTO family_authorizations(
          patient_id,family_user_id,granted_by_user_id,relationship,
          status,accepted_at
         ) VALUES($1,$2,$3,$4,'active',now())
         ON CONFLICT(patient_id,family_user_id) DO UPDATE SET
          granted_by_user_id=EXCLUDED.granted_by_user_id,
          relationship=EXCLUDED.relationship,status='active',
          accepted_at=now(),revoked_at=NULL
         RETURNING id`,
        [
          ownPatient.rows[0].id,
          familyUser.id,
          user.id,
          input.relationship.trim(),
        ],
      );
      if (!authorization.rows[0]) {
        throw new ConflictException("No se pudo actualizar la autorización.");
      }
      const authorizationId = authorization.rows[0].id;
      await client.query(
        `DELETE FROM family_authorization_permissions
         WHERE authorization_id=$1`,
        [authorizationId],
      );
      const permissions = [
        ifTrue(input.canViewHistory, "clinical_records.read"),
        ifTrue(input.canBookAppointments, "appointments.manage"),
        ifTrue(input.canHandleEmergencies, "emergencies.manage"),
      ].filter((permission): permission is string => permission != null);
      for (const permission of permissions) {
        await client.query(
          `INSERT INTO family_authorization_permissions(
            authorization_id,permission_code
           ) VALUES($1,$2) ON CONFLICT DO NOTHING`,
          [authorizationId, permission],
        );
      }
      await client.query(
        `INSERT INTO audit_events(
          actor_user_id,actor_role,patient_id,module,action,entity_type,
          entity_id,new_values
         ) VALUES($1,$2,$3,'patients','family_authorization_granted',
          'family_authorization',$4,
          jsonb_build_object('permissionCount',$5::int))`,
        [
          user.id,
          user.roleCode,
          ownPatient.rows[0].id,
          authorizationId,
          [...permissions].length,
        ],
      );
    });
  }

  updateFamilyAuthorization(
    user: RequestUser,
    id: string,
    input: {
      relationship?: string;
      canViewHistory: boolean;
      canBookAppointments: boolean;
      canHandleEmergencies: boolean;
    },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const updated = await client.query<{ id: string }>(
        `UPDATE family_authorizations family_auth SET
          relationship=COALESCE(NULLIF($3,''),relationship)
         FROM patients patient JOIN persons person ON person.id=patient.person_id
         WHERE family_auth.id=$1 AND patient.id=family_auth.patient_id
           AND person.user_id=$2 AND family_auth.revoked_at IS NULL
         RETURNING family_auth.id`,
        [id, user.id, input.relationship?.trim() ?? ""],
      );
      if (!updated.rows[0])
        throw new NotFoundException("La autorización no existe.");
      await client.query(
        `DELETE FROM family_authorization_permissions WHERE authorization_id=$1`,
        [id],
      );
      const permissions = [
        ifTrue(input.canViewHistory, "clinical_records.read"),
        ifTrue(input.canBookAppointments, "appointments.manage"),
        ifTrue(input.canHandleEmergencies, "emergencies.manage"),
      ].filter((permission): permission is string => permission != null);
      for (const permission of permissions) {
        await client.query(
          `INSERT INTO family_authorization_permissions(authorization_id,permission_code)
           VALUES($1,$2) ON CONFLICT DO NOTHING`,
          [id, permission],
        );
      }
    });
  }

  revokeFamilyAuthorization(user: RequestUser, id: string): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE family_authorizations family_auth SET
          status='inactive',revoked_at=now()
         FROM patients patient JOIN persons person ON person.id=patient.person_id
         WHERE family_auth.id=$1 AND patient.id=family_auth.patient_id
           AND person.user_id=$2 AND family_auth.revoked_at IS NULL
         RETURNING family_auth.id`,
        [id, user.id],
      );
      if (!result.rows[0])
        throw new NotFoundException("La autorización no existe.");
      await client.query(
        `DELETE FROM family_authorization_permissions WHERE authorization_id=$1`,
        [id],
      );
    });
  }

  resource(user: RequestUser, resource: PatientResource): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const tables: Record<PatientResource, string> = {
        emergency_contacts: "emergency_contacts",
        patient_guardians: "patient_guardians",
        family_authorizations: "family_authorizations",
        family_authorization_permissions: "family_authorization_permissions",
        patient_profile_completion: "patient_profile_completion",
      };
      return (await client.query(`SELECT * FROM ${tables[resource]} LIMIT 200`))
        .rows;
    });
  }
}

function ifTrue(condition: boolean, value: string): string | null {
  return condition ? value : null;
}
