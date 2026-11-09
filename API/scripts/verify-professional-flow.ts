import { PostgresPushRepository } from "../src/modules/notifications/infrastructure/persistence/postgres-push.repository";
import { PostgresPartnersRepository } from "../src/modules/partners/infrastructure/persistence/postgres-partners.repository";
import { PostgresAuthRepository } from "../src/modules/auth/infrastructure/persistence/postgres-auth.repository";
/** Integration regression against a disposable cluster only. No dotenv is loaded.
 * Start an isolated PostgreSQL cluster on 127.0.0.1:55439 with owner docia_test,
 * apply db/01..07 and migrations, then run: npx tsx scripts/verify-professional-flow.ts
 */
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { Pool, PoolClient } from "pg";
import { RequestUser } from "../src/common/types/request-user";
import { DatabaseService } from "../src/database/database.service";
import { PostgresHumanResourcesRepository } from "../src/modules/human-resources/infrastructure/persistence/postgres-human-resources.repository";
import { PostgresProfessionalsRepository } from "../src/modules/professionals/infrastructure/persistence/postgres-professionals.repository";
import { JwtAuthGuard } from "../src/common/guards/jwt-auth.guard";
import { PostgresEmergenciesRepository } from "../src/modules/emergencies/infrastructure/persistence/postgres-emergencies.repository";
import { PostgresClinicalRecordsRepository } from "../src/modules/clinical-records/infrastructure/persistence/postgres-clinical-records.repository";
import { PostgresPatientsRepository } from "../src/modules/patients/infrastructure/persistence/postgres-patients.repository";
import { PostgresAppointmentsRepository } from "../src/modules/appointments/infrastructure/persistence/postgres-appointments.repository";

