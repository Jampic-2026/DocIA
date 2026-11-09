import { Injectable } from "@nestjs/common";
import { QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { AccountProfile } from "../../domain/account-profile";
import {
  PeopleResource,
  PeopleRepository,
  UpdateAccountProfile,
} from "../../domain/ports/people.repository";

type AccountProfileRow = QueryResultRow & {
  person_id: string;
  first_name: string;
  last_name: string;
  second_last_name: string | null;
  document_type: string | null;
  document_number: string | null;
  birth_date: Date | null;
  nationality: string | null;
  phone: string | null;
  email: string;
  photo_url: string | null;
  municipality: string | null;
  zone: string | null;
  address_line: string | null;
  reference: string | null;
  address_id: string | null;
};

@Injectable()
export class PostgresPeopleRepository implements PeopleRepository {
  constructor(private readonly database: DatabaseService) {}

  findAccountProfile(user: RequestUser): Promise<AccountProfile | null> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<AccountProfileRow>(
        `
        SELECT person.id AS person_id, person.first_name, person.last_name,
          person.second_last_name, person.document_type, person.document_number,
          person.birth_date, person.nationality, app_user.phone, app_user.email,
          person.photo_url, address.id AS address_id, address.municipality,
          address.zone, address.address_line, address.reference
        FROM persons person
        JOIN users app_user ON app_user.id = person.user_id
        LEFT JOIN LATERAL (
          SELECT current_address.*
          FROM addresses current_address
          WHERE current_address.person_id = person.id
            AND current_address.is_current
          ORDER BY current_address.updated_at DESC
          LIMIT 1
        ) address ON true
        WHERE person.user_id = $1
        LIMIT 1
        `,
        [user.id],
      );
      const row = result.rows[0];
      if (!row) return null;
      return {
        personId: row.person_id,
        firstName: row.first_name,
        lastName: row.last_name,
        secondLastName: row.second_last_name,
        documentType: row.document_type,
        documentNumber: row.document_number,
        birthDate: row.birth_date,
        nationality: row.nationality,
        phone: row.phone,
        email: row.email,
        photoUrl: row.photo_url,
        address: row.address_id
          ? {
              municipality: row.municipality,
              zone: row.zone,
              addressLine: row.address_line,
              reference: row.reference,
            }
          : null,
      };
    });
  }

  updateAccountProfile(
    user: RequestUser,
    input: UpdateAccountProfile,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const person = await client.query<{ id: string }>(
        `UPDATE persons SET
           first_name=COALESCE(NULLIF($2,''),first_name),
           last_name=COALESCE(NULLIF($3,''),last_name),
           second_last_name=CASE
             WHEN $4::text IS NULL THEN second_last_name ELSE NULLIF($4,'')
           END,
           updated_at=now()
         WHERE user_id=$1 RETURNING id`,
        [
          user.id,
          input.firstName?.trim() ?? null,
          input.lastName?.trim() ?? null,
          input.secondLastName?.trim() ?? null,
        ],
      );
      if (!person.rows[0]) return;

      if (input.phone != null) {
        await client.query(
          `UPDATE users SET phone=NULLIF($2,''),updated_at=now() WHERE id=$1`,
          [user.id, input.phone.trim()],
        );
      }

      const updatesAddress = [
        input.municipality,
        input.zone,
        input.addressLine,
        input.reference,
      ].some((value) => value != null);
      if (!updatesAddress) return;

      await client.query(
        `UPDATE addresses SET is_current=false,updated_at=now()
         WHERE person_id=$1 AND is_current`,
        [person.rows[0].id],
      );
      await client.query(
        `INSERT INTO addresses(person_id,municipality,zone,address_line,reference)
         VALUES($1,NULLIF($2,''),NULLIF($3,''),NULLIF($4,''),NULLIF($5,''))`,
        [
          person.rows[0].id,
          input.municipality?.trim() ?? "",
          input.zone?.trim() ?? "",
          input.addressLine?.trim() ?? "",
          input.reference?.trim() ?? "",
        ],
      );
    });
  }
  resource(user: RequestUser, resource: PeopleResource): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const queries: Record<PeopleResource, string> = {
        persons: `SELECT id,user_id AS "userId",first_name AS "firstName",last_name AS "lastName",second_last_name AS "secondLastName",birth_date AS "birthDate",sex,created_at AS "createdAt" FROM persons ORDER BY created_at DESC LIMIT 200`,
        addresses: `SELECT id,person_id AS "personId",municipality,zone,address_line AS "addressLine",reference,latitude::float8,longitude::float8,is_current AS "isCurrent",created_at AS "createdAt" FROM addresses ORDER BY created_at DESC LIMIT 200`,
      };
      return (await client.query(queries[resource])).rows;
    });
  }
}
