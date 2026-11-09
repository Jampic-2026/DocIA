import {
  SendAiMessageDto,
  EndVoiceSessionDto,
  StartVoiceSessionDto,
} from "../../domain/ai-inputs";
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { MeetSpace } from "../../../integrations/domain/ports/meet-provider";
import {
  CHAT_MESSAGE_COST,
  FREE_WEEKLY_COINS,
  VOICE_COST_PER_STARTED_MINUTE,
  VOICE_MAX_MINUTES,
} from "../../domain/ai-persistence-types";
import { AiRepository } from "../../domain/ports/ai.repository";

@Injectable()
export class PostgresAiRepository implements AiRepository {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}
  prepareChatMessage(
    user: RequestUser,
    input: SendAiMessageDto,
    message: string,
    configurationValue1: string | undefined,
  ): Promise<{
    conversationId: string;
    patientId: string;
    charge: {
      transactionId: string;
      amount: number;
      balanceAfter: number;
      allocations: { id: string; amount: number }[];
      relatedEntityType: string;
      relatedEntityId: string;
    };
    history: { role: "user" | "assistant"; content: string }[];
  }> {
    return this.database.transactionAsUser(user, async (client) => {
      await this.ensureWeeklyFreeCoins(client, user);
      const patient = await client.query<{ id: string }>(
        `SELECT patient.id FROM patients patient
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1 LIMIT 1`,
        [user.id],
      );
      if (!patient.rows[0]) {
        throw new NotFoundException(
          "La cuenta no tiene un perfil de paciente.",
        );
      }

      let conversationId = input.conversationId;
      if (conversationId) {
        const existing = await client.query(
          `SELECT 1 FROM ai_conversations
           WHERE id=$1 AND patient_id=$2 AND status='active'`,
          [conversationId, patient.rows[0].id],
        );
        if (!existing.rows[0]) {
          throw new NotFoundException(
            "La conversación no existe o está cerrada.",
          );
        }
      } else {
        const created = await client.query<{ id: string }>(
          `INSERT INTO ai_conversations
           (patient_id,created_by_user_id,title,model_name,prompt_version)
           VALUES($1,$2,$3,$4,'orientation-v1') RETURNING id`,
          [
            patient.rows[0].id,
            user.id,
            message.slice(0, 120),
            configurationValue1,
          ],
        );
        conversationId = created.rows[0].id;
      }
      await client.query(
        `INSERT INTO ai_messages(conversation_id,sender,message)
         VALUES($1,'user',$2)`,
        [conversationId, message],
      );
      const charge = await this.debitCoins(
        client,
        user,
        CHAT_MESSAGE_COST,
        "ai_chat_message",
        conversationId,
        "Mensaje de chat IA",
      );
      const history = await client.query<{
        sender: "user" | "assistant";
        message: string;
      }>(
        `SELECT sender,message FROM ai_messages
         WHERE conversation_id=$1 AND sender IN('user','assistant')
         ORDER BY created_at DESC LIMIT 12`,
        [conversationId],
      );
      return {
        conversationId,
        patientId: patient.rows[0].id,
        charge,
        history: history.rows.reverse().map((row) => ({
          role: row.sender,
          content: row.message,
        })),
      };
    });
  }
  refundChatCharge(
    user: RequestUser,
    prepared: {
      conversationId: string;
      patientId: string;
      charge: {
        transactionId: string;
        amount: number;
        balanceAfter: number;
        allocations: { id: string; amount: number }[];
        relatedEntityType: string;
        relatedEntityId: string;
      };
      history: { role: "user" | "assistant"; content: string }[];
    },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await this.refundDebit(
        client,
        user,
        prepared.charge,
        "Devolución automática por fallo del proveedor IA",
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,
             action,entity_type,entity_id,new_values)
           VALUES($1,$2,$3,'ai','ai_provider_failed','ai_conversation',$4,
             jsonb_build_object('provider','openai'))`,
        [user.id, user.roleCode, prepared.patientId, prepared.conversationId],
      );
    });
  }
  saveChatResponse(
    prepared: {
      conversationId: string;
      patientId: string;
      charge: {
        transactionId: string;
        amount: number;
        balanceAfter: number;
        allocations: { id: string; amount: number }[];
        relatedEntityType: string;
        relatedEntityId: string;
      };
      history: { role: "user" | "assistant"; content: string }[];
    },
    reply: string,
    user: RequestUser,
    urgent: boolean,
    safetyData?: Record<string, unknown>,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `INSERT INTO ai_messages(conversation_id,sender,message,safety_flags)
         VALUES($1,'assistant',$2,$3::jsonb)`,
        [
          prepared.conversationId,
          reply,
          JSON.stringify({ urgent, ...safetyData }),
        ],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,
           action,entity_type,entity_id,new_values)
         VALUES($1,$2,$3,'ai','ai_chat_message_charged','ai_conversation',$4,$5::jsonb)`,
        [
          user.id,
          user.roleCode,
          prepared.patientId,
          prepared.conversationId,
          JSON.stringify({
            coinAmount: CHAT_MESSAGE_COST,
            transactionId: prepared.charge.transactionId,
          }),
        ],
      );
    });
  }
  chatBalance(user: RequestUser): Promise<number> {
    return this.database.transactionAsUser(user, (client) =>
      this.availableCoinBalance(client, user),
    );
  }
  prepareVoiceSession(
    user: RequestUser,
  ): Promise<{ patientId: string; maxBillableMinutes: number }> {
    return this.database.transactionAsUser(user, async (client) => {
      await this.ensureWeeklyFreeCoins(client, user);
      const availableCoins = await this.availableCoinBalance(client, user);
      if (availableCoins < VOICE_COST_PER_STARTED_MINUTE) {
        throw new ConflictException("Saldo de monedas insuficiente.");
      }
      const patientId = await this.findPatientId(client, user);
      const active = await client.query(
        `SELECT id FROM ai_voice_sessions
         WHERE user_id=$1 AND status='active'
         ORDER BY started_at DESC LIMIT 1`,
        [user.id],
      );
      if (active.rows[0]) {
        throw new ConflictException("Ya tienes una llamada de voz activa.");
      }
      return {
        patientId,
        maxBillableMinutes: Math.min(
          VOICE_MAX_MINUTES,
          Math.floor(availableCoins / VOICE_COST_PER_STARTED_MINUTE),
        ),
      };
    });
  }
  createVoiceSession(
    user: RequestUser,
    prepared: { patientId: string; maxBillableMinutes: number },
    input: StartVoiceSessionDto,
    space: MeetSpace,
  ): Promise<any> {
    return this.database.transactionAsUser(user, async (client) => {
      const active = await client.query(
        `SELECT id FROM ai_voice_sessions
         WHERE user_id=$1 AND status='active'
         ORDER BY started_at DESC LIMIT 1`,
        [user.id],
      );
      if (active.rows[0]) {
        throw new ConflictException("Ya tienes una llamada de voz activa.");
      }
      const session = await client.query(
        `INSERT INTO ai_voice_sessions(user_id,patient_id,topic,meeting_url,
           external_meeting_id,max_billable_minutes)
         VALUES($1,$2,NULLIF($3,''),$4,$5,$6)
         RETURNING id,meeting_url AS "meetingUrl",started_at AS "startedAt",
           max_billable_minutes AS "maxBillableMinutes",status`,
        [
          user.id,
          prepared.patientId,
          input.topic?.trim() ?? "",
          space.meetingUri,
          space.name,
          prepared.maxBillableMinutes,
        ],
      );
      return {
        ...session.rows[0],
        warningAtMinutes: Math.max(1, prepared.maxBillableMinutes - 2),
        cutoffAtMinutes: prepared.maxBillableMinutes,
        costPerStartedMinute: VOICE_COST_PER_STARTED_MINUTE,
        message:
          "Si tus monedas se agotan, la llamada se cortará automáticamente.",
      };
    });
  }
  endVoiceSession(input: EndVoiceSessionDto, user: RequestUser): Promise<any> {
    return this.database.transactionAsUser(user, async (client) => {
      const session = await client.query<{
        id: string;
        patient_id: string;
        started_at: Date;
        max_billable_minutes: number;
        status: string;
      }>(
        `SELECT id,patient_id,started_at,max_billable_minutes,status FROM ai_voice_sessions
         WHERE id=$1 AND user_id=$2 FOR UPDATE`,
        [input.sessionId, user.id],
      );
      const row = session.rows[0];
      if (!row) throw new NotFoundException("Llamada de voz no encontrada.");
      if (row.status !== "active")
        throw new ConflictException("La llamada ya fue finalizada.");
      const elapsedMs = Date.now() - row.started_at.getTime();
      const elapsedMinutes = Math.max(1, Math.ceil(elapsedMs / 60000));
      const billedMinutes = Math.min(
        elapsedMinutes,
        row.max_billable_minutes,
        VOICE_MAX_MINUTES,
      );
      const charge = await this.debitCoins(
        client,
        user,
        billedMinutes * VOICE_COST_PER_STARTED_MINUTE,
        "ai_voice_call",
        row.id,
        `Llamada de voz IA (${billedMinutes} min)`,
      );
      const updated = await client.query(
        `UPDATE ai_voice_sessions SET status='completed',ended_at=now(),
           billed_minutes=$2,coin_transaction_id=$3
         WHERE id=$1 RETURNING id,started_at AS "startedAt",
           ended_at AS "endedAt",billed_minutes AS "billedMinutes",status`,
        [row.id, billedMinutes, charge.transactionId],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,
           action,entity_type,entity_id,new_values)
         VALUES($1,$2,$3,'ai','ai_voice_call_charged','ai_voice_session',$4,$5::jsonb)`,
        [
          user.id,
          user.roleCode,
          row.patient_id,
          row.id,
          JSON.stringify({
            billedMinutes,
            coinAmount: billedMinutes * VOICE_COST_PER_STARTED_MINUTE,
            transactionId: charge.transactionId,
          }),
        ],
      );
      return {
        ...updated.rows[0],
        coinCost: billedMinutes * VOICE_COST_PER_STARTED_MINUTE,
        cutoffReached: elapsedMinutes >= row.max_billable_minutes,
      };
    });
  }
  listConversations(user: RequestUser): Promise<{ items: any[] }> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT conversation.id,conversation.title,
          conversation.model_name AS "modelName",conversation.status,
          conversation.created_at AS "createdAt",conversation.closed_at AS "closedAt",
          (SELECT message.message FROM ai_messages message
            WHERE message.conversation_id=conversation.id ORDER BY message.created_at DESC LIMIT 1) AS "lastMessage"
        FROM ai_conversations conversation WHERE conversation.created_by_user_id=$1
        ORDER BY conversation.created_at DESC`,
        [user.id],
      );
      return { items: result.rows };
    });
  }
  listMessages(
    conversationId: string,
    user: RequestUser,
  ): Promise<{ items: any[] }> {
    return this.database.transactionAsUser(user, async (client) => {
      const conversation = await client.query(
        `SELECT 1 FROM ai_conversations
        WHERE id=$1 AND created_by_user_id=$2`,
        [conversationId, user.id],
      );
      if (!conversation.rowCount)
        throw new NotFoundException("La conversación no existe.");
      const messages = await client.query(
        `SELECT id,sender,message,
          safety_flags AS "safetyFlags",created_at AS "createdAt"
        FROM ai_messages WHERE conversation_id=$1 ORDER BY created_at`,
        [conversationId],
      );
      return { items: messages.rows };
    });
  }
  closeConversation(
    conversationId: string,
    user: RequestUser,
  ): Promise<{ closed: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE ai_conversations SET status='closed',closed_at=now()
        WHERE id=$1 AND created_by_user_id=$2 AND status='active' RETURNING id`,
        [conversationId, user.id],
      );
      if (!result.rowCount)
        throw new NotFoundException(
          "La conversación no existe o ya está cerrada.",
        );
      return { closed: true };
    });
  }
  listRiskAssessments(user: RequestUser): Promise<{ items: any[] }> {
    return this.database.transactionAsUser(user, async (client) => ({
      items: (
        await client.query(
          `SELECT id,conversation_id AS "conversationId",patient_id AS "patientId",risk_level AS "riskLevel",reasons,recommended_action AS "recommendedAction",user_decision AS "userDecision",created_at AS "createdAt" FROM ai_risk_assessments ORDER BY created_at DESC LIMIT 200`,
        )
      ).rows,
    }));
  }
  maintainVoiceSessions(user: RequestUser): Promise<{ closed: number }> {
    return this.database.transactionAsUser(user, async (client) => {
      const expired = await client.query<{
        id: string;
        user_id: string;
        patient_id: string;
        started_at: Date;
        max_billable_minutes: number;
      }>(
        `SELECT id,user_id,patient_id,started_at,max_billable_minutes
         FROM ai_voice_sessions
         WHERE status='active'
           AND started_at + (max_billable_minutes::text || ' minutes')::interval <= now()
         ORDER BY started_at
         FOR UPDATE SKIP LOCKED`,
      );
      let closed = 0;
      for (const row of expired.rows) {
        const sessionUser: RequestUser = {
          ...user,
          id: row.user_id,
          sessionId: `ai-maintenance:${user.sessionId}`,
        };
        const charge = await this.debitCoins(
          client,
          sessionUser,
          row.max_billable_minutes * VOICE_COST_PER_STARTED_MINUTE,
          "ai_voice_call",
          row.id,
          `Cierre automático de llamada de voz IA (${row.max_billable_minutes} min)`,
        );
        await client.query(
          `UPDATE ai_voice_sessions SET status='completed',ended_at=now(),
             billed_minutes=$2,coin_transaction_id=$3
           WHERE id=$1`,
          [row.id, row.max_billable_minutes, charge.transactionId],
        );
        await client.query(
          `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,
             action,entity_type,entity_id,new_values)
           VALUES($1,$2,$3,'ai','ai_voice_call_auto_closed',
             'ai_voice_session',$4,$5::jsonb)`,
          [
            user.id,
            user.roleCode,
            row.patient_id,
            row.id,
            JSON.stringify({
              billedMinutes: row.max_billable_minutes,
              coinAmount:
                row.max_billable_minutes * VOICE_COST_PER_STARTED_MINUTE,
              transactionId: charge.transactionId,
            }),
          ],
        );
        closed += 1;
      }
      return { closed };
    });
  }
  private async findPatientId(
    client: import("pg").PoolClient,
    user: RequestUser,
  ) {
    const patient = await client.query<{ id: string }>(
      `SELECT patient.id FROM patients patient
       JOIN persons person ON person.id=patient.person_id
       WHERE person.user_id=$1 LIMIT 1`,
      [user.id],
    );
    if (!patient.rows[0]) {
      throw new NotFoundException("La cuenta no tiene un perfil de paciente.");
    }
    return patient.rows[0].id;
  }
  private async ensureWeeklyFreeCoins(
    client: import("pg").PoolClient,
    user: RequestUser,
  ) {
    await client.query(
      `SELECT pg_advisory_xact_lock(hashtext('weekly-free-coins:'||$1))`,
      [user.id],
    );
    const wallet = await client.query<{
      id: string;
      available_balance: string;
    }>(
      `INSERT INTO coin_wallets(user_id)
       VALUES($1)
       ON CONFLICT(user_id) DO UPDATE SET updated_at=now()
       RETURNING id,available_balance::text`,
      [user.id],
    );
    const current = wallet.rows[0];
    const week = await client.query<{ week_start: string; expires_at: Date }>(
      `SELECT date_trunc('week', now() AT TIME ZONE 'America/La_Paz')::date::text AS week_start,
        ((date_trunc('week', now() AT TIME ZONE 'America/La_Paz') + interval '7 days')
          AT TIME ZONE 'America/La_Paz') AS expires_at`,
    );
    const existing = await client.query(
      `SELECT 1 FROM weekly_free_coin_grants
       WHERE user_id=$1 AND week_start=$2`,
      [user.id, week.rows[0].week_start],
    );
    if (existing.rows[0]) return;

    const balanceAfter = Number(current.available_balance) + FREE_WEEKLY_COINS;
    const lot = await client.query<{ id: string }>(
      `INSERT INTO coin_lots(wallet_id,original_amount,remaining_amount,expires_at)
       VALUES($1,$2,$2,$3) RETURNING id`,
      [current.id, FREE_WEEKLY_COINS, week.rows[0].expires_at],
    );
    await client.query(
      `UPDATE coin_wallets SET available_balance=$2,
         lifetime_credited=lifetime_credited+$3,updated_at=now()
       WHERE id=$1`,
      [current.id, balanceAfter, FREE_WEEKLY_COINS],
    );
    const transaction = await client.query<{ id: string }>(
      `INSERT INTO coin_transactions(wallet_id,transaction_type,coin_amount,
         balance_after,related_entity_type,related_entity_id,performed_by_user_id,reason)
       VALUES($1,'bonus',$2,$3,'weekly_free_coin_grant',$4,$5,
         'Beneficio semanal gratuito para consultas IA')
       RETURNING id`,
      [current.id, FREE_WEEKLY_COINS, balanceAfter, lot.rows[0].id, user.id],
    );
    await client.query(
      `INSERT INTO coin_transaction_allocations(transaction_id,coin_lot_id,coin_amount)
       VALUES($1,$2,$3)`,
      [transaction.rows[0].id, lot.rows[0].id, FREE_WEEKLY_COINS],
    );
    await client.query(
      `INSERT INTO weekly_free_coin_grants(user_id,wallet_id,coin_lot_id,week_start,coin_amount)
       VALUES($1,$2,$3,$4,$5)`,
      [
        user.id,
        current.id,
        lot.rows[0].id,
        week.rows[0].week_start,
        FREE_WEEKLY_COINS,
      ],
    );
  }
  private async assertCoinBalance(
    client: import("pg").PoolClient,
    user: RequestUser,
    amount: number,
  ) {
    const available = await this.availableCoinBalance(client, user);
    if (available < amount) {
      throw new ConflictException("Saldo de monedas insuficiente.");
    }
  }
  private async availableCoinBalance(
    client: import("pg").PoolClient,
    user: RequestUser,
  ) {
    const wallet = await client.query<{
      available_balance: string;
      reserved_balance: string;
    }>(
      `SELECT available_balance::text,reserved_balance::text
       FROM coin_wallets WHERE user_id=$1`,
      [user.id],
    );
    return (
      Number(wallet.rows[0]?.available_balance ?? 0) -
      Number(wallet.rows[0]?.reserved_balance ?? 0)
    );
  }
  private async debitCoins(
    client: import("pg").PoolClient,
    user: RequestUser,
    amount: number,
    relatedEntityType: string,
    relatedEntityId: string,
    reason: string,
  ) {
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new BadRequestException("El cobro debe ser una cantidad entera.");
    }
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
    if (!current) throw new ConflictException("Saldo de monedas insuficiente.");
    if (
      Number(current.available_balance) - Number(current.reserved_balance) <
      amount
    ) {
      throw new ConflictException("Saldo de monedas insuficiente.");
    }
    const lots = await client.query<{
      id: string;
      remaining_amount: string;
    }>(
      `SELECT lot.id,lot.remaining_amount::text
       FROM coin_lots lot
       LEFT JOIN weekly_free_coin_grants free_grant ON free_grant.coin_lot_id=lot.id
       WHERE lot.wallet_id=$1 AND lot.remaining_amount>0
         AND lot.expired_at IS NULL AND lot.expires_at>now()
       ORDER BY CASE WHEN free_grant.id IS NULL THEN 1 ELSE 0 END,
         lot.expires_at,lot.credited_at
       FOR UPDATE OF lot`,
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
    if (pending > 0) {
      throw new ConflictException("Saldo de monedas insuficiente.");
    }
    const balanceAfter = Number(current.available_balance) - amount;
    await client.query(
      `UPDATE coin_wallets SET available_balance=$2,
         lifetime_spent=lifetime_spent+$3,updated_at=now()
       WHERE id=$1`,
      [current.id, balanceAfter, amount],
    );
    const transaction = await client.query<{ id: string }>(
      `INSERT INTO coin_transactions(wallet_id,transaction_type,coin_amount,
         balance_after,related_entity_type,related_entity_id,performed_by_user_id,reason)
       VALUES($1,'charge',$2,$3,$4,$5,$6,$7) RETURNING id`,
      [
        current.id,
        -amount,
        balanceAfter,
        relatedEntityType,
        relatedEntityId,
        user.id,
        reason,
      ],
    );
    for (const allocation of allocations) {
      await client.query(
        `INSERT INTO coin_transaction_allocations(transaction_id,coin_lot_id,coin_amount)
         VALUES($1,$2,$3)`,
        [transaction.rows[0].id, allocation.id, allocation.amount],
      );
    }
    return {
      transactionId: transaction.rows[0].id,
      amount,
      balanceAfter,
      allocations,
      relatedEntityType,
      relatedEntityId,
    };
  }
  private async refundDebit(
    client: import("pg").PoolClient,
    user: RequestUser,
    charge: {
      transactionId: string;
      amount: number;
      allocations: Array<{ id: string; amount: number }>;
      relatedEntityType: string;
      relatedEntityId: string;
    },
    reason: string,
  ) {
    const wallet = await client.query<{
      id: string;
      available_balance: string;
    }>(
      `SELECT id,available_balance::text FROM coin_wallets
       WHERE user_id=$1 FOR UPDATE`,
      [user.id],
    );
    const current = wallet.rows[0];
    if (!current) return;
    for (const allocation of charge.allocations) {
      await client.query(
        `UPDATE coin_lots SET remaining_amount=remaining_amount+$2 WHERE id=$1`,
        [allocation.id, allocation.amount],
      );
    }
    const balanceAfter = Number(current.available_balance) + charge.amount;
    await client.query(
      `UPDATE coin_wallets SET available_balance=$2,
         lifetime_spent=GREATEST(lifetime_spent-$3,0),updated_at=now()
       WHERE id=$1`,
      [current.id, balanceAfter, charge.amount],
    );
    const refund = await client.query<{ id: string }>(
      `INSERT INTO coin_transactions(wallet_id,transaction_type,coin_amount,
         balance_after,related_entity_type,related_entity_id,performed_by_user_id,reason)
       VALUES($1,'refund',$2,$3,$4,$5,$6,$7) RETURNING id`,
      [
        current.id,
        charge.amount,
        balanceAfter,
        charge.relatedEntityType,
        charge.relatedEntityId,
        user.id,
        reason,
      ],
    );
    for (const allocation of charge.allocations) {
      await client.query(
        `INSERT INTO coin_transaction_allocations(transaction_id,coin_lot_id,coin_amount)
         VALUES($1,$2,$3)`,
        [refund.rows[0].id, allocation.id, allocation.amount],
      );
    }
  }
}
