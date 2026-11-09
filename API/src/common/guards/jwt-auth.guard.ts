import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Reflector } from "@nestjs/core";
import { JwtService } from "@nestjs/jwt";
import { DatabaseService } from "../../database/database.service";
import { AuthTokenPayload } from "../../modules/auth/domain/auth-token-payload";
import { IS_PUBLIC_KEY } from "../decorators/public.decorator";
import { RequestUser } from "../types/request-user";

type HttpRequestWithUser = {
  headers: Record<string, string | string[] | undefined>;
  user?: RequestUser;
};

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly database: DatabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest<HttpRequestWithUser>();
    const token = this.extractBearerToken(request.headers.authorization);

    if (!token) {
      throw new UnauthorizedException("Token de acceso requerido");
    }

    const payload = await this.verifyAccessToken(token);
    const access = await this.activeAccess(payload.sid, payload.sub);

    request.user = {
      id: payload.sub,
      sessionId: payload.sid,
      email: payload.email,
      phone: payload.phone,
      roleCode: access.roles.includes(payload.roleCode)
        ? payload.roleCode
        : (access.roles[0] ?? "patient"),
      roles: access.roles,
      permissions: access.permissions,
    };

    return true;
  }

  private extractBearerToken(header: string | string[] | undefined) {
    const value = Array.isArray(header) ? header[0] : header;
    const [type, token] = value?.split(" ") ?? [];
    return type === "Bearer" ? token : undefined;
  }

  private async verifyAccessToken(token: string) {
    try {
      const payload = await this.jwtService.verifyAsync<AuthTokenPayload>(
        token,
        {
          secret: this.config.getOrThrow<string>("JWT_ACCESS_SECRET"),
        },
      );

      if (payload.tokenUse !== "access") {
        throw new UnauthorizedException("Token inválido");
      }

      return payload;
    } catch {
      throw new UnauthorizedException("Token inválido o expirado");
    }
  }

  private async activeAccess(sessionId: string, userId: string) {
    const access = await this.database.transactionWithSettings(
      {
        "app.user_id": userId,
        "app.session_id": sessionId,
      },
      async (client) => {
        const result = await client.query<{
          roles: string[];
          permissions: string[];
        }>(
          `
          WITH active_account AS (
            SELECT u.id,u.role_id FROM users u JOIN user_sessions s ON s.user_id=u.id
            WHERE s.id=$1 AND u.id=$2 AND u.status='active'
              AND s.revoked_at IS NULL AND s.expires_at>now()
          ), candidate_roles AS (
            SELECT r.id,r.code FROM roles r JOIN active_account u ON u.role_id=r.id WHERE r.is_active
            UNION
            SELECT r.id,r.code FROM roles r JOIN user_roles ur ON ur.role_id=r.id
              JOIN active_account u ON u.id=ur.user_id
            WHERE r.is_active AND ur.revoked_at IS NULL AND ur.valid_from<=now()
              AND (ur.valid_until IS NULL OR ur.valid_until>now())
          ), effective_roles AS (
            SELECT * FROM candidate_roles r
            WHERE r.code NOT IN ('doctor_general','doctor_specialist','nurse') OR EXISTS (
              SELECT 1 FROM professionals p WHERE p.user_id=$2 AND p.verification_status='approved'
            )
          )
          SELECT COALESCE(array_agg(DISTINCT r.code) FILTER(WHERE r.code IS NOT NULL),ARRAY[]::text[]) AS roles,
            COALESCE(array_agg(DISTINCT p.code) FILTER(WHERE p.code IS NOT NULL),ARRAY[]::text[]) AS permissions
          FROM active_account u LEFT JOIN effective_roles r ON TRUE
          LEFT JOIN role_permissions rp ON rp.role_id=r.id LEFT JOIN permissions p ON p.id=rp.permission_id
          GROUP BY u.id
          `,
          [sessionId, userId],
        );

        return result.rows[0];
      },
    );

    if (!access) {
      throw new UnauthorizedException("Sesión inválida o expirada");
    }
    return access;
  }
}