const isolatedDatabase = process.argv[2] ?? "postgres";
assert.match(
  isolatedDatabase,
  /^(postgres|docia_phase12_(fresh|upgrade)_[a-f0-9]{32})$/,
);
const pool = new Pool({
  host: "127.0.0.1",
  port: 55439,
  user: "docia_test",
  database: isolatedDatabase,
});
let checks = 0;
async function transaction<T>(work: (client: PoolClient) => Promise<T>) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await work(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
const context = async (client: PoolClient, user: RequestUser) => {
  await client.query("SET LOCAL ROLE docia_phase12_runtime");
  for (const [key, value] of Object.entries({
    "app.user_id": user.id,
    "app.session_id": user.sessionId,
    "app.roles": JSON.stringify(user.roles),
    "app.role_code": user.roleCode,
    "app.permissions": JSON.stringify(user.permissions),
  })) {
    await client.query("SELECT set_config($1,$2,true)", [key, value]);
  }
};
const database = {
  transactionAsUser: <T>(
    user: RequestUser,
    work: (client: PoolClient) => Promise<T>,
  ) =>
    transaction(async (client) => {
      await context(client, user);
      return work(client);
    }),
  transactionWithSettings: <T>(
    settings: Record<string, string>,
    work: (client: PoolClient) => Promise<T>,
  ) =>
    transaction(async (client) => {
      await client.query("SET LOCAL ROLE docia_phase12_runtime");
      for (const [key, value] of Object.entries(settings))
        await client.query("SELECT set_config($1,$2,true)", [key, value]);
      return work(client);
    }),
} as DatabaseService;
const hrRepository = new PostgresHumanResourcesRepository(database);
const professionals = new PostgresProfessionalsRepository(database);
const hr: RequestUser = {
  id: randomUUID(),
  sessionId: randomUUID(),
  email: `hr-${randomUUID()}@example.invalid`,
  roleCode: "human_resources",
  roles: ["human_resources"],
  permissions: [
    "human_resources.read",
    "human_resources.manage",
    "professionals.read",
  ],
};
const applicant: RequestUser = {
  id: randomUUID(),
  sessionId: randomUUID(),
  email: `test-${randomUUID()}@example.invalid`,
  roleCode: "patient",
  roles: ["patient"],
  permissions: ["professionals.read"],
};
async function main() {
  // Refuse to touch an arbitrary existing local PostgreSQL installation.
  const directory = (await pool.query("SHOW data_directory")).rows[0]
    .data_directory as string;
  assert.match(directory.replace(/\\/g, "/"), /\/docia-phase12-pg\/?$/);
  await pool.query(`DO $$ BEGIN CREATE ROLE docia_phase12_runtime NOSUPERUSER NOBYPASSRLS; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    GRANT USAGE ON SCHEMA public TO docia_phase12_runtime;
    GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO docia_phase12_runtime;
    GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO docia_phase12_runtime;`);
  for (const user of [hr, applicant]) {
    user.permissions = (
      await pool.query(
        `SELECT p.code FROM roles r JOIN role_permissions rp ON rp.role_id=r.id JOIN permissions p ON p.id=rp.permission_id WHERE r.code=$1`,
        [user.roleCode],
      )
    ).rows.map((row) => row.code as string);
    await pool.query(
      `INSERT INTO users(id,role_id,email,password_hash,email_verified_at) SELECT $1,id,$2,'synthetic-unused',now() FROM roles WHERE code=$3`,
      [user.id, user.email, user.roleCode],
    );
    await pool.query(
      `INSERT INTO persons(user_id,first_name,last_name) VALUES($1,'Synthetic','Fixture')`,
      [user.id],
    );
    await pool.query(
      `INSERT INTO user_sessions(id,user_id,refresh_token_hash,expires_at) VALUES($1,$2,'synthetic-unused',now()+interval '1 hour')`,
      [user.sessionId, user.id],
    );
  }
  const specialty = (
    await pool.query(`INSERT INTO specialties(name) VALUES($1) RETURNING id`, [
      `Synthetic ${randomUUID()}`,
    ])
  ).rows[0].id as string;
  await pool.query(
    `DELETE FROM professional_document_requirements WHERE role_code='doctor_general'`,
  );
  const application = (await hrRepository.submitApplication(applicant, {
    requestedRoleCode: "doctor_general",
    licenseNumber: "TEST-ONLY",
    requestedSpecialty: "Synthetic",
  })) as { id: string };
  await assert.rejects(
    hrRepository.reviewApplication(hr, application.id, {
      status: "approved",
      specialtyId: specialty,
    }),
    /Define los documentos/,
  );
  checks++;
  await hrRepository.configureRequirements(hr, "doctor_general", [
    "Synthetic credential",
  ]);
  await assert.rejects(
    hrRepository.configureRequirements(applicant, "nurse", ["Unauthorized"]),
  );
  checks++;
  const document = (await hrRepository.addApplicationDocument(
    applicant,
    application.id,
    {
      documentType: "Synthetic credential",
      fileUrl: "synthetic/not-a-real-file.pdf",
    },
  )) as { id: string };
  await assert.rejects(
    hrRepository.reviewApplication(hr, application.id, {
      status: "approved",
      specialtyId: specialty,
    }),
    /aprobados/,
  );
  checks++;
  await hrRepository.reviewDocument(hr, document.id, { status: "approved" });
  await assert.rejects(
    hrRepository.reviewApplication(hr, application.id, { status: "approved" }),
    /especialidad/,
  );
  checks++;
  await hrRepository.reviewApplication(hr, application.id, {
    status: "approved",
    specialtyId: specialty,
  });
  const profile = await professionals.getOwnProfile(applicant);
  assert.equal(profile.verificationStatus, "approved");
  assert.equal(profile.specialties[0].id, specialty);
  checks++;
  assert.ok(
    (await professionals.listDirectory(applicant)).some(
      (item) => item.id === profile.id,
    ),
  );
  checks++;
  const payload = {
    sub: applicant.id,
    sid: applicant.sessionId,
    email: applicant.email,
    tokenUse: "access",
    roleCode: "doctor_general",
    roles: ["patient", "doctor_general"],
    permissions: ["clinical_records.manage"],
  };
  const guard = new JwtAuthGuard(
    { getAllAndOverride: () => false } as never,
    { verifyAsync: async () => payload } as never,
    { getOrThrow: () => "synthetic" } as never,
    database,
  );
  const request: { headers: Record<string, string>; user?: RequestUser } = {
    headers: { authorization: "Bearer synthetic" },
  };
  const execution = {
    getHandler: () => null,
    getClass: () => null,
    switchToHttp: () => ({ getRequest: () => request }),
  } as never;
  await guard.canActivate(execution);
  assert.ok(request.user!.roles.includes("doctor_general"));
  checks++;
  await professionals.updateOwnProfile(applicant, {
    licenseNumber: "TEST-CHANGED",
  });
  assert.equal(
    (await professionals.getOwnProfile(applicant)).verificationStatus,
    "under_review",
  );
  assert.ok(
    !(await professionals.listDirectory(applicant)).some(
      (item) => item.id === profile.id,
    ),
  );
  checks++;
  await guard.canActivate(execution);
  assert.ok(!request.user!.permissions.includes("clinical_records.manage"));
  checks++;
  await hrRepository.reviewProfessionalDocument(hr, profile.documents[0].id, {
    status: "rejected",
    observation: "Synthetic rejection",
  });
  await assert.rejects(
    hrRepository.reviewProfessional(hr, profile.id, {
      status: "approved",
      roleCode: "doctor_general",
      specialtyId: specialty,
    }),
    /aprobados/,
  );
  checks++;
  await hrRepository.reviewProfessionalDocument(hr, profile.documents[0].id, {
    status: "approved",
  });
  await hrRepository.reviewProfessional(hr, profile.id, {
    status: "approved",
    roleCode: "doctor_general",
    specialtyId: specialty,
  });
  await guard.canActivate(execution);
  assert.ok(request.user!.permissions.includes("clinical_records.manage"));
  checks++;
  await hrRepository.reviewProfessional(hr, profile.id, {
    status: "rejected",
    reason: "Synthetic rejection",
  });
  await guard.canActivate(execution);
  assert.ok(!request.user!.roles.includes("doctor_general"));
  checks++;
  console.log(
    `Professional integration: ${checks} checks passed (disposable PostgreSQL, runtime role with RLS).`,
  );
  const push = new PostgresPushRepository(database);
  const syntheticToken = "synthetic-" + randomUUID();
  await pool.query(
    "INSERT INTO push_device_tokens(user_id,token) VALUES($1,$2)",
    [applicant.id, syntheticToken],
  );
  assert.ok((await push.claim()).length > 0);
  assert.ok(
    (await push.activeTokensForUser(applicant.id, "emergencies")).includes(
      syntheticToken,
    ),
  );
  await push.deactivateTokens(applicant.id, [syntheticToken]);
  assert.ok(
    !(await push.activeTokensForUser(applicant.id, "emergencies")).includes(
      syntheticToken,
    ),
  );
  console.log(
    "Push persistence: background outbox claims and owner-scoped tokens/deactivation work without RLS bypass.",
  );
  const nursing = new PostgresEmergenciesRepository(database);
  const clinical = new PostgresClinicalRecordsRepository(database);
  const patientId = (
    await pool.query(
      `INSERT INTO patients(person_id) SELECT id FROM persons WHERE user_id=$1 RETURNING id`,
      [applicant.id],
    )
  ).rows[0].id as string;
  const actors: Record<string, RequestUser> = {};
  for (const role of ["nurse", "operator"]) {
    const actor: RequestUser = {
      id: randomUUID(),
      sessionId: randomUUID(),
      email: `fixture-${randomUUID()}@example.invalid`,
      roleCode: role,
      roles: [role],
      permissions: [],
    };
    actor.permissions = (
      await pool.query(
        `SELECT p.code FROM roles r JOIN role_permissions rp ON rp.role_id=r.id JOIN permissions p ON p.id=rp.permission_id WHERE r.code=$1`,
        [role],
      )
    ).rows.map((row) => row.code as string);
    await pool.query(
      `INSERT INTO users(id,role_id,email,password_hash,email_verified_at) SELECT $1,id,$2,'synthetic-unused',now() FROM roles WHERE code=$3`,
      [actor.id, actor.email, role],
    );
    const person = (
      await pool.query(
        `INSERT INTO persons(user_id,first_name,last_name) VALUES($1,'Synthetic','Care') RETURNING id`,
        [actor.id],
      )
    ).rows[0].id;
    await pool.query(
      `INSERT INTO professionals(user_id,person_id,professional_type,verification_status) VALUES($1,$2,$3,'approved')`,
      [actor.id, person, role],
    );
    actors[role] = actor;
  }
  const nurse = actors.nurse,
    operator = actors.operator;
  const nurseId = (
    await pool.query(`SELECT id FROM professionals WHERE user_id=$1`, [
      nurse.id,
    ])
  ).rows[0].id as string;
  let nursingChecks = 0;
  const event = await nursing.create(applicant, {
    riskLevel: "yellow",
    manualAddress: "Synthetic location",
  });
  assert.ok(
    (
      await pool.query(
        `SELECT 1 FROM notifications WHERE user_id=$1 AND related_entity_id=$2`,
        [operator.id, event.id],
      )
    ).rowCount,
  );
  nursingChecks++;
  await nursing.assign(operator, event.id, { professionalId: nurseId });
  assert.ok(
    (await nursing.list(nurse)).items.some((item) => item.id === event.id),
  );
  nursingChecks++;
  await assert.rejects(
    nursing.updateStatus(nurse, event.id, { status: "on_route" }),
    /aceptada/,
  );
  nursingChecks++;
  await nursing.decideAssignment(nurse, event.id, {
    decision: "rejected",
    reason: "Synthetic unavailability",
  });
  assert.ok(
    !(await nursing.list(nurse)).items.some((item) => item.id === event.id),
  );
  nursingChecks++;
  await nursing.assign(operator, event.id, { professionalId: nurseId });
  await nursing.decideAssignment(nurse, event.id, { decision: "accepted" });
  await nursing.updateStatus(nurse, event.id, { status: "on_route" });
  await nursing.updateStatus(nurse, event.id, { status: "on_site" });
  const vitals = {
    systolicPressure: 120,
    diastolicPressure: 80,
    heartRate: 70,
    temperatureC: 36.5,
    oxygenSaturation: 98,
    respiratoryRate: null,
    glucoseMgDl: null,
    weightKg: null,
    heightCm: null,
    notes: null,
    emergencyId: event.id,
  };
  const vital = await clinical.createProfessionalVitalSign(
    nurse,
    patientId,
    vitals,
  );
  assert.equal(vital.source, "professional");
  nursingChecks++;
  await assert.rejects(
    clinical.createProfessionalVitalSign(operator, patientId, vitals),
    /autorizada/,
  );
  nursingChecks++;
  await nursing.recordCare(nurse, event.id, {
    careType: "nursing_assessment",
    notes: "Synthetic note",
    symptoms: [],
    assessment: "Synthetic assessment",
  });
  assert.equal((await nursing.careHistory(nurse, event.id)).length, 1);
  nursingChecks++;
  await assert.rejects(
    nursing.recordCare(nurse, event.id, {
      careType: "medical_assessment",
      notes: "Synthetic",
      symptoms: [],
      assessment: "Synthetic",
    }),
    /médica/,
  );
  nursingChecks++;
  await assert.rejects(
    nursing.updateStatus(nurse, event.id, { status: "closed" }),
    /Registra el cierre/,
  );
  nursingChecks++;
  await nursing.recordCare(nurse, event.id, {
    careType: "closure",
    notes: "Synthetic closure",
    symptoms: [],
    assessment: "Synthetic assessment",
  });
  await nursing.updateStatus(nurse, event.id, { status: "closed" });
  await assert.rejects(
    clinical.createProfessionalVitalSign(nurse, patientId, vitals),
    /autorizada/,
  );
  nursingChecks++;
  console.log(
    `Nursing integration: ${nursingChecks} checks passed (assignment, decline, acceptance, care, vitals, closure, contextual permissions).`,
  );
  const start = new Date(Date.now() + 86400000),
    end = new Date(start.getTime() + 3600000);
  const shiftInput = {
    professionalId: nurseId,
    startAt: start.toISOString(),
    endAt: end.toISOString(),
    location: "Synthetic site",
    area: "Synthetic area",
    notes: "Synthetic notes",
    status: "assigned" as const,
    reason: "Synthetic assignment",
  };
  const shift = (await professionals.saveShift(hr, shiftInput)) as {
    id: string;
  };
  await assert.rejects(professionals.saveShift(hr, shiftInput), /superpone/);
  await assert.rejects(professionals.saveShift(nurse, shiftInput));
  const ownShifts = (await professionals.listShifts(nurse, {
    from: new Date().toISOString(),
    to: new Date(Date.now() + 172800000).toISOString(),
  })) as { id: string }[];
  assert.ok(ownShifts.some((item) => item.id === shift.id));
  assert.equal((await professionals.listShifts(applicant, {})).length, 0);
  await professionals.saveShift(
    hr,
    { ...shiftInput, status: "cancelled", reason: "Synthetic cancellation" },
    shift.id,
  );
  assert.equal(
    (await professionals.resource(nurse, "work_shift_history")).length,
    2,
  );
  assert.ok(
    (await professionals.availableStaff(hr, { role: "nurse" })).length > 0,
  );
  console.log(
    "Shifts integration: create, overlap rejection, owner read, unauthorized writes, cancellation, history, availability passed.",
  );
  const patients = new PostgresPatientsRepository(database);
  const minorInput = {
    firstName: "Synthetic",
    lastName: "Dependent",
    birthDate: "2020-01-01",
    relationship: "Tutor declarado",
    confirmResponsibility: true,
  };
  await assert.rejects(patients.createDependent(applicant, minorInput));
  await pool.query(
    `UPDATE persons SET birth_date='1990-01-01' WHERE user_id=$1`,
    [applicant.id],
  );
  const dependent = await patients.createDependent(applicant, minorInput);
  assert.ok(
    (await patients.listFamily(applicant)).some(
      (item) => item.patientId === dependent.patientId,
    ),
  );
  await assert.rejects(
    patients.createDependent(applicant, {
      ...minorInput,
      confirmResponsibility: false,
    }),
  );
  assert.equal(
    await database.transactionAsUser(
      applicant,
      async (client) =>
        (
          await client.query(
            `SELECT app_can_patient_action($1,'appointments.manage') AS allowed`,
            [dependent.patientId],
          )
        ).rows[0].allowed,
    ),
    true,
  );
  const relative = actors.operator;
  await patients.createFamilyAuthorization(applicant, {
    email: relative.email,
    relationship: "Synthetic family",
    canViewHistory: true,
    canBookAppointments: false,
    canHandleEmergencies: false,
  });
  assert.ok(
    (await patients.listFamily(relative)).some(
      (item) =>
        item.patientId === patientId &&
        item.canViewHistory &&
        !item.canBookAppointments,
    ),
  );
  assert.equal(
    await database.transactionAsUser(
      relative,
      async (client) =>
        (
          await client.query(
            `SELECT app_can_patient_action($1,'appointments.manage') AS allowed`,
            [patientId],
          )
        ).rows[0].allowed,
    ),
    false,
  );
  const link = (await patients.listFamily(applicant)).find(
    (item) => item.linkKind === "outgoing",
  )!;
  await patients.revokeFamilyAuthorization(applicant, link.id);
  assert.ok(
    !(await patients.listFamily(relative)).some(
      (item) => item.patientId === patientId,
    ),
  );
  console.log(
    "Family integration: minor creation, adult requirement, responsibility, scoped permissions, incoming links and immediate revocation passed.",
  );
  await clinical.updateOwnProfile(
    applicant,
    {
      bloodType: "O+",
      allergies: ["Synthetic substance"],
      emergencyContactName: "Synthetic contact",
      emergencyContactPhone: "synthetic-unused",
    },
    dependent.patientId,
  );
  assert.equal(
    (await clinical.getOwnProfile(applicant, dependent.patientId))?.bloodType,
    "O+",
  );
  await pool.query(
    `UPDATE allergies SET validation_status='validated' WHERE patient_id=$1`,
    [dependent.patientId],
  );
  await clinical.updateOwnProfile(
    applicant,
    { allergies: ["Synthetic new statement"] },
    dependent.patientId,
  );
  assert.ok(
    (await clinical.getOwnProfile(
      applicant,
      dependent.patientId,
    ))!.allergies.includes("Synthetic substance"),
  );
  await assert.rejects(
    clinical.updateOwnProfile(
      relative,
      { bloodType: "A+" },
      dependent.patientId,
    ),
  );
  await hrRepository.reviewProfessional(hr, profile.id, {
    status: "approved",
    roleCode: "doctor_general",
    specialtyId: specialty,
  });
  const appointmentStart = new Date(Date.now() + 3 * 86400000);
  appointmentStart.setUTCHours(14, 0, 0, 0);
  await professionals.createAvailability(applicant, {
    weekday: appointmentStart.getUTCDay(),
    startTime: "09:00",
    endTime: "18:00",
    modality: "telemedicine",
  });
  const appointments = new PostgresAppointmentsRepository(database);
  const appointmentInput = {
    patientId: dependent.patientId,
    professionalId: profile.id,
    specialtyId: specialty,
    modality: "telemedicine" as const,
    startAt: appointmentStart,
    endAt: new Date(appointmentStart.getTime() + 1800000),
    reason: "Synthetic booking",
  };
  const booking = await appointments.create(applicant, appointmentInput);
  assert.equal(booking.patientId, dependent.patientId);
  assert.ok(
    (await appointments.listForUser(applicant)).some(
      (item) => item.id === booking.id,
    ),
  );
  const admin: RequestUser = {
    ...hr,
    id: randomUUID(),
    sessionId: randomUUID(),
    email: `admin-${randomUUID()}@example.invalid`,
    roleCode: "admin",
    roles: ["admin"],
    permissions: ["administration.manage", "clinical_records.read"],
  };
  await pool.query(
    `INSERT INTO users(id,role_id,email,password_hash,email_verified_at) SELECT $1,id,$2,'synthetic-unused',now() FROM roles WHERE code='admin'`,
    [admin.id, admin.email],
  );
  await pool.query(
    `UPDATE profile_completion_policy SET policy='{"rules":[],"rewardEnabled":false}'`,
  );
  assert.equal(
    (
      (await clinical.completion(applicant, dependent.patientId)) as {
        percent: null;
      }
    ).percent,
    null,
  );
  const policy = {
    rules: [
      {
        field: "bloodType" as const,
        label: "Synthetic patient field",
        actor: "patient" as const,
      },
      {
        field: "professionalVitals" as const,
        label: "Synthetic professional field",
        actor: "professional" as const,
      },
    ],
    rewardEnabled: false,
  };
  await assert.rejects(clinical.saveCompletionPolicy(applicant, policy));
  await clinical.saveCompletionPolicy(admin, policy);
  assert.equal(
    (
      (await clinical.completion(applicant, dependent.patientId)) as {
        percent: number;
      }
    ).percent,
    50,
  );
  await assert.rejects(
    clinical.saveCompletionPolicy(admin, { ...policy, rewardEnabled: true }),
    /Define reglas/,
  );
  const benefitId = (
    await pool.query(
      `INSERT INTO benefits(code,name,discount_percent) VALUES($1,'Synthetic profile reward',10) RETURNING id`,
      [randomUUID()],
    )
  ).rows[0].id;
  await clinical.saveCompletionPolicy(admin, {
    ...policy,
    rewardEnabled: true,
    benefitId,
    campaignId: randomUUID(),
    threshold: 50,
    validUntil: new Date(Date.now() + 86400000).toISOString(),
  });
  assert.equal(
    (
      (await clinical.completion(applicant, dependent.patientId)) as {
        rewardAssignedNow: boolean;
      }
    ).rewardAssignedNow,
    false,
  );
  await pool.query(
    `INSERT INTO vital_signs(patient_id,source,recorded_by_user_id,heart_rate) VALUES($1,'professional',$2,70)`,
    [dependent.patientId, nurse.id],
  );
  assert.equal(
    (
      (await clinical.completion(applicant, dependent.patientId)) as {
        rewardAssignedNow: boolean;
      }
    ).rewardAssignedNow,
    true,
  );
  assert.equal(
    (
      (await clinical.completion(applicant, dependent.patientId)) as {
        rewardAssignedNow: boolean;
      }
    ).rewardAssignedNow,
    false,
  );
  await clinical.saveCompletionPolicy(admin, {
    ...policy,
    rewardEnabled: false,
  });
  await pool.query(
    `INSERT INTO clinical_records(patient_id,record_type,title,content,patient_visible) VALUES
    ($1,'note','Synthetic public','{"summary":"Synthetic summary","internal_notes":"PRIVATE_SENTINEL","nested":{"private":"PRIVATE_SENTINEL"}}',TRUE),
    ($1,'note','HIDDEN_SENTINEL','{}',FALSE)`,
    [dependent.patientId],
  );
  const exported = JSON.stringify(
    await clinical.exportRecord(applicant, dependent.patientId),
  );
  assert.ok(
    !exported.includes("PRIVATE_SENTINEL") &&
      !exported.includes("HIDDEN_SENTINEL"),
  );
  assert.ok(
    !(await clinical.listOwnHistory(applicant, dependent.patientId)).some(
      (row) => row.title === "HIDDEN_SENTINEL",
    ),
  );
  await assert.rejects(clinical.exportRecord(relative, dependent.patientId));
  assert.ok(
    !JSON.stringify(
      await clinical.resource(applicant, "clinical_records"),
    ).includes("PRIVATE_SENTINEL"),
  );
  assert.equal(
    await database.transactionAsUser(
      applicant,
      async (client) =>
        (
          await client.query(
            "SELECT count(*)::int AS count FROM clinical_records WHERE patient_id=$1 AND title='HIDDEN_SENTINEL'",
            [dependent.patientId],
          )
        ).rows[0].count,
    ),
    0,
  );
  const filteredExport = (await clinical.exportRecord(
    applicant,
    dependent.patientId,
    "jampic",
    ["vitalSigns"],
  )) as { clinicalRecords: unknown[] };
  assert.equal(filteredExport.clinicalRecords.length, 0);
  const started = performance.now();
  const familyEmergency = await nursing.create(applicant, {
    patientId: dependent.patientId,
    riskLevel: "yellow",
    manualAddress: "Synthetic dependent location",
  });
  const elapsed = performance.now() - started;
  assert.ok(
    (await nursing.list(applicant)).items.some(
      (item) => item.id === familyEmergency.id,
    ),
  );
  assert.ok(
    (
      await pool.query(
        `SELECT id FROM notifications WHERE user_id=$1 AND related_entity_id=$2`,
        [applicant.id, familyEmergency.id],
      )
    ).rowCount,
  );
  assert.throws(() =>
    appointments.markNoShow(applicant, booking.id, "Synthetic no show"),
  );
  const doctor: RequestUser = {
    ...applicant,
    roleCode: "doctor_general",
    roles: ["patient", "doctor_general"],
    permissions: [...applicant.permissions, "clinical_records.manage"],
  };
  await assert.rejects(
    appointments.markNoShow(doctor, booking.id, "Synthetic no show"),
    /finalizar/,
  );
  await pool.query(
    `UPDATE appointments SET start_at=now()-interval '2 hours',end_at=now()-interval '1 hour' WHERE id=$1`,
    [booking.id],
  );
  assert.equal(
    (await appointments.markNoShow(doctor, booking.id, "Synthetic no show"))
      .status,
    "no_show",
  );
  await assert.rejects(
    appointments.markNoShow(doctor, booking.id, "Synthetic duplicate"),
  );
  console.log(
    `Completion/export/emergency/no-show: configuration, actor responsibility, reward disabled/idempotency, restricted export, access checks and transitions passed. Local emergency registration with transactional alert: ${elapsed.toFixed(1)} ms (not a production SLA).`,
  );

  // Cross-account booking visibility must not allow double booking under RLS.
  const otherPatientId = (
    await pool.query(
      `INSERT INTO patients(person_id) SELECT id FROM persons WHERE user_id=$1 RETURNING id`,
      [operator.id],
    )
  ).rows[0].id;
  const other: RequestUser = {
    ...operator,
    roles: ["patient"],
    roleCode: "patient",
    permissions: [...applicant.permissions],
  };
  const future = {
    ...appointmentInput,
    patientId: otherPatientId,
    startAt: new Date(appointmentStart.getTime() + 3600000),
    endAt: new Date(appointmentStart.getTime() + 5400000),
  };
  const otherBooking = await appointments.create(other, future);
  await assert.rejects(
    appointments.create(applicant, {
      ...future,
      patientId: dependent.patientId,
    }),
    /disponible/,
  );
  const directoryEntry = (await professionals.listDirectory(applicant)).find(
    (item) => item.id === profile.id,
  )!;
  assert.ok(directoryEntry.bookableSlots.length > 0);
  assert.ok(
    !directoryEntry.bookableSlots.some(
      (slot) => new Date(slot.startAt).getTime() === future.startAt.getTime(),
    ),
  );
  await appointments.reschedule(
    other,
    otherBooking.id,
    new Date(appointmentStart.getTime() + 7200000),
    new Date(appointmentStart.getTime() + 9000000),
  );
  const serviceId = (
    await pool.query(
      "SELECT id FROM service_catalog WHERE code='consult_general_telemedicine'",
    )
  ).rows[0].id;
  await pool.query(
    "INSERT INTO price_list(service_id,charge_mode,coin_price,currency,valid_from,created_by_user_id) VALUES($1,'coins',17,'BOB',current_date,$2)",
    [serviceId, admin.id],
  );
  const pricedBooking = await appointments.create(applicant, {
    ...appointmentInput,
    serviceId,
    startAt: new Date(appointmentStart.getTime() + 10800000),
    endAt: new Date(appointmentStart.getTime() + 12600000),
  });
  assert.equal(
    (
      await pool.query(
        "SELECT count(*)::int AS count FROM payment_orders WHERE appointment_id=$1",
        [pricedBooking.id],
      )
    ).rows[0].count,
    1,
  );
  const invalidTariffStart = new Date(appointmentStart.getTime() + 14400000);
  await assert.rejects(
    appointments.create(applicant, {
      ...appointmentInput,
      serviceId: randomUUID(),
      startAt: invalidTariffStart,
      endAt: new Date(invalidTariffStart.getTime() + 1800000),
    }),
    /tarifa/,
  );
  assert.equal(
    (
      await pool.query(
        "SELECT count(*)::int AS count FROM appointments WHERE professional_id=$1 AND start_at=$2",
        [profile.id, invalidTariffStart],
      )
    ).rows[0].count,
    0,
  );
  const partner = (
    await pool.query(
      "INSERT INTO health_partners(name,partner_type) VALUES('Synthetic laboratory','laboratory') RETURNING id",
    )
  ).rows[0].id;
  await pool.query(
    "INSERT INTO partner_users(partner_id,user_id,partner_role) VALUES($1,$2,'clinical')",
    [partner, operator.id],
  );
  await pool.query("UPDATE appointments SET status='in_progress' WHERE id=$1", [
    pricedBooking.id,
  ]);
  const partners = new PostgresPartnersRepository(database);
  const order = (await partners.createDiagnosticOrder(doctor, {
    patientId: dependent.patientId,
    appointmentId: pricedBooking.id,
    partnerId: partner,
    orderType: "lab",
    description: "Synthetic study",
  })) as { id: string };
  await assert.rejects(
    partners.createDiagnosticOrder(nurse, {
      patientId: dependent.patientId,
      orderType: "lab",
      description: "Synthetic unauthorized",
    }),
  );
  await partners.completeDiagnosticOrder(operator, order.id, {
    documentType: "lab_result",
    fileUrl: "synthetic/result.pdf",
    fileName: "synthetic.pdf",
    mimeType: "application/pdf",
  });
  assert.ok(
    (
      (await partners.resource(applicant, "diagnostic_orders")) as {
        id: string;
        result_file_url: string;
      }[]
    ).some(
      (item) =>
        item.id === order.id && item.result_file_url === "synthetic/result.pdf",
    ),
  );
  await pool.query("UPDATE appointments SET status='completed' WHERE id=$1", [
    pricedBooking.id,
  ]);
  // Ratings are submitted by the patient, not automatically by their guardian.
  await assert.rejects(
    appointments.rate(applicant, pricedBooking.id, 5, "Synthetic", true),
  );
  const ownBooking = await appointments.create(applicant, {
    ...appointmentInput,
    patientId: undefined,
    startAt: new Date(appointmentStart.getTime() + 18000000),
    endAt: new Date(appointmentStart.getTime() + 19800000),
  });
  await pool.query("UPDATE appointments SET status='completed' WHERE id=$1", [
    ownBooking.id,
  ]);
  await appointments.rate(
    applicant,
    ownBooking.id,
    5,
    "Synthetic public feedback",
    true,
  );
  await assert.rejects(
    appointments.rate(applicant, ownBooking.id, 4, "Duplicate", true),
  );
  assert.ok(
    JSON.stringify(
      (await professionals.listDirectory(applicant)).find(
        (item) => item.id === profile.id,
      )?.publicDetails.reviews,
    ).includes("Synthetic public feedback"),
  );
  const fhir = (await clinical.exportRecord(
    applicant,
    dependent.patientId,
    "fhir",
    ["clinicalRecords"],
  )) as { entry: { resource: { resourceType: string } }[] };
  assert.ok(
    fhir.entry.some(
      (item) => item.resource.resourceType === "DocumentReference",
    ),
  );
  const auth = new PostgresAuthRepository(database, {
    get: () => undefined,
  } as never);
  assert.ok(
    (await auth.findLoginUser(applicant.email)).roles.includes(
      "doctor_general",
    ),
  );
  await professionals.createOwnDocument(applicant, {
    documentType: "Synthetic renewal",
    fileUrl: "synthetic/renewal.pdf",
  });
  assert.ok(
    !(await auth.findLoginUser(applicant.email)).roles.includes(
      "doctor_general",
    ),
  );
  await guard.canActivate(execution);
  assert.ok(!request.user!.permissions.includes("clinical_records.manage"));
  // An existing minor can link an adult account without broad code visibility.
  const minorUser = randomUUID();
  await pool.query(
    "INSERT INTO users(id,role_id,email,password_hash,email_verified_at) SELECT $1,id,$2,'synthetic-unused',now() FROM roles WHERE code='patient'",
    [minorUser, "minor-" + minorUser + "@example.invalid"],
  );
  const minorPerson = (
    await pool.query(
      "INSERT INTO persons(user_id,first_name,last_name,birth_date) VALUES($1,'Synthetic','Minor','2020-01-01') RETURNING id",
      [minorUser],
    )
  ).rows[0].id;
  await transaction(async (client) => {
    const minorPatient = (
      await client.query(
        "INSERT INTO patients(person_id,is_minor) VALUES($1,TRUE) RETURNING id",
        [minorPerson],
      )
    ).rows[0].id;
    await client.query(
      "INSERT INTO patient_guardians(patient_id,guardian_user_id,relationship,is_legal_guardian,verification_status) VALUES($1,$2,'Synthetic',TRUE,'validated')",
      [minorPatient, applicant.id],
    );
  });
  const minorActor: RequestUser = {
    ...applicant,
    id: minorUser,
    email: "minor-" + minorUser + "@example.invalid",
    roles: ["patient"],
    roleCode: "patient",
  };
  const code = await patients.createGuardianLinkCode(minorActor);
  await patients.redeemGuardianLinkCode(applicant, {
    code: code.code,
    relationship: "Synthetic tutor",
  });
  await assert.rejects(
    patients.redeemGuardianLinkCode(applicant, {
      code: code.code,
      relationship: "Synthetic duplicate",
    }),
  );
  console.log(
    "Directory/booking/diagnostics/login: private occupancy exclusion, rescheduling, atomic pricing and rollback, results, public rating consent, duplicate prevention, FHIR documents, credential revalidation and one-use guardian code passed.",
  );
  await pool.query(
    `UPDATE patient_guardians SET revoked_at=now() WHERE patient_id=$1`,
    [dependent.patientId],
  );
  await assert.rejects(
    appointments.create(applicant, {
      ...appointmentInput,
      startAt: new Date(appointmentStart.getTime() + 3600000),
      endAt: new Date(appointmentStart.getTime() + 5400000),
    }),
  );
  assert.ok(
    !(await nursing.list(applicant)).items.some(
      (item) => item.id === familyEmergency.id,
    ),
  );
  console.log(
    "Dependent clinical profile and booking: authorized update/read, preservation of validated statements, cross-user denial, booking/list and revocation passed.",
  );
}
main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
