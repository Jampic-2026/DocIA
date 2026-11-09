import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { PoolClient, QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import {
  HumanResourcesRepository,
  HumanResourcesResource,
} from "../../domain/ports/human-resources.repository";
import { StaffMember } from "../../domain/staff-member";
import {
  approvalProblems,
  personnelRoles,
  VerificationDocument,
} from "../../domain/professional-verification-policy";

type Row = QueryResultRow & {
  academic_background: string | null;
  public_certifications: string[];
  professional_id: string;
  full_name: string;
  professional_type: string;
  specialty: string | null;
  verification_status: string;
  employee_code: string | null;
  contract_type: string | null;
  employment_status: string | null;
  hired_at: Date | null;
};

@Injectable()
export class PostgresHumanResourcesRepository implements HumanResourcesRepository {
  constructor(private readonly database: DatabaseService) {}

  requirements(user: RequestUser) {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT role_code,document_types,updated_at FROM professional_document_requirements ORDER BY role_code`,
          )
        ).rows,
    );
  }

  configureRequirements(
    user: RequestUser,
    roleCode: string,
    documentTypes: string[],
  ) {
    if (!(personnelRoles as readonly string[]).includes(roleCode))
      throw new BadRequestException("Rol de personal no válido.");
    const normalized = documentTypes.map((type) => type.trim());
    if (
      !normalized.length ||
      normalized.some((type) => type.length < 2 || type.length > 80) ||
      new Set(normalized).size !== normalized.length
    )
      throw new BadRequestException(
        "Indica documentos obligatorios distintos y válidos.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const previous = await client.query(
        `SELECT * FROM professional_document_requirements WHERE role_code=$1 FOR UPDATE`,
        [roleCode],
      );
      const result = await client.query(
        `INSERT INTO professional_document_requirements(role_code,document_types,updated_by_user_id)
        VALUES($1,$2::jsonb,$3) ON CONFLICT(role_code) DO UPDATE SET document_types=EXCLUDED.document_types,
        updated_by_user_id=$3,updated_at=now() RETURNING *`,
        [roleCode, JSON.stringify(normalized), user.id],
      );
      await this.audit(
        client,
        user,
        "professional_requirements_updated",
        "professional_requirements",
        null,
        previous.rows[0] ?? null,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  professionalDocuments(user: RequestUser, professionalId: string) {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT * FROM professional_documents WHERE professional_id=$1 ORDER BY created_at`,
            [professionalId],
          )
        ).rows,
    );
  }

  reviewProfessionalDocument(
    user: RequestUser,
    documentId: string,
    input: Record<string, unknown>,
  ) {
    const observation = String(input.observation ?? "").trim();
    if (input.status === "rejected" && observation.length < 3)
      throw new BadRequestException(
        "Debes indicar la observación del rechazo.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      // Serialize document decisions with professional approval.
      const owner = await client.query(
        `SELECT p.id FROM professionals p JOIN professional_documents d ON d.professional_id=p.id WHERE d.id=$1 FOR UPDATE OF p`,
        [documentId],
      );
      if (!owner.rows[0])
        throw new NotFoundException("El documento no existe.");
      const old = await client.query(
        `SELECT * FROM professional_documents WHERE id=$1 FOR UPDATE`,
        [documentId],
      );
      const result = await client.query(
        `UPDATE professional_documents SET status=$2,reviewed_by_user_id=$3,reviewed_at=now(),observation=NULLIF($4,'') WHERE id=$1 RETURNING *`,
        [documentId, input.status, user.id, observation],
      );
      if (input.status === "rejected") {
        await client.query(
          `UPDATE professionals SET verification_status='under_review',public_profile_enabled=FALSE,verified_at=NULL,updated_at=now() WHERE id=$1`,
          [owner.rows[0].id],
        );
      }
      await this.audit(
        client,
        user,
        "professional_document_reviewed",
        "professional_document",
        documentId,
        old.rows[0],
        result.rows[0],
        observation || null,
      );
      return result.rows[0];
    });
  }

  private async assertDocumentsApproved(
    client: PoolClient,
    roleCode: string,
    documents: VerificationDocument[],
  ) {
    const config = await client.query<{ document_types: string[] }>(
      `SELECT document_types FROM professional_document_requirements WHERE role_code=$1 FOR SHARE`,
      [roleCode],
    );
    const problems = approvalProblems(
      config.rows[0]?.document_types,
      documents,
      new Date().toISOString().slice(0, 10),
    );
    if (problems.length) throw new BadRequestException(problems.join(" "));
  }

  private async approveSpecialty(
    client: PoolClient,
    professionalId: string,
    specialtyId: unknown,
  ) {
    if (!specialtyId)
      throw new BadRequestException(
        "Selecciona la especialidad del catálogo antes de habilitar al médico.",
      );
    const specialty = await client.query(
      `SELECT id FROM specialties WHERE id=$1 AND is_active FOR SHARE`,
      [specialtyId],
    );
    if (!specialty.rows[0])
      throw new BadRequestException("La especialidad no está disponible.");
    await client.query(
      `UPDATE professional_specialties SET is_primary=FALSE WHERE professional_id=$1`,
      [professionalId],
    );
    await client.query(
      `INSERT INTO professional_specialties(professional_id,specialty_id,is_primary) VALUES($1,$2,TRUE)
      ON CONFLICT(professional_id,specialty_id) DO UPDATE SET is_primary=TRUE`,
      [professionalId, specialtyId],
    );
    await client.query(
      `UPDATE professionals SET pending_specialty_id=NULL WHERE id=$1`,
      [professionalId],
    );
  }

  submitApplication(user: RequestUser, input: Record<string, unknown>) {
    const requestedRoleCode = String(input.requestedRoleCode).trim();
    const licenseNumber = String(input.licenseNumber ?? "").trim();
    const requestedSpecialty = String(input.requestedSpecialty ?? "").trim();
    if (licenseNumber.length < 3) {
      throw new BadRequestException("Debes indicar tu matrícula profesional.");
    }
    if (requestedSpecialty.length < 3) {
      throw new BadRequestException("Debes indicar tu especialidad o área.");
    }
    const allowedRoles = [
      "doctor_general",
      "doctor_specialist",
      "nurse",
      "operator",
      "clinical_supervisor",
      "delivery_assistant",
      "human_resources",
    ];
    if (!allowedRoles.includes(requestedRoleCode)) {
      throw new BadRequestException(
        "El rol no admite postulaciones de personal.",
      );
    }
    return this.database.transactionAsUser(user, async (client) => {
      const role = await client.query<{ id: string }>(
        `SELECT id FROM roles WHERE code=$1 AND is_active`,
        [requestedRoleCode],
      );
      if (!role.rows[0])
        throw new BadRequestException("El rol solicitado no está disponible.");
      const duplicate = await client.query(
        `SELECT id FROM personnel_applications
         WHERE applicant_user_id=$1 AND requested_role_code=$2
           AND status IN ('pending','under_review')`,
        [user.id, requestedRoleCode],
      );
      if (duplicate.rows[0]) {
        throw new BadRequestException(
          "Ya tienes una postulación activa para este rol.",
        );
      }
      const result = await client.query(
        `INSERT INTO personnel_applications(
          applicant_user_id,requested_role_code,license_number,requested_specialty
         )
         VALUES($1,$2,$3,$4) RETURNING *`,
        [user.id, requestedRoleCode, licenseNumber, requestedSpecialty],
      );
      await this.audit(
        client,
        user,
        "personnel_application_submitted",
        "personnel_application",
        result.rows[0].id,
        null,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  addApplicationDocument(
    user: RequestUser,
    applicationId: string,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`,
        [applicationId],
      );
      const application = await client.query<{ status: string }>(
        `SELECT status FROM personnel_applications
         WHERE id=$1 AND applicant_user_id=$2`,
        [applicationId, user.id],
      );
      if (!application.rows[0])
        throw new NotFoundException("La postulación no existe.");
      if (!["pending", "under_review"].includes(application.rows[0].status)) {
        throw new BadRequestException(
          "La postulación ya no admite documentos.",
        );
      }
      const result = await client.query(
        `INSERT INTO personnel_documents(application_id,document_type,file_url,valid_until)
         VALUES($1,$2,$3,$4) RETURNING *`,
        [
          applicationId,
          String(input.documentType).trim(),
          String(input.fileUrl).trim(),
          input.validUntil ?? null,
        ],
      );
      await this.audit(
        client,
        user,
        "personnel_document_added",
        "personnel_document",
        result.rows[0].id,
        null,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  reviewApplication(
    user: RequestUser,
    applicationId: string,
    input: Record<string, unknown>,
  ) {
    const status = String(input.status);
    const reason = String(input.reason ?? "").trim();
    if (status === "rejected" && reason.length < 3) {
      throw new BadRequestException("Debes indicar el motivo del rechazo.");
    }
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`,
        [applicationId],
      );
      const found = await client.query<{
        applicant_user_id: string;
        requested_role_code: string;
        license_number: string | null;
        status: string;
      }>(
        `SELECT applicant_user_id,requested_role_code,license_number,status
         FROM personnel_applications WHERE id=$1 FOR UPDATE`,
        [applicationId],
      );
      const application = found.rows[0];
      if (!application)
        throw new NotFoundException("La postulación no existe.");
      if (["approved", "rejected"].includes(application.status)) {
        throw new BadRequestException(
          "La postulación ya tiene una decisión final.",
        );
      }
      if (status === "approved") {
        const documents = await client.query<
          VerificationDocument & QueryResultRow
        >(
          `SELECT document_type,status,valid_until FROM personnel_documents WHERE application_id=$1 FOR UPDATE`,
          [applicationId],
        );
        await this.assertDocumentsApproved(
          client,
          application.requested_role_code,
          documents.rows,
        );
        const person = await client.query<{ id: string }>(
          `SELECT id FROM persons WHERE user_id=$1`,
          [application.applicant_user_id],
        );
        if (!person.rows[0])
          throw new BadRequestException(
            "El postulante no tiene un perfil personal completo.",
          );
        const defaultProfessionalTypes: Record<string, string> = {
          doctor_general: "doctor",
          doctor_specialist: "doctor",
          nurse: "nurse",
          operator: "operator",
          clinical_supervisor: "clinical_supervisor",
          delivery_assistant: "delivery",
          human_resources: "admin",
        };
        const expectedProfessionalType =
          defaultProfessionalTypes[application.requested_role_code];
        if (
          input.professionalType &&
          String(input.professionalType) !== expectedProfessionalType
        ) {
          throw new BadRequestException(
            "El tipo profesional no corresponde al rol solicitado.",
          );
        }
        const professionalType = expectedProfessionalType;
        const professional = await client.query<{ id: string }>(
          `INSERT INTO professionals(user_id,person_id,professional_type,license_number,
             verification_status,verified_at,verified_by_user_id,public_profile_enabled)
           VALUES($1,$2,$3,NULLIF($4,''),'approved',now(),$5,TRUE)
           ON CONFLICT(user_id) DO UPDATE SET professional_type=EXCLUDED.professional_type,
             license_number=COALESCE(EXCLUDED.license_number,professionals.license_number),
             verification_status='approved',verified_at=now(),verified_by_user_id=$5,public_profile_enabled=TRUE,updated_at=now()
           RETURNING id`,
          [
            application.applicant_user_id,
            person.rows[0].id,
            professionalType,
            String(
              input.licenseNumber ?? application.license_number ?? "",
            ).trim(),
            user.id,
          ],
        );
        if (professionalType === "doctor")
          await this.approveSpecialty(
            client,
            professional.rows[0].id,
            input.specialtyId,
          );
        const role = await client.query<{ id: string }>(
          `SELECT id FROM roles WHERE code=$1 AND is_active`,
          [application.requested_role_code],
        );
        if (!role.rows[0])
          throw new BadRequestException(
            "El rol solicitado ya no está disponible.",
          );
        await client.query(
          `INSERT INTO user_roles(user_id,role_id,granted_by_user_id)
           VALUES($1,$2,$3) ON CONFLICT(user_id,role_id) DO UPDATE
           SET granted_by_user_id=$3,valid_from=now(),valid_until=NULL,revoked_at=NULL`,
          [application.applicant_user_id, role.rows[0].id, user.id],
        );
        await client.query(
          `INSERT INTO employment_records(professional_id,employee_code,contract_type,hired_at,metadata)
           VALUES($1,NULLIF($2,''),NULLIF($3,''),COALESCE($4::date,current_date),$5::jsonb)
           ON CONFLICT(professional_id) DO UPDATE SET employee_code=COALESCE(EXCLUDED.employee_code,employment_records.employee_code),
             contract_type=COALESCE(EXCLUDED.contract_type,employment_records.contract_type),
             hired_at=COALESCE(EXCLUDED.hired_at,employment_records.hired_at),ended_at=NULL,status='active',
             metadata=employment_records.metadata || EXCLUDED.metadata,updated_at=now()`,
          [
            professional.rows[0].id,
            String(input.employeeCode ?? "").trim(),
            String(input.contractType ?? "").trim(),
            input.hiredAt ?? null,
            JSON.stringify(input.metadata ?? {}),
          ],
        );
        await client.query(
          `INSERT INTO professional_documents(professional_id,document_type,file_url,status,reviewed_by_user_id,reviewed_at,observation,valid_until)
           SELECT $2,document_type,file_url,'approved',$3,now(),observation,valid_until
           FROM personnel_documents WHERE application_id=$1
           AND NOT EXISTS(SELECT 1 FROM professional_documents pd WHERE pd.professional_id=$2 AND pd.document_type=personnel_documents.document_type AND pd.file_url=personnel_documents.file_url)`,
          [applicationId, professional.rows[0].id, user.id],
        );
      }
      const result = await client.query(
        `UPDATE personnel_applications SET status=$2::varchar,reviewed_by_user_id=$3,
           reviewed_at=CASE WHEN $2::varchar IN ('approved','rejected') THEN now() ELSE reviewed_at END,
           rejection_reason=CASE WHEN $2::varchar='rejected' THEN $4::text ELSE NULL END,updated_at=now()
         WHERE id=$1 RETURNING *`,
        [applicationId, status, user.id, reason || null],
      );
      await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status)
         VALUES($1,'personnel_application_reviewed','in_app','Actualización de tu postulación',$2,
           'personnel_application',$3,'sent')`,
        [
          application.applicant_user_id,
          status === "approved"
            ? "Tu incorporación fue aprobada."
            : status === "rejected"
              ? `Tu postulación fue rechazada: ${reason}`
              : "Tu postulación está en revisión.",
          applicationId,
        ],
      );
      await this.audit(
        client,
        user,
        `personnel_application_${status}`,
        "personnel_application",
        applicationId,
        { status: application.status },
        result.rows[0],
        reason || null,
      );
      return result.rows[0];
    });
  }

  reviewDocument(
    user: RequestUser,
    documentId: string,
    input: Record<string, unknown>,
  ) {
    const status = String(input.status);
    const observation = String(input.observation ?? "").trim();
    if (status === "rejected" && observation.length < 3)
      throw new BadRequestException(
        "Debes indicar la observación del rechazo.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const application = await client.query(
        `SELECT a.id,a.status FROM personnel_applications a JOIN personnel_documents d ON d.application_id=a.id WHERE d.id=$1 FOR UPDATE OF a`,
        [documentId],
      );
      if (!application.rows[0])
        throw new NotFoundException("El documento no existe.");
      if (["approved", "rejected"].includes(application.rows[0].status))
        throw new BadRequestException(
          "La postulación ya tiene una decisión final.",
        );
      const old = await client.query(
        `SELECT * FROM personnel_documents WHERE id=$1 FOR UPDATE`,
        [documentId],
      );
      if (!old.rows[0]) throw new NotFoundException("El documento no existe.");
      const result = await client.query(
        `UPDATE personnel_documents SET status=$2,reviewed_by_user_id=$3,reviewed_at=now(),observation=NULLIF($4,'') WHERE id=$1 RETURNING *`,
        [documentId, status, user.id, observation],
      );
      await this.audit(
        client,
        user,
        "personnel_document_reviewed",
        "personnel_document",
        documentId,
        old.rows[0],
        result.rows[0],
        observation || null,
      );
      return result.rows[0];
    });
  }

  updateEmploymentRecord(
    user: RequestUser,
    recordId: string,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const old = await client.query(
        `SELECT * FROM employment_records WHERE id=$1 FOR UPDATE`,
        [recordId],
      );
      if (!old.rows[0])
        throw new NotFoundException("El expediente laboral no existe.");
      const result = await client.query(
        `UPDATE employment_records SET employee_code=COALESCE(NULLIF($2,''),employee_code),
           contract_type=COALESCE(NULLIF($3,''),contract_type),hired_at=COALESCE($4::date,hired_at),
           ended_at=CASE WHEN $6='active' THEN NULL
             WHEN $6='ended' THEN COALESCE($5::date,ended_at,current_date)
             ELSE COALESCE($5::date,ended_at) END,
           status=COALESCE($6,status),metadata=metadata || $7::jsonb,updated_at=now()
         WHERE id=$1 RETURNING *`,
        [
          recordId,
          String(input.employeeCode ?? ""),
          String(input.contractType ?? ""),
          input.hiredAt ?? null,
          input.endedAt ?? null,
          input.status ?? null,
          JSON.stringify(input.metadata ?? {}),
        ],
      );
      await this.audit(
        client,
        user,
        "employment_record_updated",
        "employment_record",
        recordId,
        old.rows[0],
        result.rows[0],
        String(input.reason),
      );
      return result.rows[0];
    });
  }

  createObservation(user: RequestUser, input: Record<string, unknown>) {
    return this.database.transactionAsUser(user, async (client) => {
      const professionalId = String(input.professionalId);
      const exists = await client.query(
        `SELECT id FROM professionals WHERE id=$1`,
        [professionalId],
      );
      if (!exists.rows[0])
        throw new NotFoundException("El profesional no existe.");
      const result = await client.query(
        `INSERT INTO personnel_observations(professional_id,registered_by_user_id,observation_type,description,action_taken,is_confidential)
         VALUES($1,$2,$3,$4,NULLIF($5,''),$6) RETURNING *`,
        [
          professionalId,
          user.id,
          String(input.observationType).trim(),
          String(input.description).trim(),
          String(input.actionTaken ?? "").trim(),
          input.isConfidential ?? true,
        ],
      );
      await this.audit(
        client,
        user,
        "personnel_observation_created",
        "personnel_observation",
        result.rows[0].id,
        null,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  report(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => {
      const [applications, employment, documents, observations] =
        await Promise.all([
          client.query(
            `SELECT status,count(*)::int AS total FROM personnel_applications GROUP BY status ORDER BY status`,
          ),
          client.query(
            `SELECT status,count(*)::int AS total FROM employment_records GROUP BY status ORDER BY status`,
          ),
          client.query(
            `SELECT status,count(*)::int AS total FROM personnel_documents GROUP BY status ORDER BY status`,
          ),
          client.query(
            `SELECT observation_type,count(*)::int AS total FROM personnel_observations GROUP BY observation_type ORDER BY observation_type`,
          ),
        ]);
      return {
        applications: applications.rows,
        employment: employment.rows,
        documents: documents.rows,
        observations: observations.rows,
      };
    });
  }

  auditEvents(user: RequestUser) {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT id,actor_user_id,actor_role,action,entity_type,entity_id,old_values,new_values,reason,created_at
         FROM audit_events WHERE module='human_resources' ORDER BY created_at DESC LIMIT 200`,
          )
        ).rows,
    );
  }

  private async audit(
    client: { query: (text: string, values?: unknown[]) => Promise<unknown> },
    user: RequestUser,
    action: string,
    entityType: string,
    entityId: string | null,
    oldValues: unknown,
    newValues: unknown,
    reason: string | null = null,
  ) {
    await client.query(
      `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,old_values,new_values,reason)
       VALUES($1,$2,'human_resources',$3,$4,$5,$6::jsonb,$7::jsonb,$8)`,
      [
        user.id,
        user.roleCode,
        action,
        entityType,
        entityId,
        oldValues ? JSON.stringify(oldValues) : null,
        newValues ? JSON.stringify(newValues) : null,
        reason,
      ],
    );
  }

  listStaff(user: RequestUser): Promise<StaffMember[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<Row>(
        `SELECT professional.id AS professional_id,
          concat_ws(' ',person.first_name,person.last_name,
            person.second_last_name) AS full_name,
          professional.academic_background,professional.public_certifications,professional.professional_type, specialty.name AS specialty,
          professional.verification_status, employment.employee_code,
          employment.contract_type, employment.status AS employment_status,
          employment.hired_at
         FROM professionals professional
         JOIN persons person ON person.id=professional.person_id
         LEFT JOIN employment_records employment
           ON employment.professional_id=professional.id
         LEFT JOIN professional_specialties ps
           ON ps.professional_id=professional.id AND ps.is_primary
         LEFT JOIN specialties specialty ON specialty.id=ps.specialty_id
         ORDER BY full_name`,
      );
      return result.rows.map((row) => ({
        academicBackground: row.academic_background,
        certifications: row.public_certifications,
        professionalId: row.professional_id,
        fullName: row.full_name,
        professionalType: row.professional_type,
        specialty: row.specialty,
        verificationStatus: row.verification_status,
        employeeCode: row.employee_code,
        contractType: row.contract_type,
        employmentStatus: row.employment_status,
        hiredAt: row.hired_at,
      }));
    });
  }

  reviewProfessional(
    user: RequestUser,
    professionalId: string,
    input: {
      status: "approved" | "rejected";
      reason?: string;
      roleCode?: string;
      specialtyId?: string;
    },
  ): Promise<void> {
    if (input.status === "rejected" && !input.reason?.trim()) {
      throw new BadRequestException("Debes indicar el motivo del rechazo.");
    }
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{
        user_id: string;
        verification_status: string;
        professional_type: string;
        pending_specialty_id: string | null;
      }>(
        `SELECT user_id, verification_status, professional_type, pending_specialty_id
         FROM professionals WHERE id=$1 FOR UPDATE`,
        [professionalId],
      );
      const professional = result.rows[0];
      if (!professional) {
        throw new NotFoundException("El profesional no existe.");
      }
      if (input.status === "approved") {
        const roleCode = input.roleCode;
        const types: Record<string, string> = {
          doctor_general: "doctor",
          doctor_specialist: "doctor",
          nurse: "nurse",
          operator: "operator",
          clinical_supervisor: "clinical_supervisor",
          delivery_assistant: "delivery",
          human_resources: "admin",
        };
        if (!roleCode || types[roleCode] !== professional.professional_type)
          throw new BadRequestException(
            "Selecciona un rol correspondiente al tipo profesional.",
          );
        const documents = await client.query<
          VerificationDocument & QueryResultRow
        >(
          `SELECT document_type,status,valid_until FROM professional_documents WHERE professional_id=$1 FOR UPDATE`,
          [professionalId],
        );
        await this.assertDocumentsApproved(client, roleCode, documents.rows);
        if (professional.professional_type === "doctor") {
          const current = await client.query<{ specialty_id: string }>(
            `SELECT specialty_id FROM professional_specialties WHERE professional_id=$1 AND is_primary`,
            [professionalId],
          );
          await this.approveSpecialty(
            client,
            professionalId,
            input.specialtyId ??
              professional.pending_specialty_id ??
              current.rows[0]?.specialty_id,
          );
        }
        const grantedRole = await client.query(
          `INSERT INTO user_roles(user_id,role_id,granted_by_user_id)
          SELECT $1,id,$3 FROM roles WHERE code=$2 AND is_active
          ON CONFLICT(user_id,role_id) DO UPDATE SET valid_from=now(),valid_until=NULL,revoked_at=NULL,granted_by_user_id=$3`,
          [professional.user_id, roleCode, user.id],
        );
        if (!grantedRole.rowCount)
          throw new BadRequestException("El rol no est\u00e1 activo.");
      }

      const reviewedAt = new Date();
      const reason = input.reason?.trim() ?? "";
      await client.query(
        `UPDATE professionals SET verification_status=$2::professional_verification_status, verified_at=$3,
          verified_by_user_id=$4, public_profile_enabled=($2::text='approved'),
          updated_at=now() WHERE id=$1`,
        [professionalId, input.status, reviewedAt, user.id],
      );
      await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status)
        VALUES($1,'professional_verification_reviewed','in_app','Revisión profesional',$2,'professional',$3,'sent')`,
        [
          professional.user_id,
          input.status === "approved"
            ? "Tu habilitación profesional fue aprobada."
            : `Tu habilitación fue rechazada: ${reason}`,
          professionalId,
        ],
      );
      await client.query(
        `INSERT INTO audit_events(
          actor_user_id, actor_role, module, action, entity_type, entity_id,
          old_values, new_values, reason
         ) VALUES(
          $1,$2,'human_resources','professional_verification_reviewed',
          'professional',$3,jsonb_build_object('status',$4::text),
          jsonb_build_object('status',$5::text),NULLIF($6,'')
         )`,
        [
          user.id,
          user.roleCode,
          professionalId,
          professional.verification_status,
          input.status,
          reason,
        ],
      );
    });
  }
  resource(
    user: RequestUser,
    resource: HumanResourcesResource,
  ): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      if (resource === "personnel_applications") {
        return (
          await client.query(
            `SELECT application.*,
              concat_ws(' ',person.first_name,person.last_name,
                person.second_last_name) AS applicant_name,
              app_user.email AS applicant_email
             FROM personnel_applications application
             JOIN users app_user ON app_user.id=application.applicant_user_id
             LEFT JOIN persons person ON person.user_id=app_user.id
             ORDER BY application.submitted_at DESC
             LIMIT 200`,
          )
        ).rows;
      }
      if (resource === "personnel_documents") {
        return (
          await client.query(
            `SELECT document.*
             FROM personnel_documents document
             ORDER BY document.created_at DESC
             LIMIT 200`,
          )
        ).rows;
      }
      return (
        await client.query(
          `SELECT * FROM personnel_observations ORDER BY created_at DESC LIMIT 200`,
        )
      ).rows;
    });
  }
}
