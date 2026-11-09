export type DatabaseUrlInput = {
  DATABASE_URL?: string;
  DB_HOST?: string;
  DB_PORT?: string | number;
  DB_NAME?: string;
  DB_USER?: string;
  DB_PASSWORD?: string;
  DB_SSL?: string;
};

export function buildDatabaseUrl(input: DatabaseUrlInput) {
  if (input.DATABASE_URL) {
    return input.DATABASE_URL;
  }

  return buildDatabaseUrlFromParts(input, input.DB_NAME ?? "jampic_local");
}

export function buildDatabaseUrlFromParts(
  input: DatabaseUrlInput,
  databaseName: string,
) {
  const host = input.DB_HOST ?? "localhost";
  const port = String(input.DB_PORT ?? 5432);
  const user = input.DB_USER ?? "postgres";
  const password = input.DB_PASSWORD ?? "postgres";
  const sslMode =
    input.DB_SSL && input.DB_SSL !== "disable"
      ? `?sslmode=${input.DB_SSL}`
      : "";

  return `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${databaseName}${sslMode}`;
}
