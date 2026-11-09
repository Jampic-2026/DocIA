import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { PartnerSummary } from "../../domain/partner-summary";
import {
  PartnerResource,
  PartnersRepository,
  SubscriptionPlanInput,
} from "../../domain/ports/partners.repository";
type Row = QueryResultRow & {
  id: string;
  name: string;
  partner_type: string;
  tax_id: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  is_active: boolean;
  subscription_status: string | null;
  plan_name: string | null;
  site_count: string;
};
@Injectable()
export class PostgresPartnersRepository implements PartnersRepository {
  constructor(private readonly database: DatabaseService) {}
  list(user: RequestUser): Promise<PartnerSummary[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result =
        await client.query<Row>(`SELECT partner.id,partner.name,partner.partner_type,
    partner.tax_id,partner.phone,partner.email,partner.address,partner.is_active,
    subscription.status AS subscription_status,plan.name AS plan_name,
    count(DISTINCT site.id)::text AS site_count
    FROM health_partners partner LEFT JOIN LATERAL(SELECT current_subscription.*
      FROM partner_subscriptions current_subscription WHERE current_subscription.partner_id=partner.id
      ORDER BY current_subscription.created_at DESC LIMIT 1) subscription ON true
    LEFT JOIN partner_subscription_plans plan ON plan.id=subscription.plan_id
    LEFT JOIN operating_sites site ON site.partner_id=partner.id
    GROUP BY partner.id,subscription.status,plan.name ORDER BY partner.name`);
      return result.rows.map((row) => ({
        id: row.id,
        name: row.name,
        partnerType: row.partner_type,
        taxId: row.tax_id,
        phone: row.phone,
        email: row.email,
        address: row.address,
        isActive: row.is_active,
        subscriptionStatus: row.subscription_status,
        planName: row.plan_name,
        siteCount: Number(row.site_count),
      }));
    });
  }
  resource(user: RequestUser, resource: PartnerResource): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const tables: Record<PartnerResource, string> = {
        partner_subscription_plans: "partner_subscription_plans",
        partner_plan_benefits: "partner_plan_benefits",
        partner_subscriptions: "partner_subscriptions",
        partner_subscription_usage: "partner_subscription_usage",
        partner_users: "partner_users",
        partner_documents: "partner_documents",
        operating_sites: "operating_sites",
        coverage_zones: "coverage_zones",
        partner_catalog_items: "partner_catalog_items",
        partner_requests: "partner_requests",
        partner_request_items: "partner_request_items",
        diagnostic_orders: "diagnostic_orders",
      };
      if (resource === "diagnostic_orders")
        return (
          await client.query(
            "SELECT diagnostic.*,document.file_url AS result_file_url FROM diagnostic_orders diagnostic LEFT JOIN clinical_documents document ON document.id=diagnostic.result_document_id ORDER BY diagnostic.created_at DESC LIMIT 200",
          )
        ).rows;
      return (await client.query(`SELECT * FROM ${tables[resource]} LIMIT 200`))
        .rows;
    });
  }

  createPlan(
    user: RequestUser,
    input: SubscriptionPlanInput,
  ): Promise<unknown> {
    return this.savePlan(user, null, input);
  }

  updatePlan(
    user: RequestUser,
    id: string,
    input: SubscriptionPlanInput,
  ): Promise<unknown> {
    return this.savePlan(user, id, input);
  }

  createSubscription(
    user: RequestUser,
    input: {
      partnerId: string;
      planId: string;
      payerUserId: string;
      autoRenew?: boolean;
    },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const plan = await client.query<{
        name: string;
        price: string;
        currency: string;
      }>(
        `SELECT plan.name,plan.price::text,plan.currency
         FROM partner_subscription_plans plan
         JOIN partner_users partner_user ON partner_user.partner_id=$1
           AND partner_user.user_id=$3 AND partner_user.is_active
         WHERE plan.id=$2 AND plan.is_active`,
        [input.partnerId, input.planId, input.payerUserId],
      );
      if (!plan.rows[0])
        throw new NotFoundException(
          "Plan o responsable empresarial no válidos.",
        );
      const active = await client.query(
        `SELECT id FROM partner_subscriptions WHERE partner_id=$1
         AND status IN('pending_payment','active','grace_period') LIMIT 1`,
        [input.partnerId],
      );
      if (active.rows[0])
        throw new ConflictException(
          "La empresa ya tiene una suscripción vigente o pendiente.",
        );
      const order = await client.query<{ id: string }>(
        `INSERT INTO payment_orders(user_id,related_entity_type,related_entity_id,concept,charge_mode,amount,currency,status,due_at)
         VALUES($1,'partner_subscription',$2,$3,'fiat',$4,$5,'pending',now()+interval '5 days') RETURNING id`,
        [
          input.payerUserId,
          input.partnerId,
          `Suscripción empresarial ${plan.rows[0].name}`,
          plan.rows[0].price,
          plan.rows[0].currency,
        ],
      );
      const subscription = await client.query(
        `INSERT INTO partner_subscriptions(partner_id,plan_id,payment_order_id,status,auto_renew)
         VALUES($1,$2,$3,'pending_payment',$4)
         RETURNING id,partner_id AS "partnerId",plan_id AS "planId",payment_order_id AS "paymentOrderId",status,auto_renew AS "autoRenew"`,
        [
          input.partnerId,
          input.planId,
          order.rows[0].id,
          input.autoRenew ?? false,
        ],
      );
      await client.query(
        `UPDATE payment_orders SET related_entity_id=$2 WHERE id=$1`,
        [order.rows[0].id, subscription.rows[0].id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values) VALUES($1,$2,'partners','subscription_created','partner_subscription',$3,$4::jsonb)`,
        [
          user.id,
          user.roleCode,
          subscription.rows[0].id,
          JSON.stringify(subscription.rows[0]),
        ],
      );
      return {
        ...subscription.rows[0],
        amount: Number(plan.rows[0].price),
        currency: plan.rows[0].currency,
      };
    });
  }

  setPlanBenefit(
    user: RequestUser,
    planId: string,
    input: { benefitId: string; usageLimit?: number; period?: string },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO partner_plan_benefits(plan_id,benefit_id,usage_limit,period) SELECT $1,$2,$3,NULLIF($4,'') FROM partner_subscription_plans plan JOIN benefits benefit ON benefit.id=$2 WHERE plan.id=$1 ON CONFLICT(plan_id,benefit_id) DO UPDATE SET usage_limit=excluded.usage_limit,period=excluded.period RETURNING plan_id AS "planId",benefit_id AS "benefitId",usage_limit AS "usageLimit",period`,
        [
          planId,
          input.benefitId,
          input.usageLimit ?? null,
          input.period?.trim() ?? "",
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("Plan o beneficio no encontrado.");
      await this.auditPartner(
        client,
        user,
        "plan_benefit_set",
        "partner_subscription_plan",
        planId,
        result.rows[0],
      );
      return result.rows[0];
    });
  }
  removePlanBenefit(
    user: RequestUser,
    planId: string,
    benefitId: string,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `DELETE FROM partner_plan_benefits WHERE plan_id=$1 AND benefit_id=$2 RETURNING *`,
        [planId, benefitId],
      );
      if (!result.rows[0])
        throw new NotFoundException("Beneficio no asociado al plan.");
      await this.auditPartner(
        client,
        user,
        "plan_benefit_removed",
        "partner_subscription_plan",
        planId,
        { benefitId },
      );
      return { removed: true };
    });
  }
  cancelSubscription(
    user: RequestUser,
    id: string,
    reason: string,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE partner_subscriptions SET status='cancelled',cancelled_at=now(),cancellation_reason=$2,updated_at=now() WHERE id=$1 AND status IN('pending_payment','active','grace_period') RETURNING id,payment_order_id`,
        [id, reason.trim()],
      );
      if (!result.rows[0])
        throw new ConflictException("La suscripción no admite cancelación.");
      await client.query(
        `UPDATE payment_orders SET status='cancelled',updated_at=now() WHERE id=$1 AND status IN('pending','accepted')`,
        [result.rows[0].payment_order_id],
      );
      await this.auditPartner(
        client,
        user,
        "subscription_cancelled",
        "partner_subscription",
        id,
        { status: "cancelled", reason: reason.trim() },
      );
      return { id, status: "cancelled" };
    });
  }
  renewSubscription(
    user: RequestUser,
    id: string,
    input: { payerUserId: string; autoRenew?: boolean },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) =>
      this.createRenewal(client, user, id, input.payerUserId, input.autoRenew),
    );
  }
  recordUsage(
    user: RequestUser,
    id: string,
    input: {
      featureCode: string;
      quantity: number;
      periodStart?: string;
      periodEnd?: string;
    },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const subscription = await client.query<{
        limits: Record<string, unknown>;
      }>(
        `SELECT plan.limits FROM partner_subscriptions subscription JOIN partner_subscription_plans plan ON plan.id=subscription.plan_id WHERE subscription.id=$1 AND subscription.starts_at<=now() AND((subscription.status='active' AND subscription.ends_at>now())OR(subscription.status='grace_period' AND subscription.grace_period_ends_at>now())) FOR UPDATE OF subscription`,
        [id],
      );
      if (!subscription.rows[0])
        throw new ConflictException("La suscripción no está vigente.");
      const start =
        input.periodStart ?? new Date().toISOString().slice(0, 7) + "-01";
      const end =
        input.periodEnd ??
        new Date(
          new Date(start + "T00:00:00Z").setUTCMonth(
            new Date(start + "T00:00:00Z").getUTCMonth() + 1,
          ),
        )
          .toISOString()
          .slice(0, 10);
      const current = await client.query<{ used_quantity: string }>(
        `SELECT used_quantity::text FROM partner_subscription_usage WHERE subscription_id=$1 AND feature_code=$2 AND period_start=$3::date FOR UPDATE`,
        [id, input.featureCode, start],
      );
      const used = Number(current.rows[0]?.used_quantity ?? 0);
      const limitValue = subscription.rows[0].limits[input.featureCode];
      const limit = limitValue == null ? null : Number(limitValue);
      if (
        limit != null &&
        (!Number.isFinite(limit) || used + input.quantity > limit)
      )
        throw new ConflictException("El consumo supera el límite del plan.");
      const result = await client.query(
        `INSERT INTO partner_subscription_usage(subscription_id,feature_code,period_start,period_end,used_quantity) VALUES($1,$2,$3::date,$4::date,$5) ON CONFLICT(subscription_id,feature_code,period_start) DO UPDATE SET used_quantity=partner_subscription_usage.used_quantity+excluded.used_quantity,period_end=excluded.period_end,updated_at=now() RETURNING id,subscription_id AS "subscriptionId",feature_code AS "featureCode",period_start AS "periodStart",period_end AS "periodEnd",used_quantity AS "usedQuantity"`,
        [id, input.featureCode, start, end, input.quantity],
      );
      await this.auditPartner(
        client,
        user,
        "subscription_usage_recorded",
        "partner_subscription",
        id,
        result.rows[0],
      );
      return result.rows[0];
    });
  }
  processSubscriptionLifecycle(user: RequestUser): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtext('partner-subscription-maintenance'))`,
      );
      const setting = await client.query<{ days: string }>(
        `SELECT COALESCE((value #>> '{}')::int,7)::text AS days FROM system_settings WHERE setting_key='partners.grace_period_days'`,
      );
      const days = Number(setting.rows[0]?.days ?? 7);
      const automaticRenewals = await client.query<{
        id: string;
        payer_user_id: string;
      }>(
        `SELECT subscription.id,payment_order.user_id AS payer_user_id
         FROM partner_subscriptions subscription
         JOIN payment_orders payment_order ON payment_order.id=subscription.payment_order_id
         WHERE subscription.status='active' AND subscription.auto_renew
           AND subscription.ends_at>now()
           AND subscription.ends_at<=now()+interval '7 days'
           AND NOT EXISTS(
             SELECT 1 FROM partner_subscriptions pending
             WHERE pending.partner_id=subscription.partner_id
               AND pending.status='pending_payment'
           )
         ORDER BY subscription.ends_at FOR UPDATE OF subscription`,
      );
      for (const renewal of automaticRenewals.rows)
        await this.createRenewal(
          client,
          user,
          renewal.id,
          renewal.payer_user_id,
          true,
        );
      const superseded = await client.query<{ id: string; partner_id: string }>(
        `UPDATE partner_subscriptions current_subscription SET status='expired',updated_at=now()
         WHERE current_subscription.status='active' AND current_subscription.ends_at<=now()
           AND EXISTS(
             SELECT 1 FROM partner_subscriptions successor
             WHERE successor.partner_id=current_subscription.partner_id
               AND successor.id<>current_subscription.id
               AND successor.status='active' AND successor.starts_at<=now()
               AND successor.ends_at>now()
           ) RETURNING current_subscription.id,current_subscription.partner_id`,
      );
      const grace = await client.query<{ id: string; partner_id: string }>(
        `UPDATE partner_subscriptions SET status='grace_period',grace_period_ends_at=now()+($1::text||' days')::interval,updated_at=now() WHERE status='active' AND ends_at<=now() RETURNING id,partner_id`,
        [days],
      );
      const expired = await client.query<{ id: string; partner_id: string }>(
        `UPDATE partner_subscriptions SET status='expired',updated_at=now() WHERE status='grace_period' AND grace_period_ends_at<=now() RETURNING id,partner_id`,
      );
      const unpaid = await client.query<{ id: string; partner_id: string }>(
        `UPDATE partner_subscriptions subscription SET status='expired',updated_at=now() FROM payment_orders payment_order WHERE subscription.payment_order_id=payment_order.id AND subscription.status='pending_payment' AND payment_order.status='expired' RETURNING subscription.id,subscription.partner_id`,
      );
      for (const row of [
        ...superseded.rows,
        ...grace.rows,
        ...expired.rows,
        ...unpaid.rows,
      ]) {
        const status = grace.rows.some((item) => item.id === row.id)
          ? "grace_period"
          : "expired";
        await this.notifyPartnerUsers(
          client,
          row.partner_id,
          status === "grace_period"
            ? "subscription.grace_period"
            : "subscription.expired",
          status === "grace_period"
            ? "Suscripción en periodo de gracia"
            : "Suscripción vencida",
          status === "grace_period"
            ? `La suscripción entró en un periodo de gracia de ${days} días.`
            : "La suscripción empresarial venció.",
          row.id,
        );
        await this.auditPartner(
          client,
          user,
          status === "grace_period"
            ? "subscription_grace_started"
            : "subscription_expired",
          "partner_subscription",
          row.id,
          { status },
        );
      }
      return {
        renewalsCreated: automaticRenewals.rowCount ?? 0,
        gracePeriodStarted: grace.rowCount ?? 0,
        expired:
          (superseded.rowCount ?? 0) +
          (expired.rowCount ?? 0) +
          (unpaid.rowCount ?? 0),
      };
    });
  }

  createPartner(user: RequestUser, input: Record<string, unknown>) {
    return this.savePartner(user, null, input);
  }
  updatePartner(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.savePartner(user, id, input);
  }
  private savePartner(
    user: RequestUser,
    id: string | null,
    input: Record<string, unknown>,
  ) {
    if (!user.roles.includes("admin"))
      throw new ForbiddenException(
        "Sólo administración puede gestionar aliados.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const old = id
        ? (
            await client.query(
              `SELECT * FROM health_partners WHERE id=$1 FOR UPDATE`,
              [id],
            )
          ).rows[0]
        : null;
      if (id && !old)
        throw new NotFoundException("La empresa o aliado no existe.");
      const values = [
        String(input.name).trim(),
        input.partnerType,
        String(input.taxId ?? "").trim(),
        String(input.phone ?? "").trim(),
        String(input.email ?? "")
          .trim()
          .toLowerCase(),
        String(input.address ?? "").trim(),
        input.latitude ?? null,
        input.longitude ?? null,
        input.isActive ?? true,
      ];
      const result = id
        ? await client.query(
            `UPDATE health_partners SET name=$2,partner_type=$3,tax_id=NULLIF($4,''),phone=NULLIF($5,''),email=NULLIF($6,''),address=NULLIF($7,''),latitude=$8,longitude=$9,is_active=$10,updated_at=now() WHERE id=$1 RETURNING *`,
            [id, ...values],
          )
        : await client.query(
            `INSERT INTO health_partners(name,partner_type,tax_id,phone,email,address,latitude,longitude,is_active) VALUES($1,$2,NULLIF($3,''),NULLIF($4,''),NULLIF($5,''),NULLIF($6,''),$7,$8,$9) RETURNING *`,
            values,
          );
      await this.auditPartner(
        client,
        user,
        id ? "partner_updated" : "partner_created",
        "health_partner",
        result.rows[0].id,
        { old, new: result.rows[0], reason: input.reason },
      );
      return result.rows[0];
    });
  }

  addDocument(
    user: RequestUser,
    partnerId: string,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const partner = await client.query(
        `SELECT partner.id FROM health_partners partner WHERE partner.id=$1 AND (app_has_role('admin') OR EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=partner.id AND partner_user.user_id=$2 AND partner_user.is_active))`,
        [partnerId, user.id],
      );
      if (!partner.rows[0])
        throw new NotFoundException(
          "El aliado no existe o no tienes autorización.",
        );
      const result = await client.query(
        `INSERT INTO partner_documents(partner_id,document_type,document_number,file_url,valid_until) VALUES($1,$2,NULLIF($3,''),$4,$5::date) RETURNING *`,
        [
          partnerId,
          String(input.documentType).trim(),
          String(input.documentNumber ?? "").trim(),
          String(input.fileUrl).trim(),
          input.validUntil ?? null,
        ],
      );
      await this.auditPartner(
        client,
        user,
        "partner_document_added",
        "partner_document",
        result.rows[0].id,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  reviewDocument(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      if (!user.roles.includes("admin"))
        throw new ForbiddenException(
          "Sólo administración puede revisar documentos del aliado.",
        );
      const old = await client.query(
        `SELECT * FROM partner_documents WHERE id=$1 FOR UPDATE`,
        [id],
      );
      if (!old.rows[0]) throw new NotFoundException("El documento no existe.");
      if (
        input.status === "rejected" &&
        !String(input.observation ?? "").trim()
      )
        throw new ConflictException("Debes indicar el motivo del rechazo.");
      const result = await client.query(
        `UPDATE partner_documents SET status=$2,reviewed_by_user_id=$3,reviewed_at=now(),observation=NULLIF($4,'') WHERE id=$1 RETURNING *`,
        [id, input.status, user.id, String(input.observation ?? "").trim()],
      );
      await this.auditPartner(
        client,
        user,
        "partner_document_reviewed",
        "partner_document",
        id,
        { old: old.rows[0], new: result.rows[0] },
      );
      return result.rows[0];
    });
  }

  assignUser(
    user: RequestUser,
    partnerId: string,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      if (!user.roles.includes("admin"))
        throw new ForbiddenException(
          "Sólo administración puede asignar responsables empresariales.",
        );
      const result = await client.query(
        `INSERT INTO partner_users(partner_id,user_id,partner_role,is_active) SELECT $1,$2,$3,$4 FROM health_partners partner JOIN users ON users.id=$2 WHERE partner.id=$1 ON CONFLICT(partner_id,user_id) DO UPDATE SET partner_role=excluded.partner_role,is_active=excluded.is_active RETURNING *`,
        [
          partnerId,
          input.userId,
          String(input.partnerRole).trim(),
          input.isActive ?? true,
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("El aliado o usuario no existe.");
      if (input.isActive ?? true) {
        await client.query(
          `INSERT INTO user_roles(user_id,role_id,granted_by_user_id)
           SELECT $1,role.id,$2 FROM roles role WHERE role.code='health_partner'
           ON CONFLICT(user_id,role_id) DO UPDATE SET revoked_at=NULL,
             valid_from=now(),valid_until=NULL,granted_by_user_id=$2`,
          [input.userId, user.id],
        );
      } else {
        await client.query(
          `UPDATE user_roles assignment SET revoked_at=now()
           FROM roles role WHERE assignment.user_id=$1
             AND assignment.role_id=role.id AND role.code='health_partner'
             AND NOT EXISTS(SELECT 1 FROM partner_users membership
               WHERE membership.user_id=$1 AND membership.is_active)`,
          [input.userId],
        );
      }
      await this.auditPartner(
        client,
        user,
        "partner_user_assigned",
        "partner_user",
        partnerId,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  createRequest(user: RequestUser, input: Record<string, unknown>) {
    return this.database.transactionAsUser(user, async (client) => {
      const patient = await client.query<{ id: string }>(
        `SELECT patient.id FROM patients patient JOIN persons person ON person.id=patient.person_id WHERE person.user_id=$1`,
        [user.id],
      );
      if (!patient.rows[0])
        throw new NotFoundException(
          "La cuenta no tiene un perfil de paciente.",
        );
      const request = await client.query<{ id: string }>(
        `INSERT INTO partner_requests(patient_id,requested_by_user_id,partner_id,prescription_id,status,notes) VALUES($1,$2,$3,$4,'draft',NULLIF($5,'')) RETURNING id`,
        [
          patient.rows[0].id,
          user.id,
          input.partnerId ?? null,
          input.prescriptionId ?? null,
          String(input.notes ?? "").trim(),
        ],
      );
      const items = input.items as Array<Record<string, unknown>>;
      for (const item of items)
        await client.query(
          `INSERT INTO partner_request_items(request_id,catalog_item_id,prescription_item_id,description,quantity) VALUES($1,$2,$3,$4,$5)`,
          [
            request.rows[0].id,
            item.catalogItemId ?? null,
            item.prescriptionItemId ?? null,
            String(item.description).trim(),
            item.quantity,
          ],
        );
      await this.auditPartner(
        client,
        user,
        "partner_request_created",
        "partner_request",
        request.rows[0].id,
        { status: "draft", itemCount: items.length },
      );
      return {
        id: request.rows[0].id,
        status: "draft",
        itemCount: items.length,
      };
    });
  }

  confirmRequest(user: RequestUser, id: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE partner_requests SET status='pending',confirmed_at=now(),updated_at=now() WHERE id=$1 AND requested_by_user_id=$2 AND status='draft' AND partner_id IS NOT NULL RETURNING *`,
        [id, user.id],
      );
      if (!result.rows[0])
        throw new NotFoundException(
          "La solicitud no existe, no tiene aliado seleccionado o ya fue confirmada.",
        );
      await this.notifyPartnerUsers(
        client,
        result.rows[0].partner_id,
        "partner.request.received",
        "Nueva solicitud",
        "Existe una nueva solicitud pendiente de respuesta.",
        id,
      );
      await this.auditPartner(
        client,
        user,
        "partner_request_confirmed",
        "partner_request",
        id,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  respondRequest(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE partner_requests request SET status=$3::generic_request_status,partner_response_at=now(),rejection_reason=CASE WHEN $3='rejected' THEN NULLIF($4,'') ELSE NULL END,updated_at=now() FROM partner_users partner_user WHERE request.id=$1 AND partner_user.partner_id=request.partner_id AND partner_user.user_id=$2 AND partner_user.is_active AND request.status='pending' RETURNING request.*`,
        [id, user.id, input.status, String(input.reason ?? "").trim()],
      );
      if (!result.rows[0])
        throw new NotFoundException(
          "La solicitud no está disponible para responder.",
        );
      if (input.status === "rejected" && !String(input.reason ?? "").trim())
        throw new ConflictException("Debes indicar el motivo del rechazo.");
      await client.query(
        `UPDATE partner_request_items SET availability_status=$2 WHERE request_id=$1`,
        [id, input.status === "accepted" ? "available" : "rejected"],
      );
      await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at) VALUES($1,'partner.request.responded','in_app','Respuesta del aliado',$2,'partner_request',$3,'sent',now())`,
        [
          result.rows[0].requested_by_user_id,
          input.status === "accepted"
            ? "El aliado confirmó la disponibilidad."
            : `El aliado rechazó la solicitud: ${String(input.reason)}`,
          id,
        ],
      );
      await this.auditPartner(
        client,
        user,
        "partner_request_responded",
        "partner_request",
        id,
        { status: input.status, reason: input.reason },
      );
      return result.rows[0];
    });
  }

  createDiagnosticOrder(user: RequestUser, input: Record<string, unknown>) {
    return this.database.transactionAsUser(user, async (client) => {
      const professional = await client.query<{ id: string }>(
        `SELECT id FROM professionals WHERE user_id=$1 AND professional_type='doctor' AND verification_status='approved' AND app_can_read_patient($2::uuid)
          AND (EXISTS(SELECT 1 FROM appointments WHERE professional_id=professionals.id AND patient_id=$2 AND status IN('in_progress','completed'))
            OR EXISTS(SELECT 1 FROM emergency_events WHERE assigned_professional_id=professionals.id AND patient_id=$2 AND accepted_at IS NOT NULL AND status IN('on_site','in_care','referred')))`,
        [user.id, input.patientId],
      );
      if (!professional.rows[0])
        throw new NotFoundException(
          "No existe autorización clínica para el paciente.",
        );
      if (input.appointmentId) {
        const appointment = await client.query(
          `SELECT id FROM appointments WHERE id=$1 AND patient_id=$2 AND professional_id=$3 AND status IN('in_progress','completed')`,
          [input.appointmentId, input.patientId, professional.rows[0].id],
        );
        if (!appointment.rows[0])
          throw new ConflictException(
            "La cita no autoriza esta orden diagnóstica.",
          );
      }
      const result = await client.query(
        `INSERT INTO diagnostic_orders(patient_id,requested_by_professional_id,partner_id,appointment_id,order_type,description) VALUES($1,$2,$3,$4,$5,$6) RETURNING *`,
        [
          input.patientId,
          professional.rows[0].id,
          input.partnerId ?? null,
          input.appointmentId ?? null,
          input.orderType,
          String(input.description).trim(),
        ],
      );
      await this.auditPartner(
        client,
        user,
        "diagnostic_order_created",
        "diagnostic_order",
        result.rows[0].id,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  completeDiagnosticOrder(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const order = await client.query<any>(
        `SELECT diagnostic.* FROM diagnostic_orders diagnostic JOIN partner_users partner_user ON partner_user.partner_id=diagnostic.partner_id AND partner_user.user_id=$2 AND partner_user.is_active WHERE diagnostic.id=$1 AND diagnostic.status IN('requested','in_progress') FOR UPDATE OF diagnostic`,
        [id, user.id],
      );
      if (!order.rows[0])
        throw new NotFoundException("La orden diagnóstica no está disponible.");
      const document = await client.query<{ id: string }>(
        "SELECT gen_random_uuid() AS id",
      );
      await client.query(
        `INSERT INTO clinical_documents(patient_id,uploaded_by_user_id,related_appointment_id,document_type,file_url,file_name,mime_type,source,validation_status,id) VALUES($1,$2,$3,$4,$5,NULLIF($6,''),NULLIF($7,''),'external','pending_validation',$8)`,
        [
          order.rows[0].patient_id,
          user.id,
          order.rows[0].appointment_id,
          input.documentType,
          String(input.fileUrl).trim(),
          String(input.fileName ?? "").trim(),
          String(input.mimeType ?? "").trim(),
          document.rows[0].id,
        ],
      );
      await client.query(
        `UPDATE diagnostic_orders SET status='completed',result_document_id=$2,completed_at=now() WHERE id=$1`,
        [id, document.rows[0].id],
      );
      await client.query("SELECT app_notify_diagnostic_result($1)", [id]);
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,
           action,entity_type,entity_id,new_values)
         VALUES($1,$2,$3,'clinical_records','diagnostic_result_added',
           'clinical_document',$4,jsonb_build_object('diagnosticOrderId',$5::uuid))`,
        [
          user.id,
          user.roleCode,
          order.rows[0].patient_id,
          document.rows[0].id,
          id,
        ],
      );
      await this.auditPartner(
        client,
        user,
        "diagnostic_result_uploaded",
        "diagnostic_order",
        id,
        { status: "completed", resultDocumentId: document.rows[0].id },
      );
      return { id, status: "completed", resultDocumentId: document.rows[0].id };
    });
  }

  private async createRenewal(
    client: import("pg").PoolClient,
    user: RequestUser,
    subscriptionId: string,
    payerUserId: string,
    autoRenew?: boolean,
  ) {
    const source = await client.query<{
      partner_id: string;
      plan_id: string;
      ends_at: Date | null;
      name: string;
      price: string;
      currency: string;
    }>(
      `SELECT subscription.partner_id,subscription.plan_id,subscription.ends_at,plan.name,plan.price::text,plan.currency FROM partner_subscriptions subscription JOIN partner_subscription_plans plan ON plan.id=subscription.plan_id JOIN partner_users partner_user ON partner_user.partner_id=subscription.partner_id AND partner_user.user_id=$2 AND partner_user.is_active WHERE subscription.id=$1 AND subscription.status IN('active','grace_period','expired') AND plan.is_active FOR UPDATE OF subscription`,
      [subscriptionId, payerUserId],
    );
    if (!source.rows[0])
      throw new NotFoundException(
        "Suscripción, plan o responsable empresarial no válidos.",
      );
    const existing = await client.query(
      `SELECT id FROM partner_subscriptions WHERE partner_id=$1 AND status='pending_payment' LIMIT 1`,
      [source.rows[0].partner_id],
    );
    if (existing.rows[0])
      throw new ConflictException("Ya existe una renovación pendiente.");
    const order = await client.query<{ id: string }>(
      `INSERT INTO payment_orders(user_id,related_entity_type,related_entity_id,concept,charge_mode,amount,currency,status,due_at) VALUES($1,'partner_subscription',$2,$3,'fiat',$4,$5,'pending',now()+interval '5 days') RETURNING id`,
      [
        payerUserId,
        source.rows[0].partner_id,
        `Renovación empresarial ${source.rows[0].name}`,
        source.rows[0].price,
        source.rows[0].currency,
      ],
    );
    const startsAt =
      source.rows[0].ends_at && source.rows[0].ends_at > new Date()
        ? source.rows[0].ends_at
        : null;
    const result = await client.query(
      `INSERT INTO partner_subscriptions(partner_id,plan_id,payment_order_id,status,starts_at,auto_renew) VALUES($1,$2,$3,'pending_payment',$4,$5) RETURNING id,partner_id AS "partnerId",plan_id AS "planId",payment_order_id AS "paymentOrderId",status,starts_at AS "startsAt",auto_renew AS "autoRenew"`,
      [
        source.rows[0].partner_id,
        source.rows[0].plan_id,
        order.rows[0].id,
        startsAt,
        autoRenew ?? false,
      ],
    );
    await client.query(
      `UPDATE payment_orders SET related_entity_id=$2 WHERE id=$1`,
      [order.rows[0].id, result.rows[0].id],
    );
    await this.auditPartner(
      client,
      user,
      "subscription_renewal_created",
      "partner_subscription",
      result.rows[0].id,
      result.rows[0],
    );
    return {
      ...result.rows[0],
      amount: Number(source.rows[0].price),
      currency: source.rows[0].currency,
    };
  }

  private async notifyPartnerUsers(
    client: import("pg").PoolClient,
    partnerId: string,
    eventCode: string,
    title: string,
    body: string,
    entityId: string,
  ) {
    await client.query(
      `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at) SELECT partner_user.user_id,$2,'in_app',$3,$4,'partner_subscription',$5,'sent',now() FROM partner_users partner_user WHERE partner_user.partner_id=$1 AND partner_user.is_active AND NOT EXISTS(SELECT 1 FROM notifications notification WHERE notification.user_id=partner_user.user_id AND notification.event_code=$2 AND notification.related_entity_id=$5)`,
      [partnerId, eventCode, title, body, entityId],
    );
  }

  private async auditPartner(
    client: import("pg").PoolClient,
    user: RequestUser,
    action: string,
    entityType: string,
    entityId: string,
    newValues: unknown,
  ) {
    await client.query(
      `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values) VALUES($1,$2,'partners',$3,$4,$5,$6::jsonb)`,
      [
        user.id,
        user.roleCode,
        action,
        entityType,
        entityId,
        JSON.stringify(newValues),
      ],
    );
  }

  private savePlan(
    user: RequestUser,
    id: string | null,
    input: SubscriptionPlanInput,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const previous = id
        ? (
            await client.query(
              `SELECT * FROM partner_subscription_plans WHERE id=$1`,
              [id],
            )
          ).rows[0]
        : null;
      const values = [
        input.code.trim(),
        input.name.trim(),
        input.description?.trim() ?? "",
        input.billingPeriod,
        input.price,
        input.currency ?? "BOB",
        JSON.stringify(input.features ?? {}),
        JSON.stringify(input.limits ?? {}),
        input.discountPercent ?? 0,
        input.isActive ?? true,
      ];
      const result = id
        ? await client.query(
            `UPDATE partner_subscription_plans SET code=UPPER($2),name=$3,description=NULLIF($4,''),billing_period=$5,price=$6,currency=UPPER($7),features=$8::jsonb,limits=$9::jsonb,discount_percent=$10,is_active=$11,updated_at=now() WHERE id=$1 RETURNING *`,
            [id, ...values],
          )
        : await client.query(
            `INSERT INTO partner_subscription_plans(code,name,description,billing_period,price,currency,features,limits,discount_percent,is_active) VALUES(UPPER($1),$2,NULLIF($3,''),$4,$5,UPPER($6),$7::jsonb,$8::jsonb,$9,$10) RETURNING *`,
            values,
          );
      if (!result.rows[0])
        throw new NotFoundException("Plan empresarial no encontrado.");
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,old_values,new_values) VALUES($1,$2,'partners',$3,'partner_subscription_plan',$4,$5::jsonb,$6::jsonb)`,
        [
          user.id,
          user.roleCode,
          id ? "subscription_plan_updated" : "subscription_plan_created",
          result.rows[0].id,
          previous ? JSON.stringify(previous) : null,
          JSON.stringify(result.rows[0]),
        ],
      );
      return result.rows[0];
    });
  }
}
