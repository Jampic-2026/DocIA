import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { ClinicalNote } from "../../domain/clinical-note";
import {
  ClinicalProfile,
  ClinicalProfileUpdate,
} from "../../domain/clinical-profile";
import { MedicalHistoryRecord } from "../../domain/medical-history-record";
import {
  calculateCompletion,
  completionFields,
  CompletionPolicy,
} from "../../domain/profile-completion";
import {
  ClinicalRecordsRepository,
  ClinicalResource,
} from "../../domain/ports/clinical-records.repository";
import {
  CreateVitalSign,
  VitalSignRecord,
} from "../../domain/vital-sign-record";
import {
  ClinicalDocument,
  CreateClinicalDocument,
} from "../../domain/clinical-document";
import {
  ClinicalStatement,
  ProfessionalPatientRecord,
} from "../../domain/professional-patient-record";
import {
  ClinicalCorrectionRequest,
  CreateClinicalCorrectionRequest,
} from "../../domain/clinical-correction-request";

type ProfileRow = QueryResultRow & {
  patient_id: string;
  blood_type: string | null;
  height_cm: string | null;
  weight_kg: string | null;
  insurance_provider: string | null;
  insurance_number: string | null;
  profile_notes: string | null;
  allergies: string[];
  chronic_conditions: string[];
  medications: string[];
  medical_history: string[];
  family_history: string[];
  surgical_history: string[];
  emergency_contact_name: string | null;
  emergency_contact_relationship: string | null;
  emergency_contact_phone: string | null;
  emergency_contact_email: string | null;
};

type HistoryRow = QueryResultRow & {
  id: string;
  record_type: string;
  title: string | null;
  summary: string;
  author_name: string | null;
  specialty: string | null;
  recorded_at: Date;
  validation_status: string;
};

type ClinicalNoteRow = QueryResultRow & {
  id: string;
  appointment_id: string;
  patient_id: string;
  professional_id: string;
  anamnesis: string;
  findings: string | null;
  assessment: string;
  plan: string | null;
  created_at: Date;
};

type VitalSignRow = QueryResultRow & {
  id: string;
  source: string;
  systolic_pressure: number | null;
  diastolic_pressure: number | null;
  heart_rate: number | null;
  temperature_c: string | null;
  oxygen_saturation: string | null;
  respiratory_rate: number | null;
  glucose_mg_dl: string | null;
  weight_kg: string | null;
  height_cm: string | null;
  notes: string | null;
  recorded_at: Date;
};

type ClinicalDocumentRow = QueryResultRow & {
  id: string;
  document_type: string;
  file_url: string;
  file_name: string | null;
  mime_type: string | null;
  is_restricted: boolean;
  source: string;
  validation_status: string;
  created_at: Date;
};

