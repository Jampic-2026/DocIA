import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { CoinOverview } from "../../domain/coin-overview";
import {
  CoinResource,
  CoinPackageInput,
  CoinsRepository,
} from "../../domain/ports/coins.repository";
@Injectable()
export class PostgresCoinsRepository implements CoinsRepository {
  constructor(private readonly database: DatabaseService) {}
  overview(user: RequestUser): Promise<CoinOverview> {
    return this.database.transactionAsUser(user, async (client) => {
      await this.expireLots(client, user, user.id);
      await this.notifyExpiringLots(client, user.id);
      const wallet = await client.query(
        `SELECT id,available_balance,reserved_balance,lifetime_credited,lifetime_spent
    FROM coin_wallets WHERE user_id=$1`,
        [user.id],
      );
      const row = wallet.rows[0];
      const transactions = row
        ? await client.query(
            `SELECT id,transaction_type,coin_amount,balance_after,reason,created_at
    FROM coin_transactions WHERE wallet_id=$1 ORDER BY created_at DESC LIMIT 50`,
            [row.id],
          )
        : { rows: [] };
      const packages =
        await client.query(`SELECT id,code,name,description,coin_amount,bonus_coin_amount,price,currency,qr_image_url,is_active
    FROM coin_packages
    WHERE (
      is_active AND valid_from<=now() AND(valid_until IS NULL OR valid_until>now())
    ) OR app_has_role('admin') OR app_has_permission('coins.manage')
    ORDER BY coin_amount`);
      return {
        availableBalance: Number(row?.available_balance ?? 0),
        reservedBalance: Number(row?.reserved_balance ?? 0),
        lifetimeCredited: Number(row?.lifetime_credited ?? 0),
        lifetimeSpent: Number(row?.lifetime_spent ?? 0),
        transactions: transactions.rows.map((t) => ({
          id: t.id,
          type: t.transaction_type,
          amount: Number(t.coin_amount),
          balanceAfter: Number(t.balance_after),
          reason: t.reason,
          createdAt: t.created_at,
        })),
        packages: packages.rows.map((p) => ({
          id: p.id,
          code: p.code,
          name: p.name,
          description: p.description,
          coinAmount: Number(p.coin_amount),
          bonusCoinAmount: Number(p.bonus_coin_amount),
          price: Number(p.price),
          currency: p.currency,
          qrImageUrl: p.qr_image_url,
          isActive: p.is_active,
        })),
      };
    });
  }

