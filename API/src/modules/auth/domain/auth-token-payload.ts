export type AuthTokenPayload = {
  sub: string;
  sid: string;
  email: string;
  phone?: string | null;
  roleCode: string;
  roles: string[];
  permissions: string[];
  tokenUse: "access" | "refresh";
};
