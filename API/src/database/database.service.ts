import { Injectable, OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { OnModuleInit } from "@nestjs/common";
import { Pool, PoolClient, QueryResult, QueryResultRow } from "pg";
import { RequestUser } from "../common/types/request-user";

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly pool: Pool;
  private readonly mustEnforceRlsRole: boolean;

  constructor(config: ConfigService) {
    this.mustEnforceRlsRole =
      config.get<string>("nodeEnv") === "production" &&
      config.get<boolean>("database.enforceRlsRole") !== false;
    this.pool = new Pool({
      connectionTimeoutMillis: 5000,
      connectionString:
        config.get<string>("DATABASE_URL") ??
        config.getOrThrow<string>("database.url"),
    });
  }

  async onModuleInit() {
    if (!this.mustEnforceRlsRole) return;

    const result = await this.pool.query<{
      role_name: string;
      is_superuser: boolean;
      bypasses_rls: boolean;
      owns_rls_tables: boolean;
    }>(
      `SELECT current_user AS role_name,
         role.rolsuper AS is_superuser,
         role.rolbypassrls AS bypasses_rls,
         EXISTS (
           SELECT 1
           FROM pg_class relation
           JOIN pg_namespace namespace ON namespace.oid=relation.relnamespace
           WHERE namespace.nspname=current_schema()
             AND relation.relkind IN ('r','p')
             AND relation.relrowsecurity
             AND relation.relowner=(SELECT oid FROM pg_roles WHERE rolname=current_user)
         ) AS owns_rls_tables
       FROM pg_roles role
       WHERE role.rolname=current_user`,
    );
    const role = result.rows[0];
    if (
      !role ||
      role.is_superuser ||
      role.bypasses_rls ||
      role.owns_rls_tables
    ) {
      throw new Error(
        `La API no puede iniciar con el rol PostgreSQL '${role?.role_name ?? "desconocido"}': en producción debe usarse un rol runtime sin SUPERUSER, BYPASSRLS ni propiedad sobre tablas con RLS.`,
      );
    }
  }

  query<T extends QueryResultRow = QueryResultRow>(
    text: string,
    params?: unknown[],
  ): Promise<QueryResult<T>> {
    return this.pool.query<T>(text, params);
  }

  async checkHealth(): Promise<void> {
    // pg supports per-query timeouts; @types/pg omits it from QueryConfig.
    const healthQuery = { text: "SELECT 1", query_timeout: 3000 };
    await this.pool.query(healthQuery);
  }

  async transaction<T>(work: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
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

  async transactionWithSettings<T>(
    settings: Record<string, string | string[]>,
    work: (client: PoolClient) => Promise<T>,
  ): Promise<T> {
    return this.transaction(async (client) => {
      for (const [key, value] of Object.entries(settings)) {
        await client.query("SELECT set_config($1, $2, true)", [
          key,
          Array.isArray(value) ? JSON.stringify(value) : value,
        ]);
      }

      return work(client);
    });
  }

  async transactionAsUser<T>(
    user: RequestUser,
    work: (client: PoolClient) => Promise<T>,
  ): Promise<T> {
    return this.transaction(async (client) => {
      await this.setAuthContext(client, user);
      return work(client);
    });
  }

  async setAuthContext(client: PoolClient, user: RequestUser) {
    await client.query("SELECT set_config('app.user_id', $1, true)", [user.id]);
    await client.query("SELECT set_config('app.session_id', $1, true)", [
      user.sessionId,
    ]);
    await client.query("SELECT set_config('app.role_code', $1, true)", [
      user.roleCode,
    ]);
    await client.query("SELECT set_config('app.roles', $1, true)", [
      JSON.stringify(user.roles),
    ]);
    await client.query("SELECT set_config('app.permissions', $1, true)", [
      JSON.stringify(user.permissions),
    ]);
  }

  async onModuleDestroy() {
    await this.pool.end();
  }
}
