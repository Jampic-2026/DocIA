import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { PoolClient } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { Benefit, BenefitUsage } from "../../domain/benefit";
import { BenefitsRepository } from "../../domain/ports/benefits.repository";

@Injectable()
export class PostgresBenefitsRepository implements BenefitsRepository {
  constructor(private readonly database: DatabaseService) {}

  list(user: RequestUser): Promise<Benefit[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<Benefit>(
        `WITH own_patient AS (
           SELECT patient.id FROM patients patient
           JOIN persons person ON person.id=patient.person_id
           WHERE person.user_id=$1 LIMIT 1
         )
         SELECT benefit.id,benefit.code,benefit.name,benefit.description,
          benefit.discount_percent AS "discountPercent",
          benefit.discount_amount AS "discountAmount",
          benefit.discount_coin_amount::text AS "discountCoinAmount",
          benefit.benefit_type AS "benefitType",
          benefit.max_uses_per_user AS "maxUsesPerUser",
          benefit.is_stackable AS "isStackable",
          benefit.valid_from AS "validFrom",
          benefit.valid_until AS "validUntil",benefit.conditions,
          CASE WHEN NOT benefit.is_active THEN 'inactive'
            WHEN benefit.valid_from>CURRENT_DATE THEN 'upcoming'
            WHEN benefit.valid_until<CURRENT_DATE THEN 'expired'
            WHEN benefit.max_total_uses IS NOT NULL AND
              (SELECT count(*) FROM benefit_usages total_usage
               WHERE total_usage.benefit_id=benefit.id
                 AND total_usage.status NOT IN('rejected','cancelled'))>=benefit.max_total_uses
              THEN 'exhausted' ELSE 'active' END AS "lifecycleStatus",
          count(DISTINCT usage.id)::int AS "usedCount",
          (
            benefit.is_active
            AND (benefit.valid_from IS NULL OR benefit.valid_from<=CURRENT_DATE)
            AND (benefit.valid_until IS NULL OR benefit.valid_until>=CURRENT_DATE)
            AND (
              benefit.max_uses_per_user IS NULL
              OR count(DISTINCT usage.id)<benefit.max_uses_per_user
            )
          ) AS available,
          COALESCE(
            array_agg(DISTINCT partner.name)
              FILTER(WHERE partner.name IS NOT NULL),
            ARRAY[]::text[]
          ) AS "partnerNames"
         FROM benefits benefit
         LEFT JOIN own_patient own ON true
         LEFT JOIN benefit_usages usage
           ON usage.benefit_id=benefit.id AND usage.patient_id=own.id
           AND usage.status<>'cancelled'
         LEFT JOIN partner_benefits link
           ON link.benefit_id=benefit.id AND link.is_active
         LEFT JOIN health_partners partner ON partner.id=link.partner_id
         WHERE (benefit.is_active OR app_has_role('admin')) AND (
          NOT benefit.requires_profile_reward
          OR EXISTS(SELECT 1 FROM profile_reward_grants grant_record WHERE grant_record.benefit_id=benefit.id AND grant_record.patient_id=own.id)
          OR app_has_role('admin'))
         GROUP BY benefit.id
         ORDER BY available DESC,benefit.valid_until NULLS LAST,benefit.name`,
        [user.id],
      );
      return result.rows;
    });
  }

  listUsages(user: RequestUser): Promise<BenefitUsage[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<BenefitUsage>(
        `SELECT usage.id,benefit.name AS "benefitName",
          usage.discount_applied AS "discountApplied",
          usage.coin_discount_applied::text AS "coinDiscountApplied",
          usage.status,usage.used_at AS "usedAt"
         FROM benefit_usages usage
         JOIN benefits benefit ON benefit.id=usage.benefit_id
         JOIN patients patient ON patient.id=usage.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1
         ORDER BY usage.used_at DESC`,
        [user.id],
      );
      return result.rows;
    });
  }

  create(user: RequestUser, input: Record<string, unknown>) {
    return this.save(user, undefined, input);
  }
  update(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.save(user, id, input);
  }

  private save(
    user: RequestUser,
    id: string | undefined,
    input: Record<string, unknown>,
  ) {
    if (!user.roles.includes("admin"))
      throw new ForbiddenException(
        "Sólo administración puede gestionar beneficios.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const old = id
        ? await client.query(`SELECT * FROM benefits WHERE id=$1 FOR UPDATE`, [
            id,
          ])
        : null;
      if (id && !old?.rows[0])
        throw new NotFoundException("El beneficio no existe.");
      if (
        input.validFrom &&
        input.validUntil &&
        new Date(String(input.validUntil)) < new Date(String(input.validFrom))
      )
        throw new BadRequestException(
          "La vigencia final no puede ser anterior a la inicial.",
        );
      if (
        input.discountPercent == null &&
        input.discountAmount == null &&
        input.discountCoinAmount == null
      )
        throw new BadRequestException(
          "Configura al menos un tipo de descuento.",
        );
      try {
        const values = [
          input.code,
          String(input.name).trim(),
          String(input.description ?? "").trim(),
          input.discountPercent ?? null,
          input.discountAmount ?? null,
          input.discountCoinAmount ?? null,
          input.benefitType,
          input.maxUsesPerUser ?? null,
          input.maxTotalUses ?? null,
          input.isStackable ?? false,
          input.fundedBy ?? "platform",
          input.validFrom ?? null,
          input.validUntil ?? null,
          JSON.stringify(input.conditions ?? {}),
          input.isActive ?? true,
        ];
        const result = id
          ? await client.query(
              `UPDATE benefits SET code=$2,name=$3,description=NULLIF($4,''),discount_percent=$5,discount_amount=$6,discount_coin_amount=$7,benefit_type=$8,max_uses_per_user=$9,max_total_uses=$10,is_stackable=$11,funded_by=$12,valid_from=$13::date,valid_until=$14::date,conditions=$15::jsonb,is_active=$16 WHERE id=$1 RETURNING *`,
              [id, ...values],
            )
          : await client.query(
              `INSERT INTO benefits(code,name,description,discount_percent,discount_amount,discount_coin_amount,benefit_type,max_uses_per_user,max_total_uses,is_stackable,funded_by,valid_from,valid_until,conditions,is_active) VALUES($1,$2,NULLIF($3,''),$4,$5,$6,$7,$8,$9,$10,$11,$12::date,$13::date,$14::jsonb,$15) RETURNING *`,
              values,
            );
        await this.audit(
          client,
          user,
          id ? "benefit_updated" : "benefit_created",
          "benefit",
          result.rows[0].id,
          old?.rows[0] ?? null,
          result.rows[0],
          String(input.reason),
        );
        return result.rows[0];
      } catch (error) {
        if ((error as { code?: string }).code === "23505")
          throw new ConflictException("El código del beneficio ya existe.");
        throw error;
      }
    });
  }

  apply(user: RequestUser, input: Record<string, unknown>) {
    return this.database.transactionAsUser(user, async (client) => {
      const patient = await client.query<{ id: string }>(
        `SELECT patient.id FROM patients patient JOIN persons person ON person.id=patient.person_id WHERE person.user_id=$1`,
        [user.id],
      );
      if (!patient.rows[0])
        throw new NotFoundException(
          "La cuenta no tiene un perfil de paciente.",
        );
      const benefit = await client.query<any>(
        `SELECT * FROM benefits WHERE id=$1 AND is_active AND (valid_from IS NULL OR valid_from<=current_date) AND (valid_until IS NULL OR valid_until>=current_date) FOR UPDATE`,
        [input.benefitId],
      );
      if (!benefit.rows[0])
        throw new NotFoundException("El beneficio no está disponible.");
      const campaignAccess = await client.query(
        `SELECT 1 FROM benefits campaign_benefit
        WHERE campaign_benefit.id=$1::uuid AND campaign_benefit.requires_profile_reward AND NOT EXISTS(SELECT 1 FROM profile_reward_grants grant_record
          WHERE grant_record.benefit_id=$1::uuid AND grant_record.patient_id=$2)`,
        [input.benefitId, patient.rows[0].id],
      );
      if (campaignAccess.rows[0])
        throw new ForbiddenException(
          "Completa los requisitos de la campa\u00f1a antes de aplicar este beneficio.",
        );
      const order = await client.query<any>(
        `SELECT * FROM payment_orders WHERE id=$1 AND user_id=$2 AND status='pending' FOR UPDATE`,
        [input.paymentOrderId, user.id],
      );
      if (!order.rows[0])
        throw new NotFoundException(
          "La orden no existe o ya no admite descuentos.",
        );
      await this.assertEligibility(
        client,
        patient.rows[0].id,
        benefit.rows[0],
        order.rows[0],
      );
      const discount = this.calculateDiscount(benefit.rows[0], order.rows[0]);
      let validationRequired = false;
      if (input.partnerId) {
        const link = await client.query<{ validation_required: boolean }>(
          `SELECT validation_required FROM partner_benefits WHERE partner_id=$1 AND benefit_id=$2 AND is_active`,
          [input.partnerId, input.benefitId],
        );
        if (!link.rows[0])
          throw new BadRequestException(
            "El aliado no participa en este beneficio.",
          );
        validationRequired = link.rows[0].validation_required;
      }
      const usage = await client.query<any>(
        `INSERT INTO benefit_usages(benefit_id,patient_id,payment_order_id,discount_applied,coin_discount_applied,status) VALUES($1,$2,$3,$4,$5,$6) RETURNING *`,
        [
          input.benefitId,
          patient.rows[0].id,
          input.paymentOrderId,
          discount.fiat,
          discount.coins,
          validationRequired ? "pending_validation" : "applied",
        ],
      );
      let validationId: string | null = null;
      if (validationRequired) {
        const validation = await client.query<{ id: string }>(
          `INSERT INTO benefit_validations(benefit_usage_id,partner_id) VALUES($1,$2) RETURNING id`,
          [usage.rows[0].id, input.partnerId],
        );
        validationId = validation.rows[0].id;
      } else await this.applyOrderDiscount(client, order.rows[0], discount);
      await this.audit(
        client,
        user,
        "benefit_applied",
        "benefit_usage",
        usage.rows[0].id,
        null,
        usage.rows[0],
      );
      return { ...usage.rows[0], validationId };
    });
  }

  validations(user: RequestUser): Promise<unknown[]> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT validation.id,validation.status,validation.reason,validation.created_at AS "createdAt",validation.validated_at AS "validatedAt",partner.name AS "partnerName",benefit.name AS "benefitName",usage.discount_applied AS "discountApplied",usage.coin_discount_applied AS "coinDiscountApplied" FROM benefit_validations validation JOIN health_partners partner ON partner.id=validation.partner_id JOIN benefit_usages usage ON usage.id=validation.benefit_usage_id JOIN benefits benefit ON benefit.id=usage.benefit_id ORDER BY validation.created_at DESC LIMIT 200`,
          )
        ).rows,
    );
  }

  validate(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.database.transactionAsUser(user, async (client) => {
      const found = await client.query<any>(
        `SELECT validation.*,usage.payment_order_id,usage.discount_applied,usage.coin_discount_applied,usage.status AS usage_status FROM benefit_validations validation JOIN partner_users partner_user ON partner_user.partner_id=validation.partner_id AND partner_user.user_id=$2 AND partner_user.is_active JOIN benefit_usages usage ON usage.id=validation.benefit_usage_id WHERE validation.id=$1 FOR UPDATE OF validation,usage`,
        [id, user.id],
      );
      const validation = found.rows[0];
      if (!validation)
        throw new NotFoundException(
          "La validación no existe o no corresponde al aliado.",
        );
      if (validation.status !== "pending")
        throw new ConflictException("La validación ya fue resuelta.");
      if (input.status === "approved") {
        const order = await client.query<any>(
          `SELECT * FROM payment_orders WHERE id=$1 AND status='pending' FOR UPDATE`,
          [validation.payment_order_id],
        );
        if (!order.rows[0])
          throw new ConflictException("La orden ya no admite el beneficio.");
        await this.applyOrderDiscount(client, order.rows[0], {
          fiat: Number(validation.discount_applied),
          coins: Number(validation.coin_discount_applied),
        });
      }
      await client.query(
        `UPDATE benefit_validations SET status=$2,reason=NULLIF($3,''),validated_by_user_id=$4,validated_at=now() WHERE id=$1`,
        [id, input.status, String(input.reason ?? ""), user.id],
      );
      await client.query(`UPDATE benefit_usages SET status=$2 WHERE id=$1`, [
        validation.benefit_usage_id,
        input.status === "approved" ? "validated" : "rejected",
      ]);
      await this.audit(
        client,
        user,
        "benefit_validation_resolved",
        "benefit_validation",
        id,
        { status: "pending" },
        { status: input.status },
        String(input.reason ?? "") || null,
      );
      return { id, status: input.status };
    });
  }

  setPartner(
    user: RequestUser,
    benefitId: string,
    partnerId: string,
    input: Record<string, unknown>,
  ) {
    if (!user.roles.includes("admin"))
      throw new ForbiddenException(
        "Sólo administración puede asociar beneficios.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO partner_benefits(partner_id,benefit_id,validation_required,settlement_terms,is_active) SELECT $1,$2,$3,$4::jsonb,$5 FROM health_partners partner JOIN benefits benefit ON benefit.id=$2 WHERE partner.id=$1 ON CONFLICT(partner_id,benefit_id) DO UPDATE SET validation_required=excluded.validation_required,settlement_terms=excluded.settlement_terms,is_active=excluded.is_active RETURNING *`,
        [
          partnerId,
          benefitId,
          input.validationRequired ?? true,
          JSON.stringify(input.settlementTerms ?? {}),
          input.isActive ?? true,
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("El beneficio o aliado no existe.");
      await this.audit(
        client,
        user,
        "partner_benefit_configured",
        "benefit",
        benefitId,
        null,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  reverse(user: RequestUser, id: string, input: Record<string, unknown>) {
    if (!user.roles.includes("admin"))
      throw new ForbiddenException(
        "Sólo administración puede revertir beneficios.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const usage = await client.query<any>(
        `SELECT usage.*,payment_order.charge_mode,
          payment_order.status AS order_status
         FROM benefit_usages usage
         JOIN payment_orders payment_order ON payment_order.id=usage.payment_order_id
         WHERE usage.id=$1 AND usage.status IN('applied','validated')
         FOR UPDATE OF usage,payment_order`,
        [id],
      );
      if (!usage.rows[0])
        throw new NotFoundException("El uso no existe o no puede revertirse.");
      if (usage.rows[0].order_status !== "pending")
        throw new ConflictException(
          "No se puede revertir el beneficio después de procesar el pago.",
        );
      if (usage.rows[0].charge_mode === "coins")
        await client.query(
          `UPDATE payment_orders SET coin_amount=coin_amount+$2,updated_at=now()
           WHERE id=$1`,
          [usage.rows[0].payment_order_id, usage.rows[0].coin_discount_applied],
        );
      else
        await client.query(
          `UPDATE payment_orders SET amount=amount+$2,updated_at=now()
           WHERE id=$1`,
          [usage.rows[0].payment_order_id, usage.rows[0].discount_applied],
        );
      await client.query(
        `UPDATE benefit_usages SET status='reverted' WHERE id=$1`,
        [id],
      );
      await this.audit(
        client,
        user,
        "benefit_usage_reverted",
        "benefit_usage",
        id,
        { status: usage.rows[0].status },
        { status: "reverted" },
        String(input.reason),
      );
      return { id, status: "reverted" };
    });
  }

  private async assertEligibility(
    client: PoolClient,
    patientId: string,
    benefit: any,
    order: any,
  ) {
    const counts = await client.query<{ own: number; total: number }>(
      `SELECT count(*) FILTER(WHERE patient_id=$2 AND status NOT IN('rejected','cancelled'))::int AS own,count(*) FILTER(WHERE status NOT IN('rejected','cancelled'))::int AS total FROM benefit_usages WHERE benefit_id=$1`,
      [benefit.id, patientId],
    );
    if (
      benefit.max_uses_per_user != null &&
      counts.rows[0].own >= benefit.max_uses_per_user
    )
      throw new ConflictException(
        "Ya alcanzaste el límite de uso del beneficio.",
      );
    if (
      benefit.max_total_uses != null &&
      counts.rows[0].total >= benefit.max_total_uses
    )
      throw new ConflictException("El beneficio agotó su disponibilidad.");
    const existing = await client.query<{ is_stackable: boolean }>(
      `SELECT existing_benefit.is_stackable FROM benefit_usages usage
       JOIN benefits existing_benefit ON existing_benefit.id=usage.benefit_id
       WHERE usage.payment_order_id=$1
         AND usage.status NOT IN('rejected','cancelled')`,
      [order.id],
    );
    if (
      existing.rows.length > 0 &&
      (!benefit.is_stackable || existing.rows.some((row) => !row.is_stackable))
    )
      throw new ConflictException(
        "La orden ya tiene un beneficio no acumulable.",
      );
    const conditions = benefit.conditions ?? {};
    if (
      Array.isArray(conditions.chargeModes) &&
      !conditions.chargeModes.includes(order.charge_mode)
    )
      throw new BadRequestException(
        "El beneficio no aplica a esta modalidad de cobro.",
      );
    const base = Number(order.amount ?? order.coin_amount ?? 0);
    if (
      conditions.minimumAmount != null &&
      base < Number(conditions.minimumAmount)
    )
      throw new BadRequestException(
        "La orden no alcanza el importe mínimo del beneficio.",
      );
  }

  private calculateDiscount(benefit: any, order: any) {
    const base = Number(order.amount ?? order.coin_amount ?? 0);
    const percent = Number(benefit.discount_percent ?? 0);
    if (order.charge_mode === "coins")
      return {
        fiat: 0,
        coins: Math.min(
          base,
          Math.max(
            Number(benefit.discount_coin_amount ?? 0),
            Math.floor((base * percent) / 100),
          ),
        ),
      };
    return {
      fiat: Math.min(
        base,
        Math.max(
          Number(benefit.discount_amount ?? 0),
          Math.round(base * percent) / 100,
        ),
      ),
      coins: 0,
    };
  }

  private async applyOrderDiscount(
    client: PoolClient,
    order: any,
    discount: { fiat: number; coins: number },
  ) {
    if (order.charge_mode === "coins")
      await client.query(
        `UPDATE payment_orders SET coin_amount=GREATEST(0,coin_amount-$2),updated_at=now() WHERE id=$1`,
        [order.id, discount.coins],
      );
    else
      await client.query(
        `UPDATE payment_orders SET amount=GREATEST(0,amount-$2),updated_at=now() WHERE id=$1`,
        [order.id, discount.fiat],
      );
  }

  private async audit(
    client: PoolClient,
    user: RequestUser,
    action: string,
    entityType: string,
    entityId: string,
    oldValues: unknown,
    newValues: unknown,
    reason: string | null = null,
  ) {
    await client.query(
      `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,old_values,new_values,reason) VALUES($1,$2,'benefits',$3,$4,$5,$6::jsonb,$7::jsonb,$8)`,
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
}
