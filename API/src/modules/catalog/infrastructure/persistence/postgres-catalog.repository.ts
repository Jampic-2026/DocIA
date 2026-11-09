import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { CatalogItem } from "../../domain/catalog-item";
import {
  CatalogRepository,
  PriceInput,
  ServiceInput,
} from "../../domain/ports/catalog.repository";
type Row = QueryResultRow & {
  id: string;
  code: string;
  name: string;
  category: string;
  description: string | null;
  charge_mode: string | null;
  coin_price: string | null;
  price: string | null;
  currency: string | null;
};
@Injectable()
export class PostgresCatalogRepository implements CatalogRepository {
  constructor(private readonly database: DatabaseService) {}
  list(user: RequestUser): Promise<CatalogItem[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result =
        await client.query<Row>(`SELECT service.id,service.code,service.name,service.category,
    service.description,price.charge_mode,price.coin_price,price.price,price.currency
    FROM service_catalog service LEFT JOIN LATERAL(SELECT current_price.* FROM price_list current_price
      WHERE current_price.service_id=service.id AND current_price.valid_from<=CURRENT_DATE
      AND(current_price.valid_until IS NULL OR current_price.valid_until>=CURRENT_DATE)
      ORDER BY current_price.valid_from DESC,current_price.created_at DESC LIMIT 1) price ON true
    WHERE service.is_active ORDER BY service.category,service.name`);
      return result.rows.map((r) => ({
        id: r.id,
        code: r.code,
        name: r.name,
        category: r.category,
        description: r.description,
        chargeMode: r.charge_mode,
        coinPrice: r.coin_price == null ? null : Number(r.coin_price),
        price: r.price == null ? null : Number(r.price),
        currency: r.currency,
      }));
    });
  }

  createPrice(user: RequestUser, input: PriceInput): Promise<unknown> {
    if (input.chargeMode === "coins" && input.coinPrice == null)
      throw new BadRequestException("Debes indicar el precio en monedas.");
    if (input.chargeMode === "fiat" && input.price == null)
      throw new BadRequestException("Debes indicar el precio en bolivianos.");
    return this.database.transactionAsUser(user, async (client) => {
      const effectiveFrom = input.validFrom ?? new Date().toISOString().slice(0, 10);
      if (input.validUntil && input.validUntil < effectiveFrom)
        throw new BadRequestException("La fecha final no puede ser anterior al inicio de vigencia.");
      const conflict = await client.query(
        `SELECT id FROM price_list WHERE service_id=$1 AND valid_from>=$2::date
           AND(valid_until IS NULL OR valid_until>=$2::date) LIMIT 1`,
        [input.serviceId,effectiveFrom],
      );
      if(conflict.rows[0])throw new BadRequestException("Ya existe una tarifa que inicia en esa fecha o posteriormente.");
      const closed=await client.query(`UPDATE price_list SET valid_until=$2::date-1 WHERE service_id=$1 AND valid_from<$2::date AND(valid_until IS NULL OR valid_until>=$2::date) RETURNING id,valid_until AS "validUntil"`,[input.serviceId,effectiveFrom]);
      const result = await client.query(
        `INSERT INTO price_list(service_id,charge_mode,coin_price,price,currency,valid_from,valid_until,created_by_user_id)
         VALUES($1,$2,$3,$4,UPPER($5),COALESCE($6::date,CURRENT_DATE),$7::date,$8)
         RETURNING id,service_id AS "serviceId",charge_mode AS "chargeMode",coin_price AS "coinPrice",price,currency,valid_from AS "validFrom",valid_until AS "validUntil",created_at AS "createdAt"`,
        [
          input.serviceId,
          input.chargeMode,
          input.chargeMode === "coins" ? input.coinPrice : null,
          input.chargeMode === "fiat" ? input.price : null,
          input.currency ?? "BOB",
          effectiveFrom,
          input.validUntil ?? null,
          user.id,
        ],
      );
      for(const previous of closed.rows)await this.audit(client,user,"price_validity_closed","price_list",previous);
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values)
         VALUES($1,$2,'catalog','price_created','price_list',$3,$4::jsonb)`,
        [
          user.id,
          user.roleCode,
          result.rows[0].id,
          JSON.stringify(result.rows[0]),
        ],
      );
      return result.rows[0];
    });
  }
  createService(user: RequestUser, input: ServiceInput): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO service_catalog(code,name,category,description,is_active) VALUES(UPPER($1),$2,$3,NULLIF($4,''),$5) RETURNING id,code,name,category,description,is_active AS "isActive",created_at AS "createdAt"`,
        [
          input.code.trim(),
          input.name.trim(),
          input.category.trim(),
          input.description?.trim() ?? "",
          input.isActive ?? true,
        ],
      );
      await this.audit(
        client,
        user,
        "service_created",
        "service_catalog",
        result.rows[0],
      );
      return result.rows[0];
    });
  }
  updateService(
    user: RequestUser,
    id: string,
    input: ServiceInput,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const previous = await client.query(
        `SELECT * FROM service_catalog WHERE id=$1`,
        [id],
      );
      if (!previous.rows[0])
        throw new NotFoundException("Servicio no encontrado.");
      const result = await client.query(
        `UPDATE service_catalog SET code=UPPER($2),name=$3,category=$4,description=NULLIF($5,''),is_active=$6 WHERE id=$1 RETURNING id,code,name,category,description,is_active AS "isActive",created_at AS "createdAt"`,
        [
          id,
          input.code.trim(),
          input.name.trim(),
          input.category.trim(),
          input.description?.trim() ?? "",
          input.isActive ?? true,
        ],
      );
      await this.audit(
        client,
        user,
        "service_updated",
        "service_catalog",
        result.rows[0],
        previous.rows[0],
      );
      return result.rows[0];
    });
  }
  closePrice(
    user: RequestUser,
    id: string,
    validUntil: string,
  ): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => {
      const previous = await client.query(
        `SELECT * FROM price_list WHERE id=$1`,
        [id],
      );
      if (!previous.rows[0])
        throw new NotFoundException("Tarifa no encontrada.");
      const result = await client.query(
        `UPDATE price_list SET valid_until=$2::date WHERE id=$1 AND $2::date>=valid_from RETURNING id,service_id AS "serviceId",valid_until AS "validUntil"`,
        [id, validUntil],
      );
      if (!result.rows[0])
        throw new BadRequestException(
          "La fecha final no puede ser anterior al inicio de vigencia.",
        );
      await this.audit(
        client,
        user,
        "price_validity_closed",
        "price_list",
        result.rows[0],
        previous.rows[0],
      );
      return result.rows[0];
    });
  }
  management(user: RequestUser): Promise<unknown> {
    return this.database.transactionAsUser(user, async (client) => ({
      services: (
        await client.query(
          `SELECT id,code,name,category,description,is_active AS "isActive",created_at AS "createdAt" FROM service_catalog ORDER BY category,name`,
        )
      ).rows,
      prices: (
        await client.query(
          `SELECT price.id,price.service_id AS "serviceId",service.name AS "serviceName",price.charge_mode AS "chargeMode",price.coin_price AS "coinPrice",price.price,price.currency,price.valid_from AS "validFrom",price.valid_until AS "validUntil",price.created_at AS "createdAt" FROM price_list price JOIN service_catalog service ON service.id=price.service_id ORDER BY price.valid_from DESC,price.created_at DESC`,
        )
      ).rows,
    }));
  }
  private async audit(
    client: import("pg").PoolClient,
    user: RequestUser,
    action: string,
    entityType: string,
    newValues: Record<string, unknown>,
    oldValues?: Record<string, unknown>,
  ) {
    await client.query(
      `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,old_values,new_values) VALUES($1,$2,'catalog',$3,$4,$5,$6::jsonb,$7::jsonb)`,
      [
        user.id,
        user.roleCode,
        action,
        entityType,
        newValues.id,
        oldValues ? JSON.stringify(oldValues) : null,
        JSON.stringify(newValues),
      ],
    );
  }
}
