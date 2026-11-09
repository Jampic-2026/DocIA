export type RequestUser = {
  id: string;
  sessionId: string;
  email: string;
  phone?: string | null;
  roleCode: string;
  roles: string[];
  permissions: string[];
};
