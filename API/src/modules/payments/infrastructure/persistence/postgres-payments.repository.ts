import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { PaymentOrder, PaymentRecord } from "../../domain/payment-record";
import { PaymentsRepository } from "../../domain/ports/payments.repository";
import {
  CreateOrderInput,
  ResolveIncidentInput,
} from "../../domain/ports/payments.repository";

@Injectable()
export class PostgresPaymentsRepository implements PaymentsRepository {
  constructor(private readonly database: DatabaseService) {}

  listOrders(user: RequestUser): Promise<PaymentOrder[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<PaymentOrder>(
        `SELECT payment_order.id,payment_order.concept,
          payment_order.charge_mode AS "chargeMode",
          payment_order.coin_amount::text AS "coinAmount",
          payment_order.amount,payment_order.currency,
          payment_order.status::text,payment_order.due_at AS "dueAt",
          payment_order.accepted_at AS "acceptedAt",
          payment_order.created_at AS "createdAt",
          service.name AS "serviceName",
          payment_order.related_entity_type AS "relatedEntityType",
          coin_package.qr_image_url AS "qrImageUrl",
          latest.method::text AS "latestPaymentMethod",
          latest.status::text AS "latestPaymentStatus",
          latest.rejection_reason AS "latestPaymentRejectionReason"
         FROM payment_orders payment_order
         LEFT JOIN service_catalog service ON service.id=payment_order.service_id
         LEFT JOIN coin_packages coin_package
           ON payment_order.related_entity_type='coin_package'
          AND coin_package.id=payment_order.related_entity_id
         LEFT JOIN LATERAL (
           SELECT payment.method,payment.status,payment.rejection_reason FROM payments payment
           WHERE payment.payment_order_id=payment_order.id
           ORDER BY payment.created_at DESC LIMIT 1
         ) latest ON true
         WHERE payment_order.user_id=$1
         ORDER BY payment_order.created_at DESC`,
        [user.id],
      );
      return result.rows;
    });
  }

  listPayments(user: RequestUser): Promise<PaymentRecord[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<PaymentRecord>(
        `SELECT payment.id,payment.payment_order_id AS "paymentOrderId",
          payment_order.concept,payment.method::text,payment.amount,
          payment_order.currency,payment.status::text,
          payment.transaction_reference AS "transactionReference",
          payment.paid_at AS "paidAt",
          payment.rejection_reason AS "rejectionReason",
          payment.created_at AS "createdAt"
         FROM payments payment
         JOIN payment_orders payment_order
           ON payment_order.id=payment.payment_order_id
         WHERE payment_order.user_id=$1
         ORDER BY payment.created_at DESC`,
        [user.id],
      );
      return result.rows;
    });
  }

  configuration(user: RequestUser): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{ key: string; value: unknown }>(
        `SELECT setting_key AS key,value FROM system_settings
         WHERE setting_key IN('payments.qr_image_url','payments.qr_account_name','payments.qr_bank_name','payments.cash_enabled')`,
      );
      return Object.fromEntries(result.rows.map((row) => [row.key, row.value]));
    });
  }

  reviewQueue(user: RequestUser): Promise<unknown[]> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT payment.id,payment.payment_order_id AS "paymentOrderId",payment_order.user_id AS "userId",payment_order.concept,payment.method::text,payment.amount,payment_order.currency,payment.status::text,payment.receipt_url AS "receiptUrl",payment.transaction_reference AS "transactionReference",payment.rejection_reason AS "rejectionReason",payment.paid_at AS "paidAt",payment.created_at AS "createdAt" FROM payments payment JOIN payment_orders payment_order ON payment_order.id=payment.payment_order_id WHERE payment.method IN('qr','bank_transfer') ORDER BY payment.created_at DESC LIMIT 100`,
          )
        ).rows,
    );
  }

  createOrder(user: RequestUser, input: CreateOrderInput): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const price = await client.query<{
        service_id: string;
        service_name: string;
        charge_mode: string;
        coin_price: string | null;
        price: string | null;
        currency: string;
      }>(
        `SELECT service.id AS service_id,service.name AS service_name,
           tariff.charge_mode,tariff.coin_price::text,tariff.price::text,tariff.currency
         FROM service_catalog service
         JOIN LATERAL(
           SELECT price.* FROM price_list price
           WHERE price.service_id=service.id AND price.valid_from<=CURRENT_DATE
             AND(price.valid_until IS NULL OR price.valid_until>=CURRENT_DATE)
           ORDER BY price.valid_from DESC,price.created_at DESC LIMIT 1
         ) tariff ON true
         WHERE service.id=$1 AND service.is_active`,
        [input.serviceId],
      );
      if (!price.rows[0])
        throw new NotFoundException(
          "Servicio o tarifa vigente no encontrados.",
        );
      if (input.patientId) {
        const access = await client.query<{ allowed: boolean }>(
          `SELECT app_can_read_patient($1) AS allowed`,
          [input.patientId],
        );
        if (!access.rows[0]?.allowed)
          throw new NotFoundException("Paciente no encontrado.");
      }
      const tariff = price.rows[0];
      const result = await client.query(
        `INSERT INTO payment_orders(
           user_id,patient_id,service_id,appointment_id,emergency_id,
           related_entity_type,related_entity_id,concept,charge_mode,
           coin_amount,amount,currency,status,due_at
         )VALUES($1,$2,$3,$4,$5,NULLIF($6,''),$7,$8,$9,$10,$11,$12,'pending',now()+interval '24 hours')
         RETURNING id,concept,charge_mode AS "chargeMode",coin_amount AS "coinAmount",
           amount,currency,status::text,due_at AS "dueAt",created_at AS "createdAt"`,
        [
          user.id,
          input.patientId ?? null,
          input.serviceId,
          input.appointmentId ?? null,
          input.emergencyId ?? null,
          input.relatedEntityType?.trim() ?? "",
          input.relatedEntityId ?? null,
          tariff.service_name,
          tariff.charge_mode,
          tariff.charge_mode === "coins" ? tariff.coin_price : null,
          tariff.charge_mode === "fiat" ? tariff.price : null,
          tariff.currency,
        ],
      );
      await this.auditFinancial(
        client,
        user,
        "payment_order_created",
        "payment_order",
        result.rows[0].id,
        null,
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  acceptOrder(
    user: RequestUser,
    orderId: string,
    accepted: boolean,
    reason?: string,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const order = await client.query<{
        id: string;
        status: string;
        charge_mode: string;
        coin_amount: string | null;
        service_id: string | null;
        appointment_id: string | null;
        emergency_id: string | null;
        related_entity_type: string | null;
        related_entity_id: string | null;
      }>(
        `SELECT id,status::text,charge_mode,coin_amount::text,service_id,
           appointment_id,emergency_id,related_entity_type,related_entity_id
         FROM payment_orders WHERE id=$1 AND user_id=$2 FOR UPDATE`,
        [orderId, user.id],
      );
      const row = order.rows[0];
      if (!row) throw new NotFoundException("Orden de pago no encontrada.");
      if (row.status !== "pending")
        throw new ConflictException("La orden ya fue procesada.");
      if (!accepted) {
        await client.query(
          `UPDATE payment_orders SET status='cancelled',updated_at=now() WHERE id=$1`,
          [orderId],
        );
        await this.auditFinancial(
          client,
          user,
          "payment_order_cancelled",
          "payment_order",
          orderId,
          { status: row.status },
          { status: "cancelled" },
          reason,
        );
        return { id: orderId, status: "cancelled" };
      }
      if (row.charge_mode === "fiat") {
        await client.query(
          `UPDATE payment_orders SET status='accepted',accepted_at=now(),updated_at=now() WHERE id=$1`,
          [orderId],
        );
        await this.auditFinancial(
          client,
          user,
          "payment_order_accepted",
          "payment_order",
          orderId,
          { status: row.status },
          { status: "accepted" },
        );
        return { id: orderId, status: "accepted" };
      }
      await this.debitCoins(client, user, orderId, row);
      await this.auditFinancial(
        client,
        user,
        "coin_payment_completed",
        "payment_order",
        orderId,
        { status: row.status },
        { status: "paid", coinAmount: Number(row.coin_amount) },
      );
      return { id: orderId, status: "paid" };
    });
  }

  submit(
    user: RequestUser,
    orderId: string,
    input: {
      method: "qr" | "cash";
      amount: number;
      receiptUrl?: string;
      transactionReference?: string;
      collectedByProfessionalId?: string;
      collectionContext?: string;
    },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const order = await client.query<{ amount: string; status: string }>(
        `SELECT amount::text,status::text FROM payment_orders WHERE id=$1 AND user_id=$2 AND charge_mode='fiat' FOR UPDATE`,
        [orderId, user.id],
      );
      if (!order.rows[0])
        throw new NotFoundException("Orden de pago no encontrada.");
      if (!["pending", "accepted", "rejected"].includes(order.rows[0].status))
        throw new ConflictException("La orden no admite un nuevo pago.");
      if (Number(order.rows[0].amount) !== input.amount)
        throw new BadRequestException(
          "El monto no coincide con la orden de pago.",
        );
      if (input.method === "qr" && !input.receiptUrl)
        throw new BadRequestException("Debes adjuntar el comprobante QR.");
      const result = await client.query(
        `INSERT INTO payments(payment_order_id,method,amount,status,receipt_url,transaction_reference,paid_at,collected_by_professional_id,collection_context) VALUES($1,$2::payment_method,$3,'pending_validation',NULLIF($4,''),NULLIF($5,''),now(),$6,NULLIF($7,'')) RETURNING id,status::text,created_at AS "createdAt"`,
        [
          orderId,
          input.method,
          input.amount,
          input.receiptUrl ?? "",
          input.transactionReference?.trim() ?? "",
          null,
          input.collectionContext?.trim() ?? "",
        ],
      );
      await client.query(
        `UPDATE payment_orders SET status='pending_validation',accepted_at=COALESCE(accepted_at,now()),updated_at=now() WHERE id=$1`,
        [orderId],
      );
      await this.auditFinancial(
        client,
        user,
        "qr_receipt_submitted",
        "payment",
        result.rows[0].id,
        null,
        {
          status: "pending_validation",
          amount: input.amount,
          transactionReference: input.transactionReference ?? null,
        },
      );
      return result.rows[0];
    });
  }

  createCardPayment(
    user: RequestUser,
    orderId: string,
    input: {
      stripePaymentIntentId: string;
      stripeCheckoutSessionId?: string;
      amount: number;
      transactionReference?: string;
    },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const order = await client.query<{
        amount: string;
        currency: string;
        concept: string;
        status: string;
      }>(
        `SELECT amount::text,currency,concept,status::text
         FROM payment_orders
         WHERE id=$1 AND user_id=$2 AND charge_mode='fiat'
         FOR UPDATE`,
        [orderId, user.id],
      );
      const row = order.rows[0];
      if (!row) throw new NotFoundException("Orden de pago no encontrada.");
      if (
        ![
          "pending",
          "accepted",
          "rejected",
          "failed",
          "pending_validation",
        ].includes(row.status)
      )
        throw new ConflictException("La orden no admite un pago con tarjeta.");

      if (!input.stripePaymentIntentId && !input.stripeCheckoutSessionId) {
        const existing = await client.query(
          `SELECT id AS "paymentId",amount::text,status::text,
             stripe_payment_intent_id AS "stripePaymentIntentId",
             stripe_checkout_session_id AS "stripeCheckoutSessionId"
           FROM payments
           WHERE payment_order_id=$1 AND method='card'
             AND status='pending_validation'
           ORDER BY created_at DESC LIMIT 1`,
          [orderId],
        );
        if (existing.rows[0]) {
          return {
            ...existing.rows[0],
            currency: row.currency,
            concept: row.concept,
          };
        }
        const result = await client.query(
          `INSERT INTO payments(payment_order_id,method,amount,status,collection_context)
           VALUES($1,'card',$2,'pending_validation','stripe')
           RETURNING id AS "paymentId",amount::text,status::text`,
          [orderId, row.amount],
        );
        await client.query(
          `UPDATE payment_orders SET status='pending_validation',
             accepted_at=COALESCE(accepted_at,now()),updated_at=now()
           WHERE id=$1`,
          [orderId],
        );
        return {
          ...result.rows[0],
          currency: row.currency,
          concept: row.concept,
        };
      }

      const result = await client.query(
        `UPDATE payments
         SET stripe_payment_intent_id=NULLIF($2,''),
             stripe_checkout_session_id=COALESCE(NULLIF($4,''),stripe_checkout_session_id),
             transaction_reference=NULLIF($3,'')
         WHERE payment_order_id=$1 AND method='card'
           AND status='pending_validation'
         RETURNING id AS "paymentId",
           stripe_payment_intent_id AS "stripePaymentIntentId",
           stripe_checkout_session_id AS "stripeCheckoutSessionId"`,
        [
          orderId,
          input.stripePaymentIntentId,
          input.transactionReference?.trim() ?? "",
          input.stripeCheckoutSessionId?.trim() ?? "",
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("Pago con tarjeta no encontrado.");
      await this.auditFinancial(
        client,
        user,
        "stripe_payment_intent_created",
        "payment",
        result.rows[0].paymentId,
        null,
        {
          stripePaymentIntentId: input.stripePaymentIntentId,
          stripeCheckoutSessionId: input.stripeCheckoutSessionId,
          amount: input.amount,
        },
      );
      return result.rows[0];
    });
  }

  completeCardPayment(input: {
    paymentId?: string;
    paymentOrderId?: string;
    stripePaymentIntentId?: string;
    stripeCheckoutSessionId?: string;
    status: "paid" | "failed";
    transactionReference?: string;
    failureReason?: string;
  }): Promise<unknown> {
    return this.database.transaction(async (client) => {
      const payment = await client.query<{
        id: string;
        payment_order_id: string;
        user_id: string;
        status: string;
      }>(
        `SELECT payment.id,payment.payment_order_id,payment_order.user_id,
           payment.status::text
         FROM payments payment
         JOIN payment_orders payment_order
           ON payment_order.id=payment.payment_order_id
         WHERE payment.method='card'
           AND (
             payment.stripe_payment_intent_id=NULLIF($1,'')
             OR payment.stripe_checkout_session_id=NULLIF($2,'')
             OR payment.id=NULLIF($3,'')::uuid
             OR payment.payment_order_id=NULLIF($4,'')::uuid
           )
         FOR UPDATE`,
        [
          input.stripePaymentIntentId?.trim() ?? "",
          input.stripeCheckoutSessionId?.trim() ?? "",
          input.paymentId?.trim() ?? "",
          input.paymentOrderId?.trim() ?? "",
        ],
      );
      const row = payment.rows[0];
      if (!row) throw new NotFoundException("Pago Stripe no encontrado.");
      if (
        row.status === "paid" ||
        (row.status === "failed" && input.status === "failed")
      )
        return { id: row.id, status: row.status, received: true };

      await client.query(
        `UPDATE payments
         SET status=$2::payment_status,
             transaction_reference=COALESCE(NULLIF($3,''),transaction_reference),
             stripe_payment_intent_id=COALESCE(NULLIF($5,''),stripe_payment_intent_id),
             stripe_checkout_session_id=COALESCE(NULLIF($6,''),stripe_checkout_session_id),
             paid_at=CASE WHEN $2='paid' THEN now() ELSE paid_at END,
             validated_at=CASE WHEN $2='paid' THEN now() ELSE validated_at END,
             rejection_reason=CASE WHEN $2='failed' THEN NULLIF($4,'') ELSE NULL END
         WHERE id=$1`,
        [
          row.id,
          input.status,
          input.transactionReference?.trim() ?? "",
          input.failureReason?.trim() ?? "",
          input.stripePaymentIntentId?.trim() ?? "",
          input.stripeCheckoutSessionId?.trim() ?? "",
        ],
      );
      await client.query(
        `UPDATE payment_orders SET status=$2::payment_status,updated_at=now()
         WHERE id=$1`,
        [row.payment_order_id, input.status],
      );
      if (input.status === "paid") {
        await this.creditCoinPurchase(
          client,
          {
            id: row.user_id,
            email: "stripe-webhook@docia.local",
            sessionId: "stripe-webhook",
            roleCode: "system",
            roles: ["system"],
            permissions: [],
          },
          row.payment_order_id,
          row.id,
        );
        await this.propagatePaymentResult(
          client,
          row.payment_order_id,
          row.id,
          true,
        );
      }
      await client.query(
        `INSERT INTO audit_events(module,action,entity_type,entity_id,new_values,reason)
         VALUES('payments',$1,'payment',$2,$3::jsonb,NULLIF($4,''))`,
        [
          input.status === "paid"
            ? "stripe_payment_succeeded"
            : "stripe_payment_failed",
          row.id,
          JSON.stringify({
            status: input.status,
            stripePaymentIntentId: input.stripePaymentIntentId,
          }),
          input.failureReason ?? "",
        ],
      );
      return { id: row.id, status: input.status, received: true };
    });
  }

  registerInPerson(
    user: RequestUser,
    orderId: string,
    input: {
      method: "qr" | "cash";
      amount: number;
      receiptUrl?: string;
      transactionReference?: string;
      collectionContext: string;
    },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const professional = await client.query<{ id: string }>(
        `SELECT id FROM professionals WHERE user_id=$1 AND verification_status='verified'`,
        [user.id],
      );
      if (!professional.rows[0])
        throw new ConflictException(
          "Solo un profesional verificado puede registrar el cobro.",
        );
      const order = await client.query<{
        amount: string;
        status: string;
        user_id: string;
      }>(
        `SELECT payment_order.amount::text,payment_order.status::text,payment_order.user_id
         FROM payment_orders payment_order
         LEFT JOIN appointments appointment ON appointment.id=payment_order.appointment_id
         LEFT JOIN home_service_requests home_service
           ON payment_order.related_entity_type='home_service'
          AND home_service.id=payment_order.related_entity_id
         WHERE payment_order.id=$1 AND payment_order.charge_mode='fiat'
           AND(appointment.professional_id=$2 OR home_service.assigned_professional_id=$2)
         FOR UPDATE OF payment_order`,
        [orderId, professional.rows[0].id],
      );
      const row = order.rows[0];
      if (!row)
        throw new NotFoundException(
          "Orden presencial no encontrada o no asignada a tu usuario.",
        );
      if (!["pending", "accepted"].includes(row.status))
        throw new ConflictException(
          "La orden no admite el registro del cobro.",
        );
      if (Number(row.amount) !== input.amount)
        throw new BadRequestException(
          "El monto no coincide con la orden de pago.",
        );
      if (input.method === "qr" && !input.receiptUrl)
        throw new BadRequestException("Debes adjuntar el comprobante QR.");
      const payment = await client.query(
        `INSERT INTO payments(payment_order_id,method,amount,status,receipt_url,
           transaction_reference,paid_at,collected_by_professional_id,collection_context)
         VALUES($1,$2::payment_method,$3,'pending_validation',NULLIF($4,''),
           NULLIF($5,''),now(),$6,$7)
         RETURNING id,status::text,created_at AS "createdAt"`,
        [
          orderId,
          input.method,
          input.amount,
          input.receiptUrl ?? "",
          input.transactionReference?.trim() ?? "",
          professional.rows[0].id,
          input.collectionContext,
        ],
      );
      await client.query(
        `UPDATE payment_orders SET status='pending_validation',accepted_at=COALESCE(accepted_at,now()),updated_at=now() WHERE id=$1`,
        [orderId],
      );
      await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at)
         VALUES($1,'payment.in_person_registered','in_app','Cobro presencial registrado','Confirma el cobro o reporta una diferencia.','payment',$2,'sent',now())`,
        [row.user_id, payment.rows[0].id],
      );
      await this.auditFinancial(
        client,
        user,
        "in_person_payment_registered",
        "payment",
        payment.rows[0].id,
        null,
        {
          status: "pending_validation",
          method: input.method,
          amount: input.amount,
        },
      );
      return payment.rows[0];
    });
  }

  confirmInPerson(
    user: RequestUser,
    paymentId: string,
    confirmed: boolean,
    description?: string,
    reportedAmount?: number,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const payment = await client.query<{
        id: string;
        payment_order_id: string;
        amount: string;
        status: string;
      }>(
        `SELECT payment.id,payment.payment_order_id,payment.amount::text,payment.status::text
         FROM payments payment JOIN payment_orders payment_order ON payment_order.id=payment.payment_order_id
         WHERE payment.id=$1 AND payment_order.user_id=$2
           AND payment.collected_by_professional_id IS NOT NULL FOR UPDATE OF payment`,
        [paymentId, user.id],
      );
      const row = payment.rows[0];
      if (!row) throw new NotFoundException("Cobro presencial no encontrado.");
      if (row.status !== "pending_validation")
        throw new ConflictException("El cobro ya fue confirmado o revisado.");
      if (!confirmed) {
        const incident = await client.query(
          `INSERT INTO payment_incidents(payment_id,reported_by_user_id,incident_type,reported_amount,expected_amount,description,status)
           VALUES($1,$2,'amount_difference',$3,$4,$5,'open') RETURNING id,status`,
          [
            paymentId,
            user.id,
            reportedAmount ?? null,
            row.amount,
            description?.trim(),
          ],
        );
        await this.auditFinancial(
          client,
          user,
          "in_person_payment_disputed",
          "payment",
          paymentId,
          { status: row.status },
          { status: "observed", incidentId: incident.rows[0].id },
          description,
        );
        return {
          id: paymentId,
          status: "observed",
          incidentId: incident.rows[0].id,
        };
      }
      await client.query(
        `UPDATE payments SET status='paid',validated_by_user_id=$2,validated_at=now() WHERE id=$1`,
        [paymentId, user.id],
      );
      await client.query(
        `UPDATE payment_orders SET status='paid',updated_at=now() WHERE id=$1`,
        [row.payment_order_id],
      );
      await this.auditFinancial(
        client,
        user,
        "in_person_payment_confirmed",
        "payment",
        paymentId,
        { status: row.status },
        { status: "paid" },
      );
      return { id: paymentId, status: "paid" };
    });
  }

  review(
    user: RequestUser,
    paymentId: string,
    approved: boolean,
    reason?: string,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const payment = await client.query<{
        id: string;
        payment_order_id: string;
        amount: string;
        status: string;
      }>(
        `SELECT id,payment_order_id,amount::text,status::text FROM payments WHERE id=$1 FOR UPDATE`,
        [paymentId],
      );
      if (!payment.rows[0]) throw new NotFoundException("Pago no encontrado.");
      if (payment.rows[0].status !== "pending_validation")
        throw new ConflictException("El pago ya fue revisado.");
      const status = approved ? "paid" : "rejected";
      await client.query(
        `UPDATE payments SET status=$2::payment_status,validated_by_user_id=$3,validated_at=now(),rejection_reason=CASE WHEN $2::text='rejected' THEN NULLIF($4::text,'') ELSE NULL END WHERE id=$1`,
        [paymentId, status, user.id, reason?.trim() ?? ""],
      );
      await client.query(
        `UPDATE payment_orders SET status=$2::payment_status,updated_at=now() WHERE id=$1`,
        [payment.rows[0].payment_order_id, status],
      );
      if (approved)
        await this.creditCoinPurchase(
          client,
          user,
          payment.rows[0].payment_order_id,
          paymentId,
        );
      await this.propagatePaymentResult(
        client,
        payment.rows[0].payment_order_id,
        paymentId,
        approved,
        reason?.trim(),
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values,reason) VALUES($1,$2,'payments',$3,'payment',$4,jsonb_build_object('status',$5::text),NULLIF($6::text,''))`,
        [
          user.id,
          user.roleCode,
          approved ? "payment_approved" : "payment_rejected",
          paymentId,
          status,
          reason?.trim() ?? "",
        ],
      );
      const orderOwner = await client.query<{ user_id: string }>(
        `SELECT user_id FROM payment_orders WHERE id=$1`,
        [payment.rows[0].payment_order_id],
      );
      return { id: paymentId, status, userId: orderOwner.rows[0]?.user_id };
    });
  }

  reportIncident(
    user: RequestUser,
    paymentId: string,
    input: {
      incidentType: string;
      reportedAmount?: number;
      description: string;
    },
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO payment_incidents(payment_id,reported_by_user_id,incident_type,reported_amount,expected_amount,description) SELECT payment.id,$2,$3,$4,payment.amount,$5 FROM payments payment JOIN payment_orders payment_order ON payment_order.id=payment.payment_order_id WHERE payment.id=$1 AND (payment_order.user_id=$2 OR app_has_permission('payments.manage')) RETURNING id,status,created_at AS "createdAt"`,
        [
          paymentId,
          user.id,
          input.incidentType,
          input.reportedAmount ?? null,
          input.description.trim(),
        ],
      );
      if (!result.rows[0]) throw new NotFoundException("Pago no encontrado.");
      await this.auditFinancial(
        client,
        user,
        "payment_incident_reported",
        "payment_incident",
        result.rows[0].id,
        null,
        {
          status: "open",
          paymentId,
          incidentType: input.incidentType,
          reportedAmount: input.reportedAmount ?? null,
        },
        input.description,
      );
      return result.rows[0];
    });
  }

  resolveIncident(
    user: RequestUser,
    incidentId: string,
    input: ResolveIncidentInput,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const incident = await client.query<{
        id: string;
        payment_id: string;
        status: string;
        amount: string;
        payment_order_id: string;
        user_id: string;
        payment_status: string;
      }>(
        `SELECT incident.id,incident.payment_id,incident.status,
           payment.amount::text,payment.payment_order_id,payment_order.user_id,
           payment.status::text AS payment_status
         FROM payment_incidents incident
         JOIN payments payment ON payment.id=incident.payment_id
         JOIN payment_orders payment_order ON payment_order.id=payment.payment_order_id
         WHERE incident.id=$1 FOR UPDATE OF incident,payment,payment_order`,
        [incidentId],
      );
      const row = incident.rows[0];
      if (!row)
        throw new NotFoundException("Incidencia de pago no encontrada.");
      if (!["open", "in_review"].includes(row.status))
        throw new ConflictException("La incidencia ya fue resuelta.");

      let financialResult: unknown = null;
      if (input.action === "refund_fiat")
        financialResult = await this.refundFiat(
          client,
          user,
          row,
          input.amount!,
        );
      if (input.action === "return_coins")
        financialResult = await this.returnCoins(
          client,
          user,
          row,
          input.coinAmount!,
          incidentId,
        );

      const incidentStatus =
        input.action === "reject" ? "rejected" : "resolved";
      const result = await client.query(
        `UPDATE payment_incidents SET status=$2,resolved_by_user_id=$3,
           resolution=$4,resolved_at=now() WHERE id=$1
         RETURNING id,status,resolved_at AS "resolvedAt"`,
        [incidentId, incidentStatus, user.id, input.resolution.trim()],
      );
      await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at)
         VALUES($1,'payment.incident_resolved','in_app','Incidencia de pago resuelta',$2,'payment_incident',$3,'sent',now())`,
        [row.user_id, input.resolution.trim(), incidentId],
      );
      await this.auditFinancial(
        client,
        user,
        `payment_incident_${input.action}`,
        "payment_incident",
        incidentId,
        { status: row.status },
        { status: incidentStatus, financialResult },
        input.resolution,
      );
      return { ...result.rows[0], action: input.action, financialResult };
    });
  }

  incidents(user: RequestUser): Promise<unknown[]> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT incident.id,incident.payment_id AS "paymentId",incident.incident_type AS "incidentType",incident.reported_amount AS "reportedAmount",incident.expected_amount AS "expectedAmount",incident.description,incident.status,incident.resolution,incident.created_at AS "createdAt" FROM payment_incidents incident ORDER BY incident.created_at DESC LIMIT 200`,
          )
        ).rows,
    );
  }

  startIncidentReview(user: RequestUser, incidentId: string): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE payment_incidents SET status='in_review'
         WHERE id=$1 AND status='open' RETURNING id,status`,
        [incidentId],
      );
      if (!result.rows[0])
        throw new ConflictException("La incidencia no está abierta.");
      await this.auditFinancial(
        client,
        user,
        "payment_incident_review_started",
        "payment_incident",
        incidentId,
        { status: "open" },
        { status: "in_review" },
      );
      return result.rows[0];
    });
  }

  refunds(user: RequestUser): Promise<unknown[]> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT refund.id,refund.payment_id AS "paymentId",refund.amount,
               refund.reason,refund.status,refund.requested_at AS "requestedAt",
               refund.processed_at AS "processedAt"
             FROM refunds refund ORDER BY refund.requested_at DESC LIMIT 200`,
          )
        ).rows,
    );
  }

  private async creditCoinPurchase(
    client: import("pg").PoolClient,
    user: RequestUser,
    orderId: string,
    paymentId: string,
  ) {
    const purchase = await client.query<{
      id: string;
      user_id: string;
      purchased_coin_amount: string;
      bonus_coin_amount: string;
      coins_expire_after: string;
    }>(
      `SELECT purchase.id,purchase.user_id,purchase.purchased_coin_amount::text,purchase.bonus_coin_amount::text,coin_package.coins_expire_after::text FROM coin_purchases purchase JOIN coin_packages coin_package ON coin_package.id=purchase.package_id WHERE purchase.payment_order_id=$1 AND purchase.status='pending_payment' FOR UPDATE`,
      [orderId],
    );
    if (!purchase.rows[0]) return;
    const row = purchase.rows[0];
    const total =
      Number(row.purchased_coin_amount) + Number(row.bonus_coin_amount);
    const wallet = await client.query<{
      id: string;
      available_balance: string;
    }>(
      `INSERT INTO coin_wallets(user_id)VALUES($1)ON CONFLICT(user_id)DO UPDATE SET updated_at=now() RETURNING id,available_balance::text`,
      [row.user_id],
    );
    const balance = Number(wallet.rows[0].available_balance) + total;
    await client.query(
      `UPDATE coin_wallets SET available_balance=$2,lifetime_credited=lifetime_credited+$3,updated_at=now()WHERE id=$1`,
      [wallet.rows[0].id, balance, total],
    );
    const lot = await client.query<{ id: string }>(
      `INSERT INTO coin_lots(wallet_id,purchase_id,original_amount,remaining_amount,expires_at)VALUES($1,$2,$3,$3,now()+$4::interval)RETURNING id`,
      [wallet.rows[0].id, row.id, total, row.coins_expire_after],
    );
    const transaction = await client.query<{ id: string }>(
      `INSERT INTO coin_transactions(wallet_id,transaction_type,coin_amount,balance_after,payment_order_id,related_entity_type,related_entity_id,performed_by_user_id,reason)VALUES($1,'purchase',$2,$3,$4,'coin_purchase',$5,$6,'Compra de monedas aprobada')RETURNING id`,
      [wallet.rows[0].id, total, balance, orderId, row.id, user.id],
    );
    await client.query(
      `INSERT INTO coin_transaction_allocations(transaction_id,coin_lot_id,coin_amount)VALUES($1,$2,$3)`,
      [transaction.rows[0].id, lot.rows[0].id, total],
    );
    await client.query(
      `UPDATE coin_purchases SET payment_id=$2,status='credited',purchased_at=now(),credited_at=now()WHERE id=$1`,
      [row.id, paymentId],
    );
    await this.auditFinancial(
      client,
      user,
      "coin_purchase_credited",
      "coin_purchase",
      row.id,
      { status: "pending_payment" },
      {
        status: "credited",
        paymentId,
        transactionId: transaction.rows[0].id,
        coinLotId: lot.rows[0].id,
        coinAmount: total,
        balanceAfter: balance,
      },
    );
  }

  private async propagatePaymentResult(
    client: import("pg").PoolClient,
    orderId: string,
    paymentId: string,
    approved: boolean,
    reason?: string,
  ) {
    if (!approved) {
      await client.query(
        `UPDATE coin_purchases SET payment_id=$2,status='rejected' WHERE payment_order_id=$1 AND status='pending_payment'`,
        [orderId, paymentId],
      );
      await client.query(
        `UPDATE partner_subscriptions SET status='rejected',updated_at=now() WHERE payment_order_id=$1 AND status='pending_payment'`,
        [orderId],
      );
    } else {
      const subscriptions = await client.query<{
        id: string;
        partner_id: string;
      }>(
        `UPDATE partner_subscriptions subscription SET
           status='active',starts_at=COALESCE(starts_at,now()),
           ends_at=COALESCE(ends_at,COALESCE(subscription.starts_at,now())+CASE plan.billing_period
             WHEN 'annual' THEN interval '1 year'
             WHEN 'quarterly' THEN interval '3 months'
             ELSE interval '1 month' END),updated_at=now()
         FROM partner_subscription_plans plan
         WHERE subscription.plan_id=plan.id AND subscription.payment_order_id=$1
           AND subscription.status='pending_payment'
         RETURNING subscription.id,subscription.partner_id`,
        [orderId],
      );
      for (const subscription of subscriptions.rows)
        await client.query(
          `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at)
           SELECT partner_user.user_id,'subscription.activated','in_app','Suscripción empresarial activa','El pago fue aprobado y el plan empresarial está activo.','partner_subscription',$2,'sent',now()
           FROM partner_users partner_user WHERE partner_user.partner_id=$1 AND partner_user.is_active`,
          [subscription.partner_id, subscription.id],
        );
    }
    const order = await client.query<{ user_id: string }>(
      `SELECT user_id FROM payment_orders WHERE id=$1`,
      [orderId],
    );
    if (order.rows[0]) {
      const title = approved ? "Pago aprobado" : "Pago rechazado";
      const body = approved
        ? "Tu pago fue aprobado."
        : reason?.trim()
          ? `Tu pago fue rechazado: ${reason.trim()}`
          : "Tu pago fue rechazado. Revisa el motivo e intenta nuevamente.";
      await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at)
         VALUES($1,$2,'in_app',$3,$4,'payment',$5,'sent',now())`,
        [
          order.rows[0].user_id,
          approved ? "payment.approved" : "payment.rejected",
          title,
          body,
          paymentId,
        ],
      );
    }
  }

  private async debitCoins(
    client: import("pg").PoolClient,
    user: RequestUser,
    orderId: string,
    order: {
      coin_amount: string | null;
      service_id: string | null;
      appointment_id: string | null;
      emergency_id: string | null;
      related_entity_type: string | null;
      related_entity_id: string | null;
    },
  ) {
    const amount = Number(order.coin_amount);
    const wallet = await client.query<{
      id: string;
      available_balance: string;
      reserved_balance: string;
    }>(
      `SELECT id,available_balance::text,reserved_balance::text
       FROM coin_wallets WHERE user_id=$1 FOR UPDATE`,
      [user.id],
    );
    const current = wallet.rows[0];
    if (
      !current ||
      Number(current.available_balance) - Number(current.reserved_balance) <
        amount
    )
      throw new ConflictException("Saldo de monedas insuficiente.");

    const lots = await client.query<{
      id: string;
      remaining_amount: string;
    }>(
      `SELECT id,remaining_amount::text FROM coin_lots
       WHERE wallet_id=$1 AND remaining_amount>0 AND expired_at IS NULL AND expires_at>now()
       ORDER BY expires_at,credited_at FOR UPDATE`,
      [current.id],
    );
    let pending = amount;
    const allocations: Array<{ id: string; amount: number }> = [];
    for (const lot of lots.rows) {
      if (pending === 0) break;
      const consumed = Math.min(pending, Number(lot.remaining_amount));
      await client.query(
        `UPDATE coin_lots SET remaining_amount=remaining_amount-$2 WHERE id=$1`,
        [lot.id, consumed],
      );
      allocations.push({ id: lot.id, amount: consumed });
      pending -= consumed;
    }
    if (pending > 0)
      throw new ConflictException("Los lotes vigentes no cubren el cobro.");
    const balanceAfter = Number(current.available_balance) - amount;
    await client.query(
      `UPDATE coin_wallets SET available_balance=$2,lifetime_spent=lifetime_spent+$3,updated_at=now() WHERE id=$1`,
      [current.id, balanceAfter, amount],
    );
    const transaction = await client.query<{ id: string }>(
      `INSERT INTO coin_transactions(
         wallet_id,transaction_type,coin_amount,balance_after,payment_order_id,
         service_id,appointment_id,emergency_id,related_entity_type,
         related_entity_id,performed_by_user_id,reason
       )VALUES($1,'charge',$2,$3,$4,$5,$6,$7,$8,$9,$10,'Cobro aceptado por el usuario')
       RETURNING id`,
      [
        current.id,
        -amount,
        balanceAfter,
        orderId,
        order.service_id,
        order.appointment_id,
        order.emergency_id,
        order.related_entity_type,
        order.related_entity_id,
        user.id,
      ],
    );
    for (const allocation of allocations)
      await client.query(
        `INSERT INTO coin_transaction_allocations(transaction_id,coin_lot_id,coin_amount) VALUES($1,$2,$3)`,
        [transaction.rows[0].id, allocation.id, allocation.amount],
      );
    await client.query(
      `UPDATE payment_orders SET status='paid',accepted_at=now(),updated_at=now() WHERE id=$1`,
      [orderId],
    );
  }

  private async refundFiat(
    client: import("pg").PoolClient,
    user: RequestUser,
    payment: {
      payment_id: string;
      payment_order_id: string;
      amount: string;
      payment_status: string;
    },
    amount: number,
  ) {
    if (!["paid", "partially_refunded"].includes(payment.payment_status))
      throw new ConflictException("Solo se puede reembolsar un pago aprobado.");
    const totals = await client.query<{ total: string }>(
      `SELECT COALESCE(sum(amount),0)::text AS total FROM refunds
       WHERE payment_id=$1 AND status IN('pending','approved','processed')`,
      [payment.payment_id],
    );
    const alreadyRefunded = Number(totals.rows[0].total);
    if (alreadyRefunded + amount > Number(payment.amount))
      throw new BadRequestException("El reembolso supera el monto disponible.");

    const coinPurchase = await client.query<{
      id: string;
      user_id: string;
      total_coins: string;
      remaining_coins: string;
      wallet_id: string;
    }>(
      `SELECT purchase.id,purchase.user_id,
         (purchase.purchased_coin_amount+purchase.bonus_coin_amount)::text AS total_coins,
         COALESCE(sum(lot.remaining_amount),0)::text AS remaining_coins,
         lot.wallet_id
       FROM coin_purchases purchase
       LEFT JOIN coin_lots lot ON lot.purchase_id=purchase.id
       WHERE purchase.payment_id=$1 AND purchase.status='credited'
       GROUP BY purchase.id,purchase.user_id,lot.wallet_id`,
      [payment.payment_id],
    );
    if (coinPurchase.rows[0]) {
      const purchase = coinPurchase.rows[0];
      if (
        amount !== Number(payment.amount) ||
        Number(purchase.remaining_coins) !== Number(purchase.total_coins)
      )
        throw new ConflictException(
          "No se puede reembolsar la compra porque sus monedas ya fueron utilizadas o el reembolso no es total.",
        );
      const wallet = await client.query<{ available_balance: string }>(
        `SELECT available_balance::text FROM coin_wallets WHERE id=$1 FOR UPDATE`,
        [purchase.wallet_id],
      );
      const balanceAfter =
        Number(wallet.rows[0].available_balance) - Number(purchase.total_coins);
      if (balanceAfter < 0)
        throw new ConflictException(
          "El saldo actual no permite revertir la compra.",
        );
      await client.query(
        `UPDATE coin_lots SET remaining_amount=0,expired_at=now() WHERE purchase_id=$1`,
        [purchase.id],
      );
      await client.query(
        `UPDATE coin_wallets SET available_balance=$2,lifetime_credited=lifetime_credited-$3,updated_at=now() WHERE id=$1`,
        [purchase.wallet_id, balanceAfter, purchase.total_coins],
      );
      await client.query(
        `INSERT INTO coin_transactions(wallet_id,transaction_type,coin_amount,balance_after,payment_order_id,related_entity_type,related_entity_id,performed_by_user_id,reason) VALUES($1,'refund',$2,$3,$4,'coin_purchase',$5,$6,'Reversión por reembolso fiat')`,
        [
          purchase.wallet_id,
          -Number(purchase.total_coins),
          balanceAfter,
          payment.payment_order_id,
          purchase.id,
          user.id,
        ],
      );
      await client.query(
        `UPDATE coin_purchases SET status='refunded' WHERE id=$1`,
        [purchase.id],
      );
    }

    const refund = await client.query(
      `INSERT INTO refunds(payment_id,requested_by_user_id,approved_by_user_id,amount,reason,status,processed_at)
       VALUES($1,$2,$2,$3,'Resolución de incidencia','processed',now())
       RETURNING id,amount,status,processed_at AS "processedAt"`,
      [payment.payment_id, user.id, amount],
    );
    const fullyRefunded = alreadyRefunded + amount === Number(payment.amount);
    const status = fullyRefunded ? "refunded" : "partially_refunded";
    await client.query(
      `UPDATE payments SET status=$2::payment_status WHERE id=$1`,
      [payment.payment_id, status],
    );
    await client.query(
      `UPDATE payment_orders SET status=$2::payment_status,updated_at=now() WHERE id=$1`,
      [payment.payment_order_id, status],
    );
    if (fullyRefunded)
      await client.query(
        `UPDATE partner_subscriptions SET status='cancelled',cancelled_at=now(),cancellation_reason='Pago reembolsado',updated_at=now() WHERE payment_order_id=$1 AND status IN('active','grace_period')`,
        [payment.payment_order_id],
      );
    return refund.rows[0];
  }

  private async returnCoins(
    client: import("pg").PoolClient,
    user: RequestUser,
    payment: { user_id: string; payment_order_id: string },
    coinAmount: number,
    incidentId: string,
  ) {
    if (!Number.isInteger(coinAmount))
      throw new BadRequestException(
        "La devolución debe ser una cantidad entera de monedas.",
      );
    const wallet = await client.query<{
      id: string;
      available_balance: string;
    }>(
      `INSERT INTO coin_wallets(user_id) VALUES($1)
       ON CONFLICT(user_id) DO UPDATE SET updated_at=now()
       RETURNING id,available_balance::text`,
      [payment.user_id],
    );
    const balanceAfter = Number(wallet.rows[0].available_balance) + coinAmount;
    await client.query(
      `UPDATE coin_wallets SET available_balance=$2,lifetime_credited=lifetime_credited+$3,updated_at=now() WHERE id=$1`,
      [wallet.rows[0].id, balanceAfter, coinAmount],
    );
    const lot = await client.query<{ id: string }>(
      `INSERT INTO coin_lots(wallet_id,original_amount,remaining_amount,expires_at) VALUES($1,$2,$2,now()+interval '1 year') RETURNING id`,
      [wallet.rows[0].id, coinAmount],
    );
    const transaction = await client.query<{ id: string }>(
      `INSERT INTO coin_transactions(wallet_id,transaction_type,coin_amount,balance_after,payment_order_id,related_entity_type,related_entity_id,performed_by_user_id,reason) VALUES($1,'refund',$2,$3,$4,'payment_incident',$5,$6,'Devolución de monedas por incidencia') RETURNING id`,
      [
        wallet.rows[0].id,
        coinAmount,
        balanceAfter,
        payment.payment_order_id,
        incidentId,
        user.id,
      ],
    );
    await client.query(
      `INSERT INTO coin_transaction_allocations(transaction_id,coin_lot_id,coin_amount) VALUES($1,$2,$3)`,
      [transaction.rows[0].id, lot.rows[0].id, coinAmount],
    );
    return {
      transactionId: transaction.rows[0].id,
      coinLotId: lot.rows[0].id,
      coinAmount,
      balanceAfter,
    };
  }

  private async auditFinancial(
    client: import("pg").PoolClient,
    user: RequestUser,
    action: string,
    entityType: string,
    entityId: string,
    oldValues: unknown,
    newValues: unknown,
    reason?: string,
  ) {
    await client.query(
      `INSERT INTO audit_events(
         actor_user_id,actor_role,module,action,entity_type,entity_id,
         old_values,new_values,reason
       )VALUES($1,$2,'payments',$3,$4,$5,$6::jsonb,$7::jsonb,NULLIF($8,''))`,
      [
        user.id,
        user.roleCode,
        action,
        entityType,
        entityId,
        oldValues == null ? null : JSON.stringify(oldValues),
        newValues == null ? null : JSON.stringify(newValues),
        reason?.trim() ?? "",
      ],
    );
  }
}
