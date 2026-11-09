/** Domain-dependent URLs are derived here; explicit legacy overrides remain supported. */
export function resolvePublicUrls(env: Record<string, unknown>) {
  const value = (key: string) =>
    typeof env[key] === "string" && env[key].trim()
      ? env[key].trim()
      : undefined;
  const api = (value("PUBLIC_API_URL") ?? "http://localhost:3000").replace(
    /\/+$/,
    "",
  );
  const configuredWeb = value("PUBLIC_WEB_URL");
  const web = (configuredWeb ?? "http://localhost:5173").replace(/\/+$/, "");
  const prefix = (value("API_PREFIX") ?? "api/v1").replace(/^\/+|\/+$/g, "");
  const routing =
    value("WEB_ROUTING_MODE") ?? (configuredWeb ? "hash" : "path");
  const route = (pathname: string) =>
    `${web}/${routing === "hash" ? "#/" : ""}${pathname}`;
  const origins = [
    configuredWeb ? web : undefined,
    ...(value("CORS_ORIGINS") ?? "").split(","),
  ]
    .map((origin) => origin?.trim())
    .filter((origin): origin is string => Boolean(origin));
  return {
    PUBLIC_API_URL: api,
    PUBLIC_WEB_URL: configuredWeb ? web : undefined,
    API_PREFIX: prefix,
    WEB_ROUTING_MODE: routing,
    CORS_ORIGINS: [...new Set(origins)].join(","),
    PASSWORD_RESET_URL: value("PASSWORD_RESET_URL") ?? route("password-reset"),
    REGISTRATION_URL: value("REGISTRATION_URL") ?? route("register/complete"),
    STRIPE_PAYMENT_RETURN_URL:
      value("STRIPE_PAYMENT_RETURN_URL") ?? route("payments/return"),
    GOOGLE_OAUTH_REDIRECT_URI:
      value("GOOGLE_OAUTH_REDIRECT_URI") ??
      `${api}/${prefix}/integrations/google/callback`,
  };
}

/** Flutter's hash router reads query parameters inside the route fragment. */
export function appendWebQuery(
  base: string,
  parameters: Record<string, string>,
) {
  const url = new URL(base);
  const hashRoute = url.hash.startsWith("#/")
    ? new URL(url.hash.slice(1), url.origin)
    : undefined;
  const query = hashRoute?.searchParams ?? url.searchParams;
  for (const [key, value] of Object.entries(parameters)) query.set(key, value);
  if (hashRoute) url.hash = `${hashRoute.pathname}${hashRoute.search}`;
  return url.toString();
}
