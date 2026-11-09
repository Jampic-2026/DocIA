/** Disposable localhost cluster only. No dotenv, provider credentials, or operational data. */
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { Pool, PoolClient } from "pg";
import { DatabaseService } from "../src/database/database.service";
import { RequestUser } from "../src/common/types/request-user";
import { PostgresTelemedicineRepository } from "../src/modules/appointments/infrastructure/persistence/postgres-telemedicine.repository";
import { PostgresGuidanceRepository } from "../src/modules/guidance/infrastructure/postgres-guidance.repository";
import { PostgresPrescriptionsRepository } from "../src/modules/prescriptions/infrastructure/persistence/postgres-prescriptions.repository";
import { MeetProvider } from "../src/modules/integrations/domain/ports/meet-provider";
import { evaluateRisk } from "../src/modules/guidance/domain/risk-policy";
import { AiService } from "../src/modules/ai/application/ai.service";
import { PostgresAiRepository } from "../src/modules/ai/infrastructure/persistence/postgres-ai.repository";
import { ConsentsService } from "../src/modules/consents/application/consents.service";
import { PostgresConsentsRepository } from "../src/modules/consents/infrastructure/persistence/postgres-consents.repository";
import { GuidanceService } from "../src/modules/guidance/application/guidance.service";
const name = process.argv[2];
assert.match(name, /^docia_phase12_(fresh|upgrade)_[a-f0-9]{32}$/);
const pool = new Pool({
  host: "127.0.0.1",
  port: 55439,
  user: "docia_test",
  database: name,
});
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
const database = {
  transactionAsUser: <T>(
    user: RequestUser,
    work: (client: PoolClient) => Promise<T>,
  ) =>
    transaction(async (client) => {
      await client.query("SET LOCAL ROLE docia_phase12_runtime");
      for (const [key, value] of Object.entries({
        "app.user_id": user.id,
        "app.role_code": user.roleCode,
        "app.roles": JSON.stringify(user.roles),
        "app.permissions": JSON.stringify(user.permissions),
      }))
        await client.query("SELECT set_config($1,$2,true)", [key, value]);
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
let checks = 0;
const check = (value: unknown) => {
  assert.ok(value);
  checks++;
};
const denied = async (work: () => Promise<unknown>) => {
  await assert.rejects(work);
  checks++;
};
async function fixture(roleCode: string) {
  const user: RequestUser = {
    id: randomUUID(),
    sessionId: randomUUID(),
    email: randomUUID() + "@example.invalid",
    roleCode,
    roles: [roleCode],
    permissions: [],
  };
  await pool.query(
    `INSERT INTO users(id,role_id,email,password_hash,email_verified_at) SELECT $1,id,$2,'synthetic-unused',now() FROM roles WHERE code=$3`,
    [user.id, user.email, roleCode],
  );
  const person = (
    await pool.query(
      `INSERT INTO persons(user_id,first_name,last_name,birth_date) VALUES($1,'Synthetic','PhaseThree','1990-01-01') RETURNING id`,
      [user.id],
    )
  ).rows[0].id;
  user.permissions = (
    await pool.query(
      `SELECT permission.code FROM roles role JOIN role_permissions rp ON rp.role_id=role.id JOIN permissions permission ON permission.id=rp.permission_id WHERE role.code=$1`,
      [roleCode],
    )
  ).rows.map((row) => row.code);
  return { user, person };
}
async function main() {
  assert.match(
    (await pool.query("SHOW data_directory")).rows[0].data_directory.replace(
      /\\/g,
      "/",
    ),
    /\/docia-phase12-pg\/?$/,
  );
  const administrator = await fixture("admin");
  const patient = await fixture("patient"),
    other = await fixture("patient"),
    doctor = await fixture("doctor_general"),
    supervisor = await fixture("clinical_supervisor"),
    operator = await fixture("operator");
  const patientId = (
    await pool.query(
      "INSERT INTO patients(person_id) VALUES($1) RETURNING id",
      [patient.person],
    )
  ).rows[0].id;
  await pool.query("INSERT INTO patients(person_id) VALUES($1)", [
    other.person,
  ]);
  const professionalId = (
    await pool.query(
      `INSERT INTO professionals(user_id,person_id,professional_type,verification_status,public_profile_enabled) VALUES($1,$2,'doctor','approved',true) RETURNING id`,
      [doctor.user.id, doctor.person],
    )
  ).rows[0].id;
  await pool.query(
    `INSERT INTO professionals(user_id,person_id,professional_type,verification_status) VALUES($1,$2,'clinical_supervisor','approved')`,
    [supervisor.user.id, supervisor.person],
  );
  let created = 0,
    closed = 0,
    failCreate = false,
    failClose = false;
  const meet = {
    allowDirectJoin: async () => {},
    createSpace: async () => {
      if (failCreate) throw Error("synthetic-provider-unavailable");
      created++;
      return {
        name: "spaces/synthetic_" + created,
        meetingUri: "https://meet.google.com/synthetic-" + created,
      };
    },
    endActiveConference: async () => {
      if (failClose) throw Error("synthetic-provider-unavailable");
      closed++;
    },
  } as unknown as MeetProvider;
  const rooms = new PostgresTelemedicineRepository(database, {} as never),
    guidance = new PostgresGuidanceRepository(database);
  const appointment = (
    await pool.query(
      `INSERT INTO appointments(patient_id,professional_id,modality,status,start_at,end_at,created_by_user_id)
    VALUES($1,$2,'telemedicine','confirmed',now(),now()+interval '30 minutes',$3) RETURNING id`,
      [patientId, professionalId, patient.user.id],
    )
  ).rows[0].id;
  check(
    (await rooms.claimRoomJobs()).some(
      (job) => job.appointmentId === appointment,
    ),
  );
  await rooms.failRoomJob(appointment);
  await rooms.failRoomJob(appointment);
  check(
    (
      await pool.query(
        `SELECT count(*)::int AS n FROM notifications WHERE user_id=$1 AND related_entity_id=$2`,
        [administrator.user.id, appointment],
      )
    ).rows[0].n === 1,
  );
  await denied(() => rooms.createRoom(appointment, other.user, meet));
  const room = await rooms.createRoom(appointment, patient.user, meet);
  check(
    (await rooms.listRooms(patient.user)).items.some(
      (item) => item.id === room.id,
    ),
  );
  check(
    (await rooms.createRoom(appointment, doctor.user, meet)).id === room.id &&
      created === 1,
  );
  check(
    (
      await pool.query(
        "SELECT count(*)::int AS n FROM telemedicine_participants WHERE room_id=$1",
        [room.id],
      )
    ).rows[0].n === 2,
  );
  check(
    (
      await pool.query(
        "SELECT count(*)::int AS n FROM notifications WHERE related_entity_id=$1",
        [room.id],
      )
    ).rows[0].n === 2,
  );
  await denied(() => rooms.registerJoin(room.id, other.user));
  await denied(() => rooms.registerJoin(room.id, patient.user));
  await denied(() => rooms.closeRoom(room.id, doctor.user, meet));
  await rooms.registerJoin(room.id, doctor.user);
  check(
    (
      await pool.query("SELECT status FROM appointments WHERE id=$1", [
        appointment,
      ])
    ).rows[0].status === "in_progress",
  );
  await rooms.registerJoin(room.id, patient.user);
  await rooms.registerLeave(room.id, patient.user);
  await rooms.registerJoin(room.id, patient.user);
  check(
    (await rooms.activity(room.id, patient.user)).participants.some(
      (item) => item.userId === patient.user.id && item.leftAt === null,
    ),
  );
  await denied(() => rooms.closeRoom(room.id, patient.user, meet));
  failClose = true;
  await denied(() => rooms.closeRoom(room.id, doctor.user, meet));
  failClose = false;
  check(
    (
      await pool.query("SELECT status FROM telemedicine_rooms WHERE id=$1", [
        room.id,
      ])
    ).rows[0].status === "active",
  );
  await pool.query(
    `INSERT INTO clinical_notes(appointment_id,patient_id,professional_id,assessment,closed_at) VALUES($1,$2,$3,'Synthetic completed care',now())`,
    [appointment, patientId, professionalId],
  );
  check((await rooms.closeRoom(room.id, doctor.user, meet)).closed);
  check(
    (
      await pool.query("SELECT status FROM appointments WHERE id=$1", [
        appointment,
      ])
    ).rows[0].status === "completed",
  );
  await rooms.closeRoom(room.id, doctor.user, meet);
  check(closed === 1);
  await denied(() => rooms.registerJoin(room.id, patient.user));
  await rooms.completeRoomJob(appointment);
  const defaults = await guidance.policy(patient.user);
  check(!defaults.enabled && defaults.policy.rules.length === 0);
  const consents = new ConsentsService(
    new PostgresConsentsRepository(database),
  );
  await consents.accept(patient.user, "ai_orientation", {});
  const aiRepository = new PostgresAiRepository(database, {
    get: () => undefined,
  } as never);
  const guidanceService = new GuidanceService(guidance, meet, consents);
  let providerFailure = false;
  const aiService = new AiService(
    aiRepository,
    { get: () => undefined } as never,
    consents,
    {
      reply: async () => {
        if (providerFailure) throw new Error("synthetic provider unavailable");
        return "Synthetic general orientation";
      },
    },
    guidanceService,
  );
  const chat = await aiService.send(patient.user, {
    message: "synthetic ordinary message",
    useClinicalContext: true,
  });
  check(
    chat.classificationStatus === "disabled" &&
      chat.riskLevel === "undetermined",
  );
  check(
    (
      await aiRepository.listMessages(chat.conversationId, patient.user)
    ).items.some((item) => item.safetyFlags.assessmentId === chat.assessmentId),
  );
  await denied(() =>
    aiRepository.listMessages(chat.conversationId, other.user),
  );
  const before = await aiRepository.chatBalance(patient.user);
  providerFailure = true;
  await denied(() =>
    aiService.send(patient.user, {
      message: "synthetic provider failure",
      conversationId: chat.conversationId,
    }),
  );
  providerFailure = false;
  check((await aiRepository.chatBalance(patient.user)) === before);
  const alert = await aiService.send(patient.user, {
    message: "no puedo respirar",
    conversationId: chat.conversationId,
  });
  check(
    alert.classificationStatus === "preventive_alert" &&
      alert.recommendedAction === "emergency",
  );
  await guidance.decision(patient.user, alert.assessmentId, "declined");
  const policy = {
    rules: [
      {
        code: "synthetic_context",
        terms: ["synthetic symptom"],
        antecedentTerms: ["synthetic antecedent"],
        riskLevel: "yellow" as const,
        action: "appointment" as const,
        questions: ["Synthetic additional information?"],
      },
    ],
  };
  await guidance.savePolicy(supervisor.user, policy);
  const revision = (await guidance.policy(supervisor.user)).revision;
  await denied(() =>
    guidance.approvePolicy(operator.user, revision, "synthetic protocol"),
  );
  await denied(() =>
    guidance.approvePolicy(supervisor.user, revision - 1, "synthetic protocol"),
  );
  await guidance.approvePolicy(
    supervisor.user,
    revision,
    "synthetic protocol, not clinical validation",
  );
  check((await guidance.policy(patient.user)).enabled);
  await pool.query(
    `INSERT INTO medical_antecedents(patient_id,antecedent_type,description) VALUES($1,'pathological','synthetic antecedent')`,
    [patientId],
  );
  const context = await guidance.context(patient.user, patientId);
  check(context.includes("synthetic antecedent"));
  check((await guidance.context(other.user, patientId)) === "");
  const evaluation = evaluateRisk(policy, true, "synthetic symptom", context);
  check(evaluation.riskLevel === "yellow" && evaluation.questions.length === 1);
  check(
    evaluateRisk(policy, false, "synthetic symptom", context).riskLevel ===
      "undetermined",
  );
  const conversation = (
    await pool.query(
      `INSERT INTO ai_conversations(patient_id,created_by_user_id) VALUES($1,$2) RETURNING id`,
      [patientId, patient.user.id],
    )
  ).rows[0].id;
  const assessment = await guidance.saveAssessment(
    patient.user,
    conversation,
    evaluation,
    true,
    revision,
  );
  await denied(() => guidance.decision(other.user, assessment, "appointment"));
  await guidance.decision(patient.user, assessment, "appointment", appointment);
  check(
    (
      await pool.query(
        "SELECT related_entity_id FROM ai_risk_assessments WHERE id=$1",
        [assessment],
      )
    ).rows[0].related_entity_id === appointment,
  );
  await guidance.savePolicy(supervisor.user, policy);
  check(!(await guidance.policy(patient.user)).enabled);
  await denied(() =>
    guidance.saveAssessment(
      patient.user,
      conversation,
      evaluation,
      true,
      revision,
    ),
  );
  const nextRevision = (await guidance.policy(supervisor.user)).revision;
  await guidance.approvePolicy(
    supervisor.user,
    nextRevision,
    "synthetic revised protocol",
  );
  await pool.query(
    `UPDATE professionals SET verification_status='under_review' WHERE user_id=$1`,
    [supervisor.user.id],
  );
  check(!(await guidance.policy(patient.user)).enabled);
  await pool.query(
    `UPDATE professionals SET verification_status='approved' WHERE user_id=$1`,
    [supervisor.user.id],
  );
  await guidance.savePolicy(supervisor.user, policy);
  const call = (await guidance.requestCall(
    patient.user,
    "Synthetic human orientation",
    assessment,
  )) as { id: string };
  check(
    (await guidance.calls(patient.user)).items.some(
      (item) => item.id === call.id,
    ),
  );
  check(
    !(await guidance.calls(other.user)).items.some(
      (item) => item.id === call.id,
    ),
  );
  await denied(() => guidance.requestCall(patient.user, "Synthetic duplicate"));
  await denied(() =>
    guidance.transitionCall(
      patient.user,
      call.id,
      "assign",
      professionalId,
      undefined,
      meet,
    ),
  );
  await pool.query(
    `UPDATE appointments SET start_at=now()+interval '2 hours',end_at=now()+interval '150 minutes' WHERE id=$1`,
    [appointment],
  );
  check(
    !(await guidance.staff(operator.user)).items.some(
      (item) => item.id === professionalId && item.available === true,
    ),
  );
  await pool.query(
    `INSERT INTO work_shifts(professional_id,assigned_by_user_id,start_at,end_at) VALUES($1,$2,now()-interval '1 hour',now()+interval '1 hour')`,
    [professionalId, supervisor.user.id],
  );
  check(
    (await guidance.staff(operator.user)).items.some(
      (item) => item.id === professionalId && item.available === true,
    ),
  );
  await guidance.transitionCall(
    operator.user,
    call.id,
    "assign",
    professionalId,
    undefined,
    meet,
  );
  check(
    !(await guidance.staff(operator.user)).items.some(
      (item) => item.id === professionalId && item.available === true,
    ),
  );
  failCreate = true;
  await denied(() =>
    guidance.transitionCall(
      doctor.user,
      call.id,
      "start",
      undefined,
      undefined,
      meet,
    ),
  );
  failCreate = false;
  check(
    (
      await pool.query("SELECT status FROM support_call_requests WHERE id=$1", [
        call.id,
      ])
    ).rows[0].status === "assigned",
  );
  await denied(() => guidance.joinCall(patient.user, call.id, meet));
  await guidance.transitionCall(
    doctor.user,
    call.id,
    "start",
    undefined,
    undefined,
    meet,
  );
  check(
    (await guidance.joinCall(patient.user, call.id, meet)).meetingUrl.startsWith(
      "https://meet.google.com/",
    ),
  );
  await denied(() => guidance.joinCall(other.user, call.id, meet));
  await denied(() =>
    guidance.transitionCall(
      doctor.user,
      call.id,
      "complete",
      undefined,
      "",
      meet,
    ),
  );
  await guidance.transitionCall(
    doctor.user,
    call.id,
    "complete",
    undefined,
    "Synthetic attended outcome",
    meet,
  );
  check(
    (await guidance.calls(patient.user)).items.some(
      (item) =>
        item.id === call.id &&
        item.status === "completed" &&
        item.resultNotes === "Synthetic attended outcome",
    ),
  );
  await denied(() => guidance.joinCall(patient.user, call.id, meet));
  const second = (await guidance.requestCall(
    patient.user,
    "Synthetic second call",
  )) as { id: string };
  await guidance.transitionCall(
    operator.user,
    second.id,
    "assign",
    professionalId,
    undefined,
    meet,
  );
  await guidance.transitionCall(
    doctor.user,
    second.id,
    "reject",
    undefined,
    "Synthetic unavailable",
    meet,
  );
  check(
    (await guidance.calls(patient.user)).items.some(
      (item) => item.id === second.id && item.status === "pending",
    ),
  );
  await guidance.transitionCall(
    patient.user,
    second.id,
    "cancel",
    undefined,
    undefined,
    meet,
  );
  const emergencyId = (
    await pool.query(
      `INSERT INTO emergency_events(patient_id,requested_by_user_id,description) VALUES($1,$2,'Synthetic support origin') RETURNING id`,
      [patientId, patient.user.id],
    )
  ).rows[0].id;
  await denied(() =>
    guidance.requestCall(
      other.user,
      "Synthetic foreign emergency",
      undefined,
      emergencyId,
    ),
  );
  const emergencyCall = (await guidance.requestCall(
    patient.user,
    "Synthetic emergency support",
    undefined,
    emergencyId,
  )) as { id: string };
  const emergencyLink = (
    await pool.query(
      `SELECT priority,escalation_type,escalation_reference_id FROM support_call_requests WHERE id=$1`,
      [emergencyCall.id],
    )
  ).rows[0];
  check(
    emergencyLink.priority === "red" &&
      emergencyLink.escalation_type === "emergency" &&
      emergencyLink.escalation_reference_id === emergencyId,
  );
  await guidance.transitionCall(
    patient.user,
    emergencyCall.id,
    "cancel",
    undefined,
    undefined,
    meet,
  );
  await pool.query(
    `UPDATE emergency_events SET status='closed',closed_at=now() WHERE id=$1`,
    [emergencyId],
  );
  await denied(() =>
    guidance.requestCall(
      patient.user,
      "Synthetic closed emergency",
      undefined,
      emergencyId,
    ),
  );
  // Prescription warning and audited patient read. Signing secret is synthetic and never used outside this DB.
  await pool.query(`UPDATE appointments SET status='in_progress' WHERE id=$1`, [
    appointment,
  ]);
  await pool.query(
    `INSERT INTO clinical_notes(appointment_id,patient_id,professional_id,assessment) VALUES($1,$2,$3,'Synthetic only')`,
    [appointment, patientId, professionalId],
  );
  const prescriptions = new PostgresPrescriptionsRepository(database, {
    get: () => "synthetic-local-only",
  } as never);
  const prescription = await prescriptions.createDraft(doctor.user, {
    patientId,
    appointmentId: appointment,
    items: [{ medicationName: "Synthetic medication" }],
  });
  await pool.query(
    `INSERT INTO allergies(patient_id,substance,reaction) VALUES($1,'Synthetic allergy','Synthetic reaction')`,
    [patientId],
  );
  await denied(() => prescriptions.safetyReview(patient.user, prescription.id));
  await denied(() =>
    prescriptions.issue(
      doctor.user,
      prescription.id,
      new Date(Date.now() + 86400000),
    ),
  );
  const safety = await prescriptions.safetyReview(doctor.user, prescription.id);
  check(safety.allergies.length === 1);
  await pool.query(
    `UPDATE allergies SET reaction='Synthetic changed reaction' WHERE patient_id=$1`,
    [patientId],
  );
  await denied(() =>
    prescriptions.issue(
      doctor.user,
      prescription.id,
      new Date(Date.now() + 86400000),
      { fingerprint: safety.fingerprint, reason: "Synthetic review rationale" },
    ),
  );
  const current = await prescriptions.safetyReview(
    doctor.user,
    prescription.id,
  );
  check(
    (
      await prescriptions.issue(
        doctor.user,
        prescription.id,
        new Date(Date.now() + 86400000),
        {
          fingerprint: current.fingerprint,
          reason: "Synthetic review rationale",
        },
      )
    ).status === "issued",
  );
  check(
    (await prescriptions.listForUser(patient.user)).some(
      (item) => item.id === prescription.id,
    ),
  );
  check(
    !(await prescriptions.listForUser(other.user)).some(
      (item) => item.id === prescription.id,
    ),
  );
  check(
    (
      await pool.query(
        `SELECT count(*)::int AS n FROM audit_events WHERE entity_id=$1 AND action='prescription_read' AND actor_user_id=$2`,
        [prescription.id, patient.user.id],
      )
    ).rows[0].n === 1,
  );
  console.log(
    `Phase 3: ${checks} assertions passed under runtime RLS; Meet simulated; clinical rules and records synthetic.`,
  );
}
main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
