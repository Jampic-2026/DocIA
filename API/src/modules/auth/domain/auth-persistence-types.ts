export type RequestContext = {
  userAgent?: string;
  ipAddress?: string;
};
export type UserAuthRecord = {
  id: string;
  email: string;
  phone: string | null;
  password_hash: string;
  status: string;
  role_code: string;
  roles: string[];
  permissions: string[];
  mfa_enabled: boolean;
  mfa_secret_encrypted: string | null;
};
export type SessionRecord = {
  id: string;
  user_id: string;
  refresh_token_hash: string;
};