@Injectable()
export class PostgresClinicalRecordsRepository implements ClinicalRecordsRepository {
  completionPolicy(user: RequestUser): Promise<CompletionPolicy> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT policy FROM profile_completion_policy WHERE singleton`,
          )
        ).rows[0]?.policy ?? { rules: [], rewardEnabled: false },
    );
  }

  async saveCompletionPolicy(user: RequestUser, policy: CompletionPolicy) {
    if (
      policy.rules.some((rule) =>
        rule.field.startsWith("validated") ||
        rule.field === "professionalVitals"
          ? rule.actor !== "professional"
          : rule.actor !== "patient",
      )
    ) {
      throw new BadRequestException(
        "La validación y los signos profesionales corresponden al personal de salud; los demás campos son declarados por el paciente.",
      );
    }
    if (
      policy.rewardEnabled &&
      (!policy.rules.length ||
        !policy.benefitId ||
        !policy.campaignId ||
        !policy.threshold ||
        !policy.validUntil ||
        new Date(policy.validUntil) <= new Date())
    ) {
      throw new BadRequestException(
        "Define reglas, beneficio, campaña, umbral y vencimiento futuro antes de activar la recompensa.",
      );
    }
    await this.database.transactionAsUser(user, async (client) => {
      if (
        policy.benefitId &&
        !(
          await client.query(`SELECT id FROM benefits WHERE id=$1`, [
            policy.benefitId,
          ])
        ).rows[0]
      )
        throw new BadRequestException("El beneficio configurado no existe.");
      if (policy.benefitId)
        await client.query(
          "UPDATE benefits SET requires_profile_reward=TRUE WHERE id=$1",
          [policy.benefitId],
        );
      await client.query(
        `INSERT INTO profile_completion_policy(singleton,policy,updated_by_user_id) VALUES(TRUE,$1::jsonb,$2)
        ON CONFLICT(singleton) DO UPDATE SET policy=excluded.policy,updated_by_user_id=excluded.updated_by_user_id,updated_at=now()`,
        [JSON.stringify(policy), user.id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,new_values)
        VALUES($1,$2,'clinical_records','completion_policy_updated','profile_completion_policy',$3::jsonb)`,
        [user.id, user.roleCode, JSON.stringify(policy)],
      );
    });
  }

  completion(user: RequestUser, patientId?: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const id = await this.resolveAuthorizedPatient(client, user, patientId);
      const policy: CompletionPolicy = (
        await client.query(
          `SELECT policy FROM profile_completion_policy WHERE singleton`,
        )
      ).rows[0]?.policy ?? { rules: [], rewardEnabled: false };
      const present = (
        await client.query(
          `SELECT jsonb_object_agg(field,app_profile_field_present($1,field)) AS present FROM unnest($2::text[]) field`,
          [id, completionFields],
        )
      ).rows[0].present;
      const result = calculateCompletion(policy.rules, present);
      if (result.percent != null)
        await client.query(
          `INSERT INTO patient_profile_completion(patient_id,completion_percent,missing_fields) VALUES($1,$2,$3::jsonb)
        ON CONFLICT(patient_id) DO UPDATE SET completion_percent=excluded.completion_percent,missing_fields=excluded.missing_fields,calculated_at=now()`,
          [id, result.percent, JSON.stringify(result.missing)],
        );
      const rewarded =
        policy.rewardEnabled && result.percent != null
          ? (
              await client.query(
                `SELECT app_grant_profile_reward($1,$2) AS granted`,
                [id, result.percent],
              )
            ).rows[0].granted
          : false;
      await this.logClinicalAccess(
        client,
        user,
        id,
        "completion",
        "Consulta de completitud y pendientes",
      );
      return {
        ...result,
        patientId: id,
        rewardEnabled: policy.rewardEnabled,
        rewardAssignedNow: rewarded,
        rewards: (
          await client.query(
            `SELECT id,campaign_id AS "campaignId",benefit_id AS "benefitId",granted_at AS "grantedAt" FROM profile_reward_grants WHERE patient_id=$1`,
            [id],
          )
        ).rows,
      };
    });
  }
  constructor(private readonly database: DatabaseService) {}

  getTrends(user: RequestUser, patientId?: string, days = 90) {
    return this.database.transactionAsUser(user, async (client) => {
      const resolvedPatientId = await this.resolveAuthorizedPatient(
        client,
        user,
        patientId,
      );
      const result = await client.query(
        `SELECT id,recorded_at AS "recordedAt",source,recorded_by_user_id AS "recordedByUserId",related_appointment_id AS "appointmentId",related_emergency_id AS "emergencyId",
          systolic_pressure AS "systolicPressure",
          diastolic_pressure AS "diastolicPressure",heart_rate AS "heartRate",
          temperature_c::float8 AS "temperatureC",
          oxygen_saturation::float8 AS "oxygenSaturation",
          respiratory_rate AS "respiratoryRate",
          glucose_mg_dl::float8 AS "glucoseMgDl",
          weight_kg::float8 AS "weightKg",height_cm::float8 AS "heightCm"
         FROM vital_signs WHERE patient_id=$1
           AND recorded_at>=now()-($2::text||' days')::interval
         ORDER BY recorded_at`,
        [resolvedPatientId, days],
      );
      await this.logClinicalAccess(
        client,
        user,
        resolvedPatientId,
        "clinical_trends",
        "Consulta de tendencias clínicas",
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,
           action,entity_type,entity_id,new_values)
         VALUES($1,$2,$3,'clinical_records','clinical_trends_viewed',
           'patient',$3,jsonb_build_object('rangeDays',$4::integer,'pointCount',$5::integer))`,
        [user.id, user.roleCode, resolvedPatientId, days, result.rowCount ?? 0],
      );
      const keys = [
        "systolicPressure",
        "diastolicPressure",
        "heartRate",
        "temperatureC",
        "oxygenSaturation",
        "respiratoryRate",
        "glucoseMgDl",
        "weightKg",
        "heightCm",
      ];
      const summary = Object.fromEntries(
        keys.map((key) => {
          const values = result.rows
            .map((row) => row[key] as number | null)
            .filter((value): value is number => value != null);
          return [
            key,
            values.length
              ? {
                  minimum: Math.min(...values),
                  maximum: Math.max(...values),
                  average:
                    Math.round(
                      (values.reduce((total, value) => total + value, 0) /
                        values.length) *
                        100,
                    ) / 100,
                  latest: values.at(-1),
                }
              : null,
          ];
        }),
      );
      return {
        patientId: resolvedPatientId,
        rangeDays: days,
        points: result.rows,
        summary,
      };
    });
  }

  exportRecord(
    user: RequestUser,
    patientId?: string,
    format: "jampic" | "fhir" = "jampic",
    categories?: string[],
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const id = await this.resolveAuthorizedPatient(client, user, patientId);
      const patient = (
        await client.query(
          `SELECT patient.id,patient.blood_type,patient.insurance_provider,
            person.first_name,person.last_name,person.second_last_name,
            person.birth_date,person.sex::text
           FROM patients patient JOIN persons person ON person.id=patient.person_id
           WHERE patient.id=$1`,
          [id],
        )
      ).rows[0];
      if (!patient) throw new NotFoundException("El paciente no existe.");
      const vitals = await client.query(
        `SELECT * FROM vital_signs WHERE patient_id=$1 ORDER BY recorded_at`,
        [id],
      );
      const encounters = await client.query(
        `SELECT id,appointment_id,created_at,closed_at,assessment,plan FROM clinical_notes WHERE patient_id=$1 AND closed_at IS NOT NULL ORDER BY created_at`,
        [id],
      );
      const conditions = await client.query(
        `SELECT diagnosis.*,note.patient_id FROM diagnoses diagnosis JOIN clinical_notes note ON note.id=diagnosis.clinical_note_id WHERE note.patient_id=$1 AND note.closed_at IS NOT NULL ORDER BY diagnosis.created_at`,
        [id],
      );
      const medications = await client.query(
        `SELECT prescription.*,COALESCE(jsonb_agg(to_jsonb(item) ORDER BY item.created_at) FILTER(WHERE item.id IS NOT NULL),'[]') AS items FROM prescriptions prescription LEFT JOIN prescription_items item ON item.prescription_id=prescription.id WHERE prescription.patient_id=$1 AND prescription.status<>'draft' GROUP BY prescription.id ORDER BY prescription.created_at`,
        [id],
      );
      const records = await client.query(
        `SELECT id,record_type,title,jsonb_strip_nulls(jsonb_build_object('summary',content->>'summary','description',content->>'description',
            'diagnosis',content->>'diagnosis','diagnosisType',content->>'diagnosisType','plan',content->>'plan')) AS content,source,validation_status,recorded_at FROM clinical_records WHERE patient_id=$1 AND patient_visible AND validation_status<>'rejected' ORDER BY recorded_at`,
        [id],
      );
      await this.logClinicalAccess(
        client,
        user,
        id,
        "clinical_export",
        `Exportación clínica ${format}`,
      );
      const audit = await client.query(
        `SELECT gen_random_uuid() AS id,now() AS created_at`,
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id,new_values,fhir_audit_event,id,created_at)
         VALUES($1,$2,$3,'clinical_records','clinical_record_exported','patient',$3,
           jsonb_build_object('format',$4::text,'categories',$5::jsonb),jsonb_build_object('resourceType','AuditEvent','type',jsonb_build_object('code','export'),'recorded',now(),'outcome','0'),$6,$7)`,
        [
          user.id,
          user.roleCode,
          id,
          format,
          JSON.stringify(
            categories ?? [
              "vitalSigns",
              "encounters",
              "conditions",
              "medicationRequests",
              "clinicalRecords",
            ],
          ),
          audit.rows[0].id,
          audit.rows[0].created_at,
        ],
      );
      if (categories) {
        if (!categories.includes("vitalSigns")) vitals.rows = [];
        if (!categories.includes("encounters")) encounters.rows = [];
        if (!categories.includes("conditions")) conditions.rows = [];
        if (!categories.includes("medicationRequests")) medications.rows = [];
        if (!categories.includes("clinicalRecords")) records.rows = [];
      }
      if (format === "fhir") {
        const entries: unknown[] = [
          {
            resource: {
              resourceType: "Patient",
              id,
              name: [
                {
                  family: [patient.last_name, patient.second_last_name]
                    .filter(Boolean)
                    .join(" "),
                  given: [patient.first_name],
                },
              ],
              birthDate: patient.birth_date,
              gender:
                patient.sex === "male"
                  ? "male"
                  : patient.sex === "female"
                    ? "female"
                    : "unknown",
            },
          },
          ...vitals.rows.flatMap((vital) =>
            this.vitalToFhirObservations(id, vital),
          ),
          ...encounters.rows.map((row) => ({
            resource: {
              resourceType: "Encounter",
              id: row.id,
              status: row.closed_at ? "finished" : "in-progress",
              subject: { reference: `Patient/${id}` },
              period: { start: row.created_at, end: row.closed_at },
            },
          })),
          ...records.rows.map((row) => ({
            resource: {
              resourceType: "DocumentReference",
              id: row.id,
              status: "current",
              subject: { reference: `Patient/${id}` },
              date: row.recorded_at,
              description: row.title,
              content: [
                {
                  attachment: {
                    contentType: "application/json",
                    data: Buffer.from(JSON.stringify(row.content)).toString(
                      "base64",
                    ),
                  },
                },
              ],
            },
          })),
          ...conditions.rows.map((row) => ({
            resource: {
              resourceType: "Condition",
              id: row.id,
              clinicalStatus: { coding: [{ code: "active" }] },
              code: { text: row.diagnosis_text },
              subject: { reference: `Patient/${id}` },
              recordedDate: row.created_at,
            },
          })),
          ...medications.rows.map((row) => ({
            resource: {
              resourceType: "MedicationRequest",
              id: row.id,
              status:
                row.status === "cancelled"
                  ? "cancelled"
                  : row.status === "draft"
                    ? "draft"
                    : "active",
              intent: "order",
              subject: { reference: `Patient/${id}` },
              authoredOn: row.issued_at ?? row.created_at,
              medication: {
                concept: {
                  text:
                    row.items?.[0]?.medication_name ?? "Medicamento indicado",
                },
              },
              note: [{ text: JSON.stringify(row.items) }],
            },
          })),
          {
            resource: {
              resourceType: "AuditEvent",
              id: audit.rows[0].id,
              type: { code: "export" },
              recorded: audit.rows[0].created_at,
              outcome: { code: "0" },
              agent: [
                { who: { reference: `User/${user.id}` }, requestor: true },
              ],
              source: { observer: { reference: "Organization/DocIA" } },
              entity: [{ what: { reference: `Patient/${id}` } }],
            },
          },
        ];
        return {
          resourceType: "Bundle",
          type: "collection",
          timestamp: new Date().toISOString(),
          total: entries.length,
          entry: entries,
        };
      }
      return {
        schema: "jampic-clinical-export-v1",
        exportedAt: new Date().toISOString(),
        patient,
        vitalSigns: vitals.rows,
        encounters: encounters.rows,
        conditions: conditions.rows,
        medicationRequests: medications.rows,

        clinicalRecords: records.rows,
        auditEventId: audit.rows[0].id,
      };
    });
  }

  private async resolveAuthorizedPatient(
    client: {
      query: (
        text: string,
        values?: unknown[],
      ) => Promise<{ rows: Record<string, unknown>[] }>;
    },
    user: RequestUser,
    patientId?: string,
  ) {
    const result = patientId
      ? await client.query(
          `SELECT id FROM patients WHERE id=$1 AND app_can_read_patient(id)`,
          [patientId],
        )
      : await client.query(
          `SELECT patient.id FROM patients patient JOIN persons person ON person.id=patient.person_id WHERE person.user_id=$1`,
          [user.id],
        );
    if (!result.rows[0])
      throw new NotFoundException(
        "El paciente no existe o no tienes autorización.",
      );
    return String(result.rows[0].id);
  }

  private async logClinicalAccess(
    client: { query: (text: string, values?: unknown[]) => Promise<unknown> },
    user: RequestUser,
    patientId: string,
    section: string,
    purpose: string,
  ) {
    await client.query(
      `INSERT INTO clinical_access_logs(actor_user_id,actor_role,patient_id,section,purpose,access_granted)
       VALUES($1,$2,$3,$4,$5,TRUE)`,
      [user.id, user.roleCode, patientId, section, purpose],
    );
  }

  private vitalToFhirObservations(
    patientId: string,
    vital: Record<string, unknown>,
  ) {
    const definitions = [
      ["systolic_pressure", "8480-6", "Presión arterial sistólica", "mm[Hg]"],
      ["diastolic_pressure", "8462-4", "Presión arterial diastólica", "mm[Hg]"],
      ["heart_rate", "8867-4", "Frecuencia cardíaca", "/min"],
      ["temperature_c", "8310-5", "Temperatura corporal", "Cel"],
      ["oxygen_saturation", "2708-6", "Saturación de oxígeno", "%"],
      ["respiratory_rate", "9279-1", "Frecuencia respiratoria", "/min"],
      ["glucose_mg_dl", "2339-0", "Glucosa", "mg/dL"],
      ["weight_kg", "29463-7", "Peso corporal", "kg"],
      ["height_cm", "8302-2", "Talla", "cm"],
    ];
    return definitions
      .filter(([field]) => vital[field] != null)
      .map(([field, code, display, unit]) => ({
        resource: {
          resourceType: "Observation",
          id: `${vital.id}-${field}`,
          status: "final",
          category: [
            {
              coding: [
                {
                  system:
                    "http://terminology.hl7.org/CodeSystem/observation-category",
                  code: "vital-signs",
                },
              ],
            },
          ],
          code: { coding: [{ system: "http://loinc.org", code, display }] },
          subject: { reference: `Patient/${patientId}` },
          effectiveDateTime: vital.recorded_at,
          valueQuantity: {
            value: Number(vital[field]),
            unit,
            system: "http://unitsofmeasure.org",
            code: unit,
          },
        },
      }));
  }
  resource(user: RequestUser, resource: ClinicalResource): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const tables: Record<ClinicalResource, string> = {
        clinical_records: "clinical_records",
        clinical_record_versions: "clinical_record_versions",
        allergies: "allergies",
        medical_antecedents: "medical_antecedents",
      };
      if (!user.permissions.includes("clinical_records.manage")) {
        if (resource === "clinical_record_versions")
          throw new NotFoundException(
            "Las versiones internas requieren autorizaci\u00f3n cl\u00ednica.",
          );
        if (resource === "clinical_records")
          return (
            await client.query(
              `SELECT id,patient_id,record_type,title,jsonb_strip_nulls(jsonb_build_object('summary',content->>'summary','description',content->>'description','diagnosis',content->>'diagnosis','plan',content->>'plan')) AS content,source,validation_status,recorded_at FROM clinical_records WHERE patient_visible AND validation_status<>'rejected' ORDER BY recorded_at DESC LIMIT 200`,
            )
          ).rows;
      }
      return (await client.query(`SELECT * FROM ${tables[resource]} LIMIT 200`))
        .rows;
    });
  }

  getOwnProfile(
    user: RequestUser,
    patientId?: string,
  ): Promise<ClinicalProfile | null> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<ProfileRow>(
        `
        SELECT patient.id AS patient_id, patient.blood_type,
          COALESCE(latest_vitals.height_cm, patient.height_cm) AS height_cm,
          COALESCE(latest_vitals.weight_kg, patient.weight_kg) AS weight_kg,
          patient.insurance_provider, patient.insurance_number,
          patient.profile_notes,
          COALESCE((
            SELECT array_agg(allergy.substance ORDER BY allergy.substance)
            FROM allergies allergy
            WHERE allergy.patient_id = patient.id AND allergy.is_active
          ), ARRAY[]::varchar[]) AS allergies,
          COALESCE((
            SELECT array_agg(antecedent.description ORDER BY antecedent.description)
            FROM medical_antecedents antecedent
            WHERE antecedent.patient_id = patient.id AND antecedent.is_active
              AND antecedent.antecedent_type = 'chronic_condition'
          ), ARRAY[]::text[]) AS chronic_conditions,
          COALESCE((
            SELECT array_agg(antecedent.description ORDER BY antecedent.description)
            FROM medical_antecedents antecedent
            WHERE antecedent.patient_id = patient.id AND antecedent.is_active
              AND antecedent.antecedent_type = 'medication'
          ), ARRAY[]::text[]) AS medications,
          COALESCE((
            SELECT array_agg(antecedent.description ORDER BY antecedent.description)
            FROM medical_antecedents antecedent
            WHERE antecedent.patient_id = patient.id AND antecedent.is_active
              AND antecedent.antecedent_type = 'pathological'
          ), ARRAY[]::text[]) AS medical_history,
          COALESCE((
            SELECT array_agg(antecedent.description ORDER BY antecedent.description)
            FROM medical_antecedents antecedent
            WHERE antecedent.patient_id = patient.id AND antecedent.is_active
              AND antecedent.antecedent_type = 'family'
          ), ARRAY[]::text[]) AS family_history,
          COALESCE((
            SELECT array_agg(antecedent.description ORDER BY antecedent.description)
            FROM medical_antecedents antecedent
            WHERE antecedent.patient_id = patient.id AND antecedent.is_active
              AND antecedent.antecedent_type = 'surgical'
          ), ARRAY[]::text[]) AS surgical_history,
          (
            SELECT contact.full_name
            FROM emergency_contacts contact
            WHERE contact.patient_id = patient.id AND contact.is_active
            ORDER BY contact.is_primary DESC, contact.created_at ASC
            LIMIT 1
          ) AS emergency_contact_name,
          (
            SELECT contact.relationship FROM emergency_contacts contact
            WHERE contact.patient_id = patient.id AND contact.is_active
            ORDER BY contact.is_primary DESC, contact.created_at ASC LIMIT 1
          ) AS emergency_contact_relationship,
          (
            SELECT contact.phone FROM emergency_contacts contact
            WHERE contact.patient_id = patient.id AND contact.is_active
            ORDER BY contact.is_primary DESC, contact.created_at ASC LIMIT 1
          ) AS emergency_contact_phone,
          (
            SELECT contact.email::text FROM emergency_contacts contact
            WHERE contact.patient_id = patient.id AND contact.is_active
            ORDER BY contact.is_primary DESC, contact.created_at ASC LIMIT 1
          ) AS emergency_contact_email
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        LEFT JOIN LATERAL (
          SELECT vital.height_cm, vital.weight_kg
          FROM vital_signs vital
          WHERE vital.patient_id = patient.id
          ORDER BY vital.recorded_at DESC
          LIMIT 1
        ) latest_vitals ON true
        WHERE ($2::uuid IS NULL AND person.user_id = $1) OR (patient.id=$2 AND app_can_patient_action(patient.id,'clinical_records.read'))
        LIMIT 1
        `,
        [user.id, patientId ?? null],
      );
      let row = result.rows[0];
      if (!row && !patientId) {
        const personRes = await client.query<{ id: string }>(
          `SELECT id FROM persons WHERE user_id = $1 LIMIT 1`,
          [user.id],
        );
        if (personRes.rows[0]) {
          await client.query(
            `INSERT INTO patients (person_id, profile_notes)
             VALUES ($1, 'Perfil clínico inicial.')
             ON CONFLICT (person_id) DO NOTHING`,
            [personRes.rows[0].id],
          );
          const retry = await client.query<ProfileRow>(
            `
            SELECT patient.id AS patient_id, patient.blood_type,
              COALESCE(latest_vitals.height_cm, patient.height_cm) AS height_cm,
              COALESCE(latest_vitals.weight_kg, patient.weight_kg) AS weight_kg,
              patient.insurance_provider, patient.insurance_number,
              patient.profile_notes,
              ARRAY[]::varchar[] AS allergies,
              ARRAY[]::text[] AS chronic_conditions,
              ARRAY[]::text[] AS medications,
              ARRAY[]::text[] AS medical_history,
              ARRAY[]::text[] AS family_history,
              ARRAY[]::text[] AS surgical_history,
              NULL::text AS emergency_contact_name,
              NULL::text AS emergency_contact_relationship,
              NULL::text AS emergency_contact_phone,
              NULL::text AS emergency_contact_email
            FROM patients patient
            JOIN persons person ON person.id = patient.person_id
            LEFT JOIN LATERAL (
              SELECT vital.height_cm, vital.weight_kg
              FROM vital_signs vital
              WHERE vital.patient_id = patient.id
              ORDER BY vital.recorded_at DESC
              LIMIT 1
            ) latest_vitals ON true
            WHERE person.user_id = $1
            LIMIT 1
            `,
            [user.id],
          );
          row = retry.rows[0];
        }
      }
      if (!row) return null;
      return {
        patientId: row.patient_id,
        bloodType: row.blood_type,
        heightCm: row.height_cm == null ? null : Number(row.height_cm),
        weightKg: row.weight_kg == null ? null : Number(row.weight_kg),
        insuranceProvider: row.insurance_provider,
        insuranceNumber: row.insurance_number,
        profileNotes: row.profile_notes,
        allergies: row.allergies,
        chronicConditions: row.chronic_conditions,
        currentMedications: row.medications,
        medicalHistory: row.medical_history,
        familyHistory: row.family_history,
        surgicalHistory: row.surgical_history,
        emergencyContactName: row.emergency_contact_name,
        emergencyContactRelationship: row.emergency_contact_relationship,
        emergencyContactPhone: row.emergency_contact_phone,
        emergencyContactEmail: row.emergency_contact_email,
      };
    });
  }

  updateOwnProfile(
    user: RequestUser,
    input: ClinicalProfileUpdate,
    patientId?: string,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const patientResult = patientId
        ? await client.query<{ id: string }>(
            `SELECT id FROM patients WHERE id=$1 AND app_can_patient_action(id,'patients.manage') FOR UPDATE`,
            [patientId],
          )
        : await client.query<{ id: string }>(
            `SELECT patient.id FROM patients patient
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1 LIMIT 1 FOR UPDATE OF patient`,
            [user.id],
          );
      let patient = patientResult.rows[0];
      if (!patient && !patientId) {
        const personRes = await client.query<{ id: string }>(
          `SELECT id FROM persons WHERE user_id = $1 LIMIT 1`,
          [user.id],
        );
        if (personRes.rows[0]) {
          const inserted = await client.query<{ id: string }>(
            `INSERT INTO patients (person_id, profile_notes)
             VALUES ($1, 'Perfil clínico.')
             ON CONFLICT (person_id) DO UPDATE SET updated_at = now()
             RETURNING id`,
            [personRes.rows[0].id],
          );
          patient = inserted.rows[0];
        }
      }
      if (!patient) {
        throw new NotFoundException(
          "La cuenta no tiene un perfil de paciente.",
        );
      }

      await client.query(
        `UPDATE patients SET
          blood_type=COALESCE(NULLIF($2,''),blood_type),
          height_cm=COALESCE($3,height_cm),weight_kg=COALESCE($4,weight_kg),
          insurance_provider=CASE WHEN $5::boolean THEN NULLIF($6,'') ELSE insurance_provider END,
          insurance_number=CASE WHEN $7::boolean THEN NULLIF($8,'') ELSE insurance_number END,
          profile_notes=CASE WHEN $9::boolean THEN NULLIF($10,'') ELSE profile_notes END,
          updated_at=now() WHERE id=$1`,
        [
          patient.id,
          input.bloodType ?? "",
          input.heightCm ?? null,
          input.weightKg ?? null,
          input.insuranceProvider !== undefined,
          input.insuranceProvider?.trim() ?? "",
          input.insuranceNumber !== undefined,
          input.insuranceNumber?.trim() ?? "",
          input.profileNotes !== undefined,
          input.profileNotes?.trim() ?? "",
        ],
      );

      if (input.allergies !== undefined) {
        await client.query(
          `UPDATE allergies SET is_active=false,updated_at=now()
           WHERE patient_id=$1 AND is_active AND author_user_id=$2 AND validation_status IN ('self_declared','pending_validation')`,
          [patient.id, user.id],
        );
        for (const substance of cleanValues(input.allergies)) {
          await client.query(
            `INSERT INTO allergies(
              patient_id,substance,author_user_id,validation_status
             ) SELECT $1::uuid,$2::varchar,$3::uuid,'self_declared'::validation_status WHERE NOT EXISTS(SELECT 1 FROM allergies WHERE patient_id=$1::uuid AND is_active AND lower(substance)=lower($2::text))`,
            [patient.id, substance, user.id],
          );
        }
      }

      const antecedents: Array<[string, string[] | undefined]> = [
        ["chronic_condition", input.chronicConditions],
        ["medication", input.currentMedications],
        ["pathological", input.medicalHistory],
        ["family", input.familyHistory],
        ["surgical", input.surgicalHistory],
      ];
      for (const [type, values] of antecedents) {
        if (values === undefined) continue;
        await client.query(
          `UPDATE medical_antecedents SET is_active=false,updated_at=now()
           WHERE patient_id=$1 AND antecedent_type=$2 AND is_active AND author_user_id=$3 AND validation_status IN ('self_declared','pending_validation')`,
          [patient.id, type, user.id],
        );
        for (const description of cleanValues(values)) {
          await client.query(
            `INSERT INTO medical_antecedents(
              patient_id,antecedent_type,description,author_user_id,
              validation_status
             ) SELECT $1::uuid,$2::varchar,$3::text,$4::uuid,'self_declared'::validation_status WHERE NOT EXISTS(SELECT 1 FROM medical_antecedents WHERE patient_id=$1::uuid AND antecedent_type=$2::varchar AND is_active AND lower(description)=lower($3::text))`,
            [patient.id, type, description, user.id],
          );
        }
      }

      if (
        input.emergencyContactName !== undefined ||
        input.emergencyContactPhone !== undefined
      ) {
        await client.query(
          `UPDATE emergency_contacts SET is_active=false,updated_at=now()
           WHERE patient_id=$1 AND is_active`,
          [patient.id],
        );
        const name = input.emergencyContactName?.trim() ?? "";
        const phone = input.emergencyContactPhone?.trim() ?? "";
        if (name && phone) {
          await client.query(
            `INSERT INTO emergency_contacts(
              patient_id,full_name,relationship,phone,email,is_primary
             ) VALUES($1,$2,NULLIF($3,''),$4,NULLIF($5,'')::citext,true)`,
            [
              patient.id,
              name,
              input.emergencyContactRelationship?.trim() ?? "",
              phone,
              input.emergencyContactEmail?.trim() ?? "",
            ],
          );
        }
      }

      await client.query(
        `INSERT INTO audit_events(
          actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id
         ) VALUES($1,$2,$3,'clinical_records','profile_updated','patient',$3)`,
        [user.id, user.roleCode, patient.id],
      );
    });
  }

  listOwnHistory(
    user: RequestUser,
    patientId?: string,
  ): Promise<MedicalHistoryRecord[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const resolvedPatientId = await this.resolveAuthorizedPatient(
        client,
        user,
        patientId,
      );
      await this.logClinicalAccess(
        client,
        user,
        resolvedPatientId,
        "history",
        "Consulta de historial",
      );
      const result = await client.query<HistoryRow>(
        `
        SELECT record.id, record.record_type, record.title,
          COALESCE(
            NULLIF(record.content->>'summary', ''),
            NULLIF(record.content->>'description', ''),
            'Registro clínico'
          ) AS summary,
          concat_ws(' ', author.first_name, author.last_name, author.second_last_name) AS author_name,
          specialty.name AS specialty, record.recorded_at, record.validation_status
        FROM clinical_records record
        JOIN patients patient ON patient.id = record.patient_id
        JOIN persons patient_person ON patient_person.id = patient.person_id
        LEFT JOIN persons author ON author.user_id = record.author_user_id
        LEFT JOIN professionals professional ON professional.user_id = record.author_user_id
        LEFT JOIN professional_specialties professional_specialty
          ON professional_specialty.professional_id = professional.id
         AND professional_specialty.is_primary
        LEFT JOIN specialties specialty ON specialty.id = professional_specialty.specialty_id
        WHERE record.patient_id = $1 AND record.patient_visible AND record.validation_status<>'rejected'
        ORDER BY record.recorded_at DESC
        `,
        [resolvedPatientId],
      );
      return result.rows.map((row) => ({
        id: row.id,
        type: row.record_type,
        title: row.title ?? "Registro clínico",
        summary: row.summary,
        authorName: row.author_name || null,
        specialty: row.specialty,
        recordedAt: row.recorded_at,
        validationStatus: row.validation_status,
      }));
    });
  }

  listOwnVitalSigns(user: RequestUser): Promise<VitalSignRecord[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<VitalSignRow>(
        `SELECT vital.id,vital.source,vital.systolic_pressure,
          vital.diastolic_pressure,vital.heart_rate,vital.temperature_c,
          vital.oxygen_saturation,vital.respiratory_rate,vital.glucose_mg_dl,
          vital.weight_kg,vital.height_cm,vital.notes,vital.recorded_at
         FROM vital_signs vital
         JOIN patients patient ON patient.id=vital.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1
         ORDER BY vital.recorded_at DESC LIMIT 100`,
        [user.id],
      );
      return result.rows.map(mapVitalSign);
    });
  }

  createOwnVitalSign(
    user: RequestUser,
    input: CreateVitalSign,
  ): Promise<VitalSignRecord> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<VitalSignRow>(
        `INSERT INTO vital_signs(
          patient_id,recorded_by_user_id,source,systolic_pressure,
          diastolic_pressure,heart_rate,temperature_c,oxygen_saturation,
          respiratory_rate,glucose_mg_dl,weight_kg,height_cm,notes
         )
         SELECT patient.id,$1,'patient',$2,$3,$4,$5,$6,$7,$8,$9,$10,$11
         FROM patients patient JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1
         RETURNING id,source,systolic_pressure,diastolic_pressure,heart_rate,
          temperature_c,oxygen_saturation,respiratory_rate,glucose_mg_dl,
          weight_kg,height_cm,notes,recorded_at`,
        [
          user.id,
          input.systolicPressure,
          input.diastolicPressure,
          input.heartRate,
          input.temperatureC,
          input.oxygenSaturation,
          input.respiratoryRate,
          input.glucoseMgDl,
          input.weightKg,
          input.heightCm,
          input.notes,
        ],
      );
      const row = result.rows[0];
      if (!row)
        throw new NotFoundException(
          "La cuenta no tiene un perfil de paciente.",
        );
      await client.query(
        `INSERT INTO audit_events(
          actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id
         ) SELECT $1,$2,patient.id,'clinical_records','vital_sign_created',
          'vital_sign',$3 FROM patients patient
          JOIN persons person ON person.id=patient.person_id
          WHERE person.user_id=$1`,
        [user.id, user.roleCode, row.id],
      );
      return mapVitalSign(row);
    });
  }

  createProfessionalVitalSign(
    user: RequestUser,
    patientId: string,
    input: CreateVitalSign & { appointmentId?: string; emergencyId?: string },
  ): Promise<VitalSignRecord> {
    return this.database.transactionAsUser(user, async (client) => {
      // Lock the care context so closure/reassignment cannot race the observation.
      if (input.emergencyId)
        await client.query(
          `SELECT id FROM emergency_events WHERE id=$1 FOR UPDATE`,
          [input.emergencyId],
        );
      if (input.appointmentId)
        await client.query(
          `SELECT id FROM appointments WHERE id=$1 FOR UPDATE`,
          [input.appointmentId],
        );
      const authorization = await client.query(
        `SELECT app_can_record_vitals($1,$2,$3) AS allowed`,
        [patientId, input.appointmentId ?? null, input.emergencyId ?? null],
      );
      if (!authorization.rows[0]?.allowed)
        throw new BadRequestException(
          "No tienes una atención activa y autorizada para este paciente.",
        );
      const result = await client.query<VitalSignRow>(
        `INSERT INTO vital_signs(patient_id,recorded_by_user_id,source,
        related_appointment_id,related_emergency_id,systolic_pressure,diastolic_pressure,heart_rate,temperature_c,
        oxygen_saturation,respiratory_rate,glucose_mg_dl,weight_kg,height_cm,notes)
        VALUES($1,$2,'professional',$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
        RETURNING id,source,systolic_pressure,diastolic_pressure,heart_rate,temperature_c,oxygen_saturation,
          respiratory_rate,glucose_mg_dl,weight_kg,height_cm,notes,recorded_at`,
        [
          patientId,
          user.id,
          input.appointmentId ?? null,
          input.emergencyId ?? null,
          input.systolicPressure,
          input.diastolicPressure,
          input.heartRate,
          input.temperatureC,
          input.oxygenSaturation,
          input.respiratoryRate,
          input.glucoseMgDl,
          input.weightKg,
          input.heightCm,
          input.notes,
        ],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id,new_values)
        VALUES($1,$2,$3,'clinical_records','professional_vital_sign_created','vital_sign',$4,$5::jsonb)`,
        [
          user.id,
          user.roleCode,
          patientId,
          result.rows[0].id,
          JSON.stringify({
            appointmentId: input.appointmentId,
            emergencyId: input.emergencyId,
          }),
        ],
      );
      return mapVitalSign(result.rows[0]);
    });
  }

  listOwnDocuments(user: RequestUser): Promise<ClinicalDocument[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<ClinicalDocumentRow>(
        `SELECT document.id,document.document_type,document.file_url,
          document.file_name,document.mime_type,document.is_restricted,
          document.source,document.validation_status,document.created_at
         FROM clinical_documents document
         JOIN patients patient ON patient.id=document.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1 ORDER BY document.created_at DESC`,
        [user.id],
      );
      return result.rows.map(mapClinicalDocument);
    });
  }

  createOwnDocument(
    user: RequestUser,
    input: CreateClinicalDocument,
  ): Promise<ClinicalDocument> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<ClinicalDocumentRow>(
        `INSERT INTO clinical_documents(
          patient_id,uploaded_by_user_id,document_type,file_url,file_name,
          mime_type,is_restricted,source,validation_status
         )
         SELECT patient.id,$1,$2,$3,NULLIF($4,''),NULLIF($5,''),$6,
          'external','pending_validation'
         FROM patients patient JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1
         RETURNING id,document_type,file_url,file_name,mime_type,is_restricted,
          source,validation_status,created_at`,
        [
          user.id,
          input.documentType.trim(),
          input.fileUrl.trim(),
          input.fileName?.trim() ?? "",
          input.mimeType?.trim() ?? "",
          input.isRestricted ?? false,
        ],
      );
      const row = result.rows[0];
      if (!row)
        throw new NotFoundException(
          "La cuenta no tiene un perfil de paciente.",
        );
      await client.query(
        `INSERT INTO audit_events(
          actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id
         ) SELECT $1,$2,patient.id,'clinical_records','document_linked',
          'clinical_document',$3 FROM patients patient
          JOIN persons person ON person.id=patient.person_id
          WHERE person.user_id=$1`,
        [user.id, user.roleCode, row.id],
      );
      return mapClinicalDocument(row);
    });
  }

  getProfessionalPatientRecord(
    user: RequestUser,
    patientId: string,
  ): Promise<ProfessionalPatientRecord | null> {
    return this.database.transactionAsUser(user, async (client) => {
      const profile = await client.query<{
        patient_id: string;
        full_name: string;
        birth_date: Date | null;
        blood_type: string | null;
        height_cm: string | null;
        weight_kg: string | null;
        insurance_provider: string | null;
        insurance_number: string | null;
        profile_notes: string | null;
        emergency_contact: string | null;
      }>(
        `SELECT patient.id AS patient_id,
          concat_ws(' ',person.first_name,person.last_name,person.second_last_name) AS full_name,
          person.birth_date,patient.blood_type,
          COALESCE(latest.height_cm,patient.height_cm) AS height_cm,
          COALESCE(latest.weight_kg,patient.weight_kg) AS weight_kg,
          patient.insurance_provider,patient.insurance_number,patient.profile_notes,
          (SELECT concat_ws(' · ',contact.full_name,contact.relationship,contact.phone)
           FROM emergency_contacts contact WHERE contact.patient_id=patient.id
             AND contact.is_active ORDER BY contact.is_primary DESC,contact.created_at LIMIT 1
          ) AS emergency_contact
         FROM patients patient JOIN persons person ON person.id=patient.person_id
         LEFT JOIN LATERAL(
           SELECT vital.height_cm,vital.weight_kg FROM vital_signs vital
           WHERE vital.patient_id=patient.id ORDER BY vital.recorded_at DESC LIMIT 1
         ) latest ON true
         WHERE patient.id=$1 AND app_can_read_patient(patient.id) LIMIT 1`,
        [patientId],
      );
      const patient = profile.rows[0];
      if (!patient) return null;

      const statements = await client.query<ClinicalStatement>(
        `SELECT allergy.id,'allergy'::text AS type,'allergy'::text AS category,
          allergy.substance AS description,allergy.reaction AS detail,
          allergy.validation_status::text AS "validationStatus"
         FROM allergies allergy WHERE allergy.patient_id=$1 AND allergy.is_active
         UNION ALL
         SELECT antecedent.id,'antecedent',antecedent.antecedent_type,
          antecedent.description,antecedent.relation,
          antecedent.validation_status::text
         FROM medical_antecedents antecedent
         WHERE antecedent.patient_id=$1 AND antecedent.is_active
         ORDER BY category,description`,
        [patientId],
      );
      const vitals = await client.query<VitalSignRow>(
        `SELECT id,source,systolic_pressure,diastolic_pressure,heart_rate,
          temperature_c,oxygen_saturation,respiratory_rate,glucose_mg_dl,
          weight_kg,height_cm,notes,recorded_at FROM vital_signs
         WHERE patient_id=$1 ORDER BY recorded_at DESC LIMIT 30`,
        [patientId],
      );
      const documents = await client.query<ClinicalDocumentRow>(
        `SELECT id,document_type,file_url,file_name,mime_type,is_restricted,
          source,validation_status,created_at FROM clinical_documents
         WHERE patient_id=$1 ORDER BY created_at DESC`,
        [patientId],
      );
      return {
        patientId: patient.patient_id,
        fullName: patient.full_name,
        birthDate: patient.birth_date,
        bloodType: patient.blood_type,
        heightCm: numberOrNull(patient.height_cm),
        weightKg: numberOrNull(patient.weight_kg),
        insuranceProvider: patient.insurance_provider,
        insuranceNumber: patient.insurance_number,
        profileNotes: patient.profile_notes,
        emergencyContact: patient.emergency_contact,
        statements: statements.rows,
        vitalSigns: vitals.rows.map(mapVitalSign),
        documents: documents.rows.map(mapClinicalDocument),
      };
    });
  }

  validateStatement(
    user: RequestUser,
    patientId: string,
    statementType: "allergy" | "antecedent",
    statementId: string,
    status: "validated" | "rejected",
    notes?: string,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const table =
        statementType === "allergy" ? "allergies" : "medical_antecedents";
      const result = await client.query<{ id: string }>(
        `UPDATE ${table} SET validation_status=$3,updated_at=now()
         WHERE id=$1 AND patient_id=$2 AND is_active RETURNING id`,
        [statementId, patientId, status],
      );
      if (!result.rows[0]) {
        throw new NotFoundException(
          "El registro no existe o no está autorizado.",
        );
      }
      await this.auditValidation(
        client,
        user,
        patientId,
        statementType,
        statementId,
        status,
        notes,
      );
    });
  }

  validateDocument(
    user: RequestUser,
    patientId: string,
    documentId: string,
    status: "validated" | "rejected",
    notes?: string,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{ id: string }>(
        `UPDATE clinical_documents document SET validation_status=$3,
          validated_by_professional_id=professional.id,
          validated_at=CASE WHEN $3='validated' THEN now() ELSE NULL END
         FROM professionals professional
         WHERE document.id=$1 AND document.patient_id=$2
           AND professional.user_id=$4 RETURNING document.id`,
        [documentId, patientId, status, user.id],
      );
      if (!result.rows[0]) {
        throw new NotFoundException(
          "El documento no existe o no está autorizado.",
        );
      }
      await this.auditValidation(
        client,
        user,
        patientId,
        "clinical_document",
        documentId,
        status,
        notes,
      );
    });
  }

  listCorrectionRequests(
    user: RequestUser,
    operational: boolean,
  ): Promise<ClinicalCorrectionRequest[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{
        id: string;
        patient_id: string;
        patient_name: string;
        entity_type: string;
        entity_id: string;
        record_title: string | null;
        requested_change: string;
        reason: string;
        status: string;
        resolution: string | null;
        created_at: Date;
        resolved_at: Date | null;
      }>(
        `SELECT request.id,request.patient_id,
          concat_ws(' ',person.first_name,person.last_name,person.second_last_name) AS patient_name,
          request.entity_type,request.entity_id,record.title AS record_title,
          request.requested_change,request.reason,request.status,
          request.resolution,request.created_at,request.resolved_at
         FROM clinical_correction_requests request
         JOIN patients patient ON patient.id=request.patient_id
         JOIN persons person ON person.id=patient.person_id
         LEFT JOIN clinical_records record
           ON request.entity_type='clinical_record' AND record.id=request.entity_id
         WHERE $2::boolean OR request.requested_by_user_id=$1
         ORDER BY CASE WHEN request.status='pending' THEN 0 ELSE 1 END,
          request.created_at DESC`,
        [user.id, operational],
      );
      return result.rows.map((row) => ({
        id: row.id,
        patientId: row.patient_id,
        patientName: row.patient_name,
        entityType: row.entity_type,
        entityId: row.entity_id,
        recordTitle: row.record_title,
        requestedChange: row.requested_change,
        reason: row.reason,
        status: row.status,
        resolution: row.resolution,
        createdAt: row.created_at,
        resolvedAt: row.resolved_at,
      }));
    });
  }

  createCorrectionRequest(
    user: RequestUser,
    input: CreateClinicalCorrectionRequest,
  ): Promise<ClinicalCorrectionRequest> {
    return this.database.transactionAsUser(user, async (client) => {
      const target = await client.query<{
        record_id: string;
        patient_id: string;
        title: string | null;
        patient_name: string;
      }>(
        `SELECT record.id AS record_id,record.patient_id,record.title,
          concat_ws(' ',person.first_name,person.last_name,person.second_last_name) AS patient_name
         FROM clinical_records record
         JOIN patients patient ON patient.id=record.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE record.id=$1 AND person.user_id=$2 LIMIT 1`,
        [input.clinicalRecordId, user.id],
      );
      const record = target.rows[0];
      if (!record) {
        throw new NotFoundException("El registro clínico no existe.");
      }
      const duplicate = await client.query(
        `SELECT 1 FROM clinical_correction_requests
         WHERE entity_type='clinical_record' AND entity_id=$1
           AND requested_by_user_id=$2 AND status='pending' LIMIT 1`,
        [record.record_id, user.id],
      );
      if (duplicate.rows[0]) {
        throw new BadRequestException(
          "Ya existe una solicitud pendiente para este registro.",
        );
      }
      const result = await client.query<{
        id: string;
        created_at: Date;
      }>(
        `INSERT INTO clinical_correction_requests(
          patient_id,requested_by_user_id,entity_type,entity_id,
          requested_change,reason
         ) VALUES($1,$2,'clinical_record',$3,$4,$5)
         RETURNING id,created_at`,
        [
          record.patient_id,
          user.id,
          record.record_id,
          input.requestedChange,
          input.reason,
        ],
      );
      return {
        id: result.rows[0].id,
        patientId: record.patient_id,
        patientName: record.patient_name,
        entityType: "clinical_record",
        entityId: record.record_id,
        recordTitle: record.title,
        requestedChange: input.requestedChange,
        reason: input.reason,
        status: "pending",
        resolution: null,
        createdAt: result.rows[0].created_at,
        resolvedAt: null,
      };
    });
  }

  resolveCorrectionRequest(
    user: RequestUser,
    requestId: string,
    status: "accepted" | "rejected",
    resolution: string,
  ): Promise<string> {
    return this.database.transactionAsUser(user, async (client) => {
      const requestResult = await client.query<{
        patient_id: string;
        entity_type: string;
        entity_id: string;
        requested_change: string;
      }>(
        `SELECT patient_id,entity_type,entity_id,requested_change
         FROM clinical_correction_requests
         WHERE id=$1 AND status='pending' FOR UPDATE`,
        [requestId],
      );
      const request = requestResult.rows[0];
      if (!request) {
        throw new NotFoundException(
          "La solicitud no existe o ya fue resuelta.",
        );
      }
      if (status === "accepted" && request.entity_type === "clinical_record") {
        const record = await client.query<{
          id: string;
          content: unknown;
          version: number;
          title: string | null;
          validation_status: string;
        }>(
          `SELECT id,content,version,title,validation_status
           FROM clinical_records WHERE id=$1 AND patient_id=$2 FOR UPDATE`,
          [request.entity_id, request.patient_id],
        );
        const current = record.rows[0];
        if (!current)
          throw new NotFoundException("El registro clínico ya no existe.");
        await client.query(
          `INSERT INTO clinical_record_versions(
            clinical_record_id,version_number,snapshot,changed_by_user_id,
            change_reason
           ) VALUES($1,$2,jsonb_build_object(
             'title',$3::text,'content',$4::jsonb,
             'validationStatus',$5::text
           ),$6,$7)`,
          [
            current.id,
            current.version,
            current.title ?? "",
            JSON.stringify(current.content),
            current.validation_status,
            user.id,
            resolution,
          ],
        );
        await client.query(
          `UPDATE clinical_records SET
            content=jsonb_set(content,'{summary}',to_jsonb($2::text),true),
            validation_status='corrected',version=version+1,
            change_reason=$3 WHERE id=$1`,
          [current.id, request.requested_change, resolution],
        );
      }
      await client.query(
        `UPDATE clinical_correction_requests SET status=$2,
          resolved_by_user_id=$3,resolution=$4,resolved_at=now()
         WHERE id=$1`,
        [requestId, status, user.id, resolution],
      );
      await this.auditValidation(
        client,
        user,
        request.patient_id,
        "clinical_correction_request",
        requestId,
        status,
        resolution,
      );
      return request.patient_id;
    });
  }

  private async auditValidation(
    client: { query: (text: string, values?: unknown[]) => Promise<unknown> },
    user: RequestUser,
    patientId: string,
    entityType: string,
    entityId: string,
    status: string,
    notes?: string,
  ) {
    await client.query(
      `INSERT INTO audit_events(
        actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id,new_values
       ) VALUES($1,$2,$3,'clinical_records','validation_updated',$4,$5,
        jsonb_build_object('status',$6::text,'notes',$7::text))`,
      [
        user.id,
        user.roleCode,
        patientId,
        entityType,
        entityId,
        status,
        notes ?? "",
      ],
    );
  }

  createNote(
    user: RequestUser,
    input: {
      appointmentId: string;
      patientId: string;
      subjective: string;
      objective?: string;
      assessment: string;
      plan?: string;
    },
  ): Promise<ClinicalNote> {
    return this.database.transactionAsUser(user, async (client) => {
      const appointment = await client.query<{
        patient_id: string;
        professional_id: string;
        status: string;
        start_at: Date;
      }>(
        `SELECT appointment.patient_id, appointment.professional_id,
          appointment.status,appointment.start_at
         FROM appointments appointment
         JOIN professionals professional
           ON professional.id = appointment.professional_id
         WHERE appointment.id = $1 AND professional.user_id = $2
         LIMIT 1`,
        [input.appointmentId, user.id],
      );
      const authorizedAppointment = appointment.rows[0];
      if (!authorizedAppointment) {
        throw new NotFoundException(
          "La cita no existe o no está asignada al profesional.",
        );
      }
      if (authorizedAppointment.patient_id !== input.patientId) {
        throw new BadRequestException(
          "El paciente no corresponde a la cita seleccionada.",
        );
      }
      if (
        !["scheduled", "confirmed", "rescheduled", "in_progress"].includes(
          authorizedAppointment.status,
        )
      ) {
        throw new BadRequestException(
          "La cita no permite registrar una nota clínica.",
        );
      }
      if (
        authorizedAppointment.start_at.getTime() >
        Date.now() + 30 * 60 * 1000
      ) {
        throw new BadRequestException(
          "La atención solo puede iniciarse desde 30 minutos antes de la cita.",
        );
      }
      if (authorizedAppointment.status !== "in_progress") {
        await client.query(
          `UPDATE appointments SET status='in_progress',updated_at=now() WHERE id=$1`,
          [input.appointmentId],
        );
        await client.query(
          `INSERT INTO appointment_status_history(
            appointment_id,old_status,new_status,changed_by_user_id,reason
           ) VALUES($1,$2,'in_progress',$3,'Atención iniciada por el profesional')`,
          [input.appointmentId, authorizedAppointment.status, user.id],
        );
      }

      const result = await client.query<ClinicalNoteRow>(
        `INSERT INTO clinical_notes (
           appointment_id, patient_id, professional_id, anamnesis,
           findings, assessment, plan
         )
         VALUES ($1, $2, $3, $4, NULLIF($5, ''), $6, NULLIF($7, ''))
         RETURNING id, appointment_id, patient_id, professional_id, anamnesis,
           findings, assessment, plan, created_at`,
        [
          input.appointmentId,
          input.patientId,
          authorizedAppointment.professional_id,
          input.subjective.trim(),
          input.objective?.trim() ?? "",
          input.assessment.trim(),
          input.plan?.trim() ?? "",
        ],
      );
      const row = result.rows[0];

      await client.query(
        `INSERT INTO clinical_records (
           patient_id, record_type, title, content, source, validation_status,
           author_user_id, author_role, related_appointment_id
         )
         VALUES (
           $1, 'note', 'Nota clínica',
           jsonb_build_object(
             'summary', $2::text, 'subjective', $3::text,
             'objective', $4::text, 'plan', $5::text,
             'clinicalNoteId', $6::text
           ),
           'professional', 'validated', $7, $8, $9
         )`,
        [
          input.patientId,
          input.assessment.trim(),
          input.subjective.trim(),
          input.objective?.trim() ?? "",
          input.plan?.trim() ?? "",
          row.id,
          user.id,
          user.roleCode,
          input.appointmentId,
        ],
      );

      return {
        id: row.id,
        appointmentId: row.appointment_id,
        patientId: row.patient_id,
        professionalId: row.professional_id,
        subjective: row.anamnesis,
        objective: row.findings,
        assessment: row.assessment,
        plan: row.plan,
        createdAt: row.created_at,
      };
    });
  }

  closeConsultation(
    user: RequestUser,
    input: {
      appointmentId: string;
      patientId: string;
      subjective: string;
      objective?: string;
      assessment: string;
      plan?: string;
      diagnosis: string;
      diagnosisType: string;
      treatment?: string;
      treatmentInstructions?: string;
      followupDueAt?: Date;
      followupInstructions?: string;
    },
  ): Promise<ClinicalNote> {
    return this.database.transactionAsUser(user, async (client) => {
      const appointment = await client.query<{
        patient_id: string;
        professional_id: string;
        status: string;
        start_at: Date;
      }>(
        `SELECT appointment.patient_id,appointment.professional_id,
          appointment.status,appointment.start_at FROM appointments appointment
         JOIN professionals professional
           ON professional.id=appointment.professional_id
         WHERE appointment.id=$1 AND professional.user_id=$2 FOR UPDATE`,
        [input.appointmentId, user.id],
      );
      const current = appointment.rows[0];
      if (!current || current.patient_id !== input.patientId) {
        throw new NotFoundException(
          "La consulta no está asignada al profesional.",
        );
      }
      if (
        !["scheduled", "confirmed", "rescheduled", "in_progress"].includes(
          current.status,
        )
      ) {
        throw new BadRequestException(
          "La consulta no puede finalizarse en su estado actual.",
        );
      }
      if (current.start_at.getTime() > Date.now() + 30 * 60 * 1000) {
        throw new BadRequestException(
          "La consulta solo puede finalizarse desde 30 minutos antes de su inicio.",
        );
      }
      const note = await client.query<ClinicalNoteRow>(
        `WITH existing AS (
           SELECT id FROM clinical_notes WHERE appointment_id=$1
             AND professional_id=$3 AND closed_at IS NULL
           ORDER BY created_at DESC LIMIT 1
         ), updated AS (
           UPDATE clinical_notes SET anamnesis=$4,findings=NULLIF($5,''),
             assessment=$6,plan=NULLIF($7,''),closed_at=now(),updated_at=now()
           WHERE id=(SELECT id FROM existing)
           RETURNING id,appointment_id,patient_id,professional_id,
             anamnesis,findings,assessment,plan,created_at
         ), inserted AS (
           INSERT INTO clinical_notes(
             appointment_id,patient_id,professional_id,anamnesis,findings,
             assessment,plan,closed_at
           ) SELECT $1,$2,$3,$4,NULLIF($5,''),$6,NULLIF($7,''),now()
             WHERE NOT EXISTS(SELECT 1 FROM updated)
           RETURNING id,appointment_id,patient_id,professional_id,
             anamnesis,findings,assessment,plan,created_at
         ) SELECT * FROM updated UNION ALL SELECT * FROM inserted`,
        [
          input.appointmentId,
          input.patientId,
          current.professional_id,
          input.subjective.trim(),
          input.objective?.trim() ?? "",
          input.assessment.trim(),
          input.plan?.trim() ?? "",
        ],
      );
      const row = note.rows[0];
      await client.query(
        `INSERT INTO diagnoses(
          clinical_note_id,diagnosis_text,diagnosis_type
         ) VALUES($1,$2,$3)`,
        [row.id, input.diagnosis.trim(), input.diagnosisType],
      );
      if (input.treatment?.trim()) {
        await client.query(
          `INSERT INTO treatments(clinical_note_id,description,instructions)
           VALUES($1,$2,NULLIF($3,''))`,
          [
            row.id,
            input.treatment.trim(),
            input.treatmentInstructions?.trim() ?? "",
          ],
        );
      }
      if (input.followupDueAt || input.followupInstructions?.trim()) {
        await client.query(
          `INSERT INTO appointment_followups(
            source_appointment_id,recommended_by_professional_id,due_at,instructions
           ) VALUES($1,$2,$3,NULLIF($4,''))`,
          [
            input.appointmentId,
            current.professional_id,
            input.followupDueAt ?? null,
            input.followupInstructions?.trim() ?? "",
          ],
        );
      }
      await client.query(
        `WITH updated AS (
          UPDATE clinical_records SET title='Consulta médica',
            content=jsonb_build_object(
              'summary',$2::text,'subjective',$3::text,'objective',$4::text,
              'plan',$5::text,'diagnosis',$6::text,'diagnosisType',$7::text,
              'treatment',$8::text,'clinicalNoteId',$9::text
            ),validation_status='validated',version=version+1,
            change_reason='Cierre de consulta'
          WHERE patient_id=$1 AND related_appointment_id=$12
            AND record_type='note' AND content->>'clinicalNoteId'=$9
          RETURNING id
        ) INSERT INTO clinical_records(
          patient_id,record_type,title,content,source,validation_status,
          author_user_id,author_role,related_appointment_id
        ) SELECT $1,'note','Consulta médica',jsonb_build_object(
          'summary',$2::text,'subjective',$3::text,'objective',$4::text,
          'plan',$5::text,'diagnosis',$6::text,'diagnosisType',$7::text,
          'treatment',$8::text,'clinicalNoteId',$9::text
        ),'professional','validated',$10,$11,$12
        WHERE NOT EXISTS(SELECT 1 FROM updated)`,
        [
          input.patientId,
          input.assessment.trim(),
          input.subjective.trim(),
          input.objective?.trim() ?? "",
          input.plan?.trim() ?? "",
          input.diagnosis.trim(),
          input.diagnosisType,
          input.treatment?.trim() ?? "",
          row.id,
          user.id,
          user.roleCode,
          input.appointmentId,
        ],
      );
      await client.query(
        `UPDATE appointments SET status='completed',updated_at=now() WHERE id=$1`,
        [input.appointmentId],
      );
      await client.query(
        `INSERT INTO appointment_status_history(
          appointment_id,old_status,new_status,changed_by_user_id,reason
         ) VALUES($1,$2,'completed',$3,'Consulta finalizada por el profesional')`,
        [input.appointmentId, current.status, user.id],
      );
      return {
        id: row.id,
        appointmentId: row.appointment_id,
        patientId: row.patient_id,
        professionalId: row.professional_id,
        subjective: row.anamnesis,
        objective: row.findings,
        assessment: row.assessment,
        plan: row.plan,
        createdAt: row.created_at,
      };
    });
  }
}

function cleanValues(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

function mapVitalSign(row: VitalSignRow): VitalSignRecord {
  return {
    id: row.id,
    source: row.source,
    systolicPressure: row.systolic_pressure,
    diastolicPressure: row.diastolic_pressure,
    heartRate: row.heart_rate,
    temperatureC: numberOrNull(row.temperature_c),
    oxygenSaturation: numberOrNull(row.oxygen_saturation),
    respiratoryRate: row.respiratory_rate,
    glucoseMgDl: numberOrNull(row.glucose_mg_dl),
    weightKg: numberOrNull(row.weight_kg),
    heightCm: numberOrNull(row.height_cm),
    notes: row.notes,
    recordedAt: row.recorded_at,
  };
}

function mapClinicalDocument(row: ClinicalDocumentRow): ClinicalDocument {
  return {
    id: row.id,
    documentType: row.document_type,
    fileUrl: row.file_url,
    fileName: row.file_name,
    mimeType: row.mime_type,
    isRestricted: row.is_restricted,
    source: row.source,
    validationStatus: row.validation_status,
    createdAt: row.created_at,
  };
}

function numberOrNull(value: string | null): number | null {
  return value == null ? null : Number(value);
}