  processMaintenance(user: RequestUser): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const users = await client.query<{ user_id: string }>(
        `SELECT DISTINCT user_id FROM coin_wallets ORDER BY user_id`,
      );
      let expiredLots = 0;
      let notificationsCreated = 0;
      for (const row of users.rows) {
        expiredLots += await this.expireLots(client, user, row.user_id);
        notificationsCreated += await this.notifyExpiringLots(
          client,
          row.user_id,
        );
      }
      await client.query(
        `UPDATE payment_orders SET status='expired',updated_at=now()
         WHERE status IN('pending','accepted') AND due_at IS NOT NULL AND due_at<now()`,
      );
      return {
        processedUsers: users.rowCount,
        expiredLots,
        notificationsCreated,
      };
    });
  }
  resource(user: RequestUser, resource: CoinResource): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const queries: Record<CoinResource, string> = {
        "coin-purchases": `SELECT id,user_id AS "userId",package_id AS "packageId",payment_order_id AS "paymentOrderId",status,purchased_coin_amount AS "baseCoins",bonus_coin_amount AS "bonusCoins",(purchased_coin_amount+bonus_coin_amount) AS "totalCoins",created_at AS "createdAt" FROM coin_purchases ORDER BY created_at DESC LIMIT 100`,
        "coin-lots": `SELECT id,wallet_id AS "walletId",purchase_id AS "purchaseId",original_amount AS "originalAmount",remaining_amount AS "remainingAmount",credited_at AS "creditedAt",expires_at AS "expiresAt",expired_at AS "expiredAt",created_at AS "createdAt",CASE WHEN expired_at IS NOT NULL OR expires_at<=now() THEN 'expired' WHEN remaining_amount=0 THEN 'depleted' WHEN expires_at<=now()+interval '30 days' THEN 'expiring' ELSE 'active' END AS status FROM coin_lots ORDER BY expires_at LIMIT 100`,
        "coin-transaction-allocations": `SELECT allocation.transaction_id AS "transactionId",allocation.coin_lot_id AS "coinLotId",allocation.coin_amount AS "coinAmount" FROM coin_transaction_allocations allocation`,
      };
      return (await client.query(queries[resource])).rows;
    });
  }

  purchase(user: RequestUser, packageId: string): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const packageResult = await client.query<{
        id: string;
        name: string;
        coin_amount: string;
        bonus_coin_amount: string;
        price: string;
        currency: string;
      }>(
        `SELECT id,name,coin_amount::text,bonus_coin_amount::text,price::text,currency
         FROM coin_packages
         WHERE id=$1 AND is_active AND valid_from<=now()
           AND(valid_until IS NULL OR valid_until>now())`,
        [packageId],
      );
      const selectedPackage = packageResult.rows[0];
      if (!selectedPackage)
        throw new NotFoundException("Paquete de monedas no disponible.");

      const openPurchase = await client.query(
        `SELECT purchase.id,purchase.payment_order_id AS "paymentOrderId"
         FROM coin_purchases purchase
         JOIN payment_orders payment_order ON payment_order.id=purchase.payment_order_id
         WHERE purchase.user_id=$1 AND purchase.package_id=$2
           AND purchase.status='pending_payment'
           AND payment_order.status IN('pending','pending_validation')
         ORDER BY purchase.created_at DESC LIMIT 1`,
        [user.id, packageId],
      );
      if (openPurchase.rows[0])
        throw new ConflictException(
          "Ya tienes una compra pendiente para este paquete.",
        );

      const order = await client.query<{ id: string }>(
         `INSERT INTO payment_orders(
           user_id,related_entity_type,related_entity_id,concept,
           charge_mode,amount,currency,status,due_at
         )VALUES($1::uuid,'coin_package',$2::uuid,$3,'fiat',$4::numeric,$5::char(3),'pending',now()+interval '24 hours')
         RETURNING id`,
        [
          user.id,
          packageId,
          `Compra de paquete ${selectedPackage.name}`,
          selectedPackage.price,
          selectedPackage.currency,
        ],
      );
      const purchase = await client.query(
        `INSERT INTO coin_purchases(
           user_id,package_id,payment_order_id,purchased_coin_amount,
           bonus_coin_amount,status
         )VALUES($1,$2,$3,$4,$5,'pending_payment')
         RETURNING id,status,created_at AS "createdAt"`,
        [
          user.id,
          packageId,
          order.rows[0].id,
          selectedPackage.coin_amount,
          selectedPackage.bonus_coin_amount,
        ],
      );
      await client.query(
         `INSERT INTO audit_events(
           actor_user_id,actor_role,module,action,entity_type,entity_id,new_values
         )VALUES($1,$2,'coins','coin_purchase_created','coin_purchase',$3,
           jsonb_build_object('packageId',$4::text,'paymentOrderId',$5::text,
             'amount',$6::numeric,'currency',$7::text,'status','pending_payment'))`,
        [user.id,user.roleCode,purchase.rows[0].id,packageId,order.rows[0].id,selectedPackage.price,selectedPackage.currency],
      );
      return {
        ...purchase.rows[0],
        paymentOrderId: order.rows[0].id,
        amount: Number(selectedPackage.price),
        currency: selectedPackage.currency,
      };
    });
  }

  createPackage(user: RequestUser, input: CoinPackageInput): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO coin_packages(
           code,name,description,coin_amount,bonus_coin_amount,price,currency,qr_image_url,is_active
         )VALUES(UPPER($1),$2,NULLIF($3,''),$4,$5,$6,UPPER($7),NULLIF($8,''),$9)
         RETURNING id,code,name,description,coin_amount AS "coinAmount",
           bonus_coin_amount AS "bonusCoinAmount",price,currency,qr_image_url AS "qrImageUrl",is_active AS "isActive"`,
        [
          input.code.trim(),
          input.name.trim(),
          input.description?.trim() ?? "",
          input.coinAmount,
          input.bonusCoinAmount ?? 0,
          input.price,
          input.currency ?? "BOB",
          input.qrImageUrl?.trim() ?? "",
          input.isActive ?? true,
        ],
      );
      await this.auditPackage(
        client,
        user,
        "coin_package_created",
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  updatePackage(
    user: RequestUser,
    id: string,
    input: CoinPackageInput,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const previous = await client.query(`SELECT * FROM coin_packages WHERE id=$1`,[id]);
      const result = await client.query(
        `UPDATE coin_packages SET code=UPPER($2),name=$3,description=NULLIF($4,''),
           coin_amount=$5,bonus_coin_amount=$6,price=$7,currency=UPPER($8),
           qr_image_url=NULLIF($9,''),is_active=$10,updated_at=now()
         WHERE id=$1
         RETURNING id,code,name,description,coin_amount AS "coinAmount",
           bonus_coin_amount AS "bonusCoinAmount",price,currency,qr_image_url AS "qrImageUrl",is_active AS "isActive"`,
        [
          id,
          input.code.trim(),
          input.name.trim(),
          input.description?.trim() ?? "",
          input.coinAmount,
          input.bonusCoinAmount ?? 0,
          input.price,
          input.currency ?? "BOB",
          input.qrImageUrl?.trim() ?? "",
          input.isActive ?? true,
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("Paquete de monedas no encontrado.");
      await this.auditPackage(
        client,
        user,
        "coin_package_updated",
        result.rows[0],
        previous.rows[0],
      );
      return result.rows[0];
    });
  }

  deletePackage(user: RequestUser, id: string): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const previous = await client.query(
        `SELECT * FROM coin_packages WHERE id=$1`,
        [id],
      );
      if (!previous.rows[0])
        throw new NotFoundException("Paquete de monedas no encontrado.");
      const result = await client.query(
        `UPDATE coin_packages
         SET is_active=false,valid_until=LEAST(COALESCE(valid_until,now()),now()),
             updated_at=now()
         WHERE id=$1
         RETURNING id,code,name,description,coin_amount AS "coinAmount",
           bonus_coin_amount AS "bonusCoinAmount",price,currency,qr_image_url AS "qrImageUrl",is_active AS "isActive"`,
        [id],
      );
      await this.auditPackage(
        client,
        user,
        "coin_package_deleted",
        result.rows[0],
        previous.rows[0],
      );
      return result.rows[0];
    });
  }

  private async expireLots(
    client: import("pg").PoolClient,
    actor: RequestUser,
    targetUserId: string,
  ): Promise<number> {
    await client.query(
      `SELECT pg_advisory_xact_lock(hashtext('coin-maintenance:'||$1))`,
      [targetUserId],
    );
    const wallet = await client.query<{
      id: string;
      available_balance: string;
    }>(
      `SELECT id,available_balance::text FROM coin_wallets
       WHERE user_id=$1 FOR UPDATE`,
      [targetUserId],
    );
    if (!wallet.rows[0]) return 0;
    const lots = await client.query<{
      id: string;
      remaining_amount: string;
    }>(
      `SELECT id,remaining_amount::text FROM coin_lots
       WHERE wallet_id=$1 AND remaining_amount>0 AND expired_at IS NULL
         AND expires_at<=now() ORDER BY expires_at FOR UPDATE`,
      [wallet.rows[0].id],
    );
    let balance = Number(wallet.rows[0].available_balance);
    for (const lot of lots.rows) {
      const amount = Number(lot.remaining_amount);
      balance -= amount;
      if (balance < 0)
        throw new ConflictException(
          "La billetera tiene un saldo inconsistente con sus lotes.",
        );
      await client.query(
        `UPDATE coin_lots SET remaining_amount=0,expired_at=now() WHERE id=$1`,
        [lot.id],
      );
      const transaction = await client.query<{ id: string }>(
        `INSERT INTO coin_transactions(
         wallet_id,transaction_type,coin_amount,balance_after,
           related_entity_type,related_entity_id,performed_by_user_id,reason
         )VALUES($1::uuid,'expiration',$2::bigint,$3::bigint,'coin_lot',$4::uuid,$5::uuid,'Vencimiento del lote de monedas')
         RETURNING id`,
        [wallet.rows[0].id, -amount, balance, lot.id, actor.id],
      );
      await client.query(
        `INSERT INTO coin_transaction_allocations(transaction_id,coin_lot_id,coin_amount)
         VALUES($1,$2,$3)`,
        [transaction.rows[0].id, lot.id, amount],
      );
      await client.query(
        `INSERT INTO audit_events(
         actor_user_id,actor_role,module,action,entity_type,entity_id,
           old_values,new_values,reason
         )VALUES($1::uuid,$2::text,'coins','coin_lot_expired','coin_lot',$3::uuid,
           jsonb_build_object('remainingAmount',$4::bigint),
           jsonb_build_object('remainingAmount',0,'balanceAfter',$5::bigint),
           'Vencimiento automático')`,
        [actor.id, actor.roleCode, lot.id, amount, balance],
      );
      await client.query(
        `INSERT INTO notifications(
           user_id,event_code,channel,title,body,related_entity_type,
           related_entity_id,status,sent_at
         )SELECT $1::uuid,'coins.expired','in_app','Monedas vencidas',
           $2::text,'coin_lot',$3::uuid,'sent',now()
         WHERE NOT EXISTS(
           SELECT 1 FROM notifications WHERE user_id=$1::uuid
             AND event_code='coins.expired' AND related_entity_id=$3::uuid
         )`,
        [targetUserId, `Venció un lote de ${amount} monedas Doc IA.`, lot.id],
      );
    }
    if (lots.rows.length)
      await client.query(
        `UPDATE coin_wallets SET available_balance=$2,updated_at=now() WHERE id=$1`,
        [wallet.rows[0].id, balance],
      );
    return lots.rows.length;
  }

  private async notifyExpiringLots(
    client: import("pg").PoolClient,
    targetUserId: string,
  ): Promise<number> {
    const setting = await client.query<{ days: string }>(
      `SELECT COALESCE((value #>> '{}')::int,30)::text AS days
       FROM system_settings WHERE setting_key='coins.expiration_notice_days'`,
    );
    const days = Number(setting.rows[0]?.days ?? 30);
    const result = await client.query(
      `INSERT INTO notifications(
         user_id,event_code,channel,title,body,related_entity_type,
         related_entity_id,status,sent_at
       )SELECT wallet.user_id,'coins.expiring','in_app',
         'Tus monedas están por vencer',
         concat('Tienes ',lot.remaining_amount,' monedas que vencen el ',
           to_char(lot.expires_at AT TIME ZONE 'America/La_Paz','DD/MM/YYYY'),'.'),
         'coin_lot',lot.id,'sent',now()
       FROM coin_lots lot JOIN coin_wallets wallet ON wallet.id=lot.wallet_id
       WHERE wallet.user_id=$1 AND lot.remaining_amount>0
         AND lot.expired_at IS NULL AND lot.expires_at>now()
         AND lot.expires_at<=now()+($2::text||' days')::interval
         AND NOT EXISTS(
           SELECT 1 FROM notifications notification
           WHERE notification.user_id=wallet.user_id
             AND notification.event_code='coins.expiring'
             AND notification.related_entity_id=lot.id
         )`,
      [targetUserId, days],
    );
    return result.rowCount ?? 0;
  }

  private async auditPackage(
    client: import("pg").PoolClient,
    user: RequestUser,
    action: string,
    values: Record<string, unknown>,
    oldValues?: Record<string, unknown>,
  ) {
    await client.query(
      `INSERT INTO audit_events(
         actor_user_id,actor_role,module,action,entity_type,entity_id,old_values,new_values
       )VALUES($1,$2,'coins',$3,'coin_package',$4,$5::jsonb,$6::jsonb)`,
      [user.id,user.roleCode,action,values.id,oldValues?JSON.stringify(oldValues):null,JSON.stringify(values)],
    );
  }
}
