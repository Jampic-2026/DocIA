// Only public compile-time values may enter the web artifact.
const fs = require("node:fs");
const { fromEnvironment } = require("./public-config.cjs");
const allowed = ["APP_ENV", "API_BASE_URL", "STRIPE_PUBLISHABLE_KEY"];
let config;
try {
  config = JSON.parse(process.env.DOCIA_WEB_CONFIG_JSON || "{}");
  if (!config || Array.isArray(config) || typeof config !== "object")
    throw Error();
  if (Object.keys(config).some((key) => !allowed.includes(key))) throw Error();
  const sites = fromEnvironment();
  if (sites) {
    config.APP_ENV = "production";
    config.API_BASE_URL = `${sites.PUBLIC_API_URL}/${sites.API_PREFIX}/`;
  }
  if (config.APP_ENV !== "production") throw Error();
  const url = new URL(config.API_BASE_URL);
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    !url.pathname.endsWith("/")
  )
    throw Error();
  if (
    config.STRIPE_PUBLISHABLE_KEY !== undefined &&
    typeof config.STRIPE_PUBLISHABLE_KEY !== "string"
  )
    throw Error();
  if (
    config.STRIPE_PUBLISHABLE_KEY &&
    !/^pk_live_[A-Za-z0-9]+$/.test(config.STRIPE_PUBLISHABLE_KEY)
  )
    throw Error();
  fs.writeFileSync("config/ci-production.json", JSON.stringify(config));
} catch {
  console.error(
    "Configuración pública inválida: revisar DOCIA_PUBLIC_CONFIG_JSON (o DOCIA_PUBLIC_CONFIG_FILE) y DOCIA_WEB_CONFIG_JSON. Requiere producción, API_BASE_URL HTTPS terminada en / y opcional STRIPE_PUBLISHABLE_KEY pk_live_. Solo se permiten claves públicas.",
  );
  process.exit(1);
}
