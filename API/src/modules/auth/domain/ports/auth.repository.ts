import {
  ChangePasswordDto,
  RefreshTokenDto,
  CompleteRegistrationDto,
  DisableMfaDto,
} from "../auth-inputs";
import { RequestUser } from "../../../../common/types/request-user";

import { RequestContext, UserAuthRecord } from "../auth-persistence-types";
import { AuthTokenPayload } from "../auth-token-payload";
export const AUTH_REPOSITORY = Symbol("AUTH_REPOSITORY");
export interface AuthRepository {
  createLoginSession(
    sessionId: `${string}-${string}-${string}-${string}-${string}`,
    user: UserAuthRecord,
    refreshTokenHash: string,
    context: RequestContext,
    refreshExpiresAt: Date,
  ): Promise<void>;
  rotateRefreshSession(
    payload: AuthTokenPayload,
    dto: RefreshTokenDto,
    issueTokensCallback: (
      user: UserAuthRecord,
      sessionId: string,
    ) => Promise<{ accessToken: string; refreshToken: string }>,
    expirationToDateCallback: (value: string) => Date,
    authResponseCallback: (
      user: UserAuthRecord,
      sessionId: string,
      tokens: { accessToken: string; refreshToken: string },
    ) => {
      accessToken: string;
      refreshToken: string;
      tokenType: string;
      user: {
        id: string;
        sessionId: string;
        email: string;
        phone: string | null;
        roleCode: string;
        roles: string[];
        permissions: string[];
      };
    },
    configurationValue1: string,
  ): Promise<{
    accessToken: string;
    refreshToken: string;
    tokenType: string;
    user: {
      id: string;
      sessionId: string;
      email: string;
      phone: string | null;
      roleCode: string;
      roles: string[];
      permissions: string[];
    };
  }>;
  revokeLogoutSession(payload: AuthTokenPayload): Promise<void>;
  listSessions(user: RequestUser): Promise<{ items: any[] }>;
  createRegistrationRequest(
    email: string,
    hash: string,
    context: RequestContext,
  ): Promise<string>;
  completeRegistration(
    tokenHash: string,
    isMinor: boolean,
    input: CompleteRegistrationDto,
    passwordHash: string,
  ): Promise<{
    userId: string;
    patientId: string;
    email: string;
    status: string;
  }>;
  changePassword(
    user: RequestUser,
    input: ChangePasswordDto,
  ): Promise<{ updated: boolean }>;
  revokeSession(sessionId: string, user: RequestUser): Promise<any>;
  storeMfaSecret(
    user: RequestUser,
    password: string,
    encrypted: string,
    secret: string,
  ): Promise<{ secret: string; otpauthUrl: string }>;
  confirmMfa(
    user: RequestUser,
    code: string,
    verifyTotpCallback: (secret: string, code: string) => boolean,
    decryptMfaSecretCallback: (value: string) => string,
  ): Promise<{ mfaEnabled: boolean }>;
  disableMfa(
    user: RequestUser,
    input: DisableMfaDto,
    verifyTotpCallback: (secret: string, code: string) => boolean,
    decryptMfaSecretCallback: (value: string) => string,
  ): Promise<{ mfaEnabled: boolean }>;
  storePhoneVerification(
    normalized: string,
    user: RequestUser,
    hash: string,
  ): Promise<string>;
  confirmPhoneVerification(
    user: RequestUser,
    code: string,
  ): Promise<
    | { invalid: true; phone?: undefined; phoneVerified?: undefined }
    | { invalid: false; phone: string; phoneVerified: boolean }
  >;
  administrativeResource(
    user: RequestUser,
    resource: "registration-email-tokens" | "user-sessions",
  ): Promise<{ items: any[] }>;
  createPasswordReset(email: string, tokenHash: string): Promise<string | null>;
  resetPassword(tokenHash: string, passwordHash: string): Promise<void>;
  findLoginUser(identifier: string): Promise<UserAuthRecord>;
}
