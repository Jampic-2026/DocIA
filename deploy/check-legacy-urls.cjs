// Detect custom production URLs before normalizing the NEW private env copy.
// Never log values from the private configuration.
const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");
const { parseEnv } = require("./public-config.cjs");

function validateOverrides(env, sites) {
  const invalid = [];
  const compare = (key, expected, origin = false) => {
    if (!env[key]?.trim()) return;
    try {
      const actual = origin
        ? env[key].trim().replace(/\/+$/, "")
        : new URL(env[key].trim()).toString();
      const normalized = origin ? expected : new URL(expected).toString();
      if (actual !== normalized) invalid.push(key);
    } catch {
      invalid.push(key);
    }
  };
  for (const key of ["PUBLIC_API_URL", "PUBLIC_WEB_URL", "PUBLIC_LANDING_URL"])
    compare(key, sites[key], true);
  if (
    env.API_PREFIX &&
    env.API_PREFIX.replace(/^\/+|\/+$/g, "") !== sites.API_PREFIX
  )
    invalid.push("API_PREFIX");
  const routing = env.WEB_ROUTING_MODE || "hash";
  if (!["hash", "path"].includes(routing)) invalid.push("WEB_ROUTING_MODE");
  const route = (suffix) =>
    `${sites.PUBLIC_WEB_URL}/${routing === "hash" ? "#/" : ""}${suffix}`;
  compare("PASSWORD_RESET_URL", route("password-reset"));
  compare("REGISTRATION_URL", route("register/complete"));
  compare("STRIPE_PAYMENT_RETURN_URL", route("payments/return"));
  compare(
    "GOOGLE_OAUTH_REDIRECT_URI",
    `${sites.PUBLIC_API_URL}/${sites.API_PREFIX}/integrations/google/callback`,
  );
  if (invalid.length)
    throw Error(
      `Se conservaron los archivos anteriores. Hay rutas personalizadas o dominios distintos en: ${invalid.join(", ")}. Revisar su equivalencia antes de normalizar la copia nueva; no se muestran sus valores.`,
    );
}
module.exports = { validateOverrides };
if (require.main === module) {
  try {
    const legacy = "/var/www/docia/deploy";
    const dotenv = createRequire(`${legacy}/current-api/api/package.json`)(
      "dotenv",
    );
    const env = dotenv.parse(fs.readFileSync(`${legacy}/shared/api.env`));
    const sites = parseEnv(
      fs.readFileSync(
        path.resolve(__dirname, "../config/environments/production.env"),
        "utf8",
      ),
    );
    validateOverrides(env, sites);
    console.log(
      "Rutas públicas anteriores compatibles con la configuración central.",
    );
  } catch (error) {
    console.error(
      error.code
        ? "No se pudo comprobar la configuración privada anterior; no continuar con la instalación."
        : error.message,
    );
    process.exitCode = 1;
  }
}
