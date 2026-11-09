// Normalize only public URLs; verify every other parsed value before writing the NEW copy.
const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");
const { parseEnv } = require("./public-config.cjs");
const { validateOverrides } = require("./check-legacy-urls.cjs");
const managedKeys = new Set([
  "PUBLIC_API_URL",
  "PUBLIC_WEB_URL",
  "PUBLIC_LANDING_URL",
  "API_PREFIX",
  "PASSWORD_RESET_URL",
  "REGISTRATION_URL",
  "STRIPE_PAYMENT_RETURN_URL",
  "GOOGLE_OAUTH_REDIRECT_URI",
]);
function normalizePrivateEnvironment(source, sites, parse) {
  const before = parse(source);
  const routing = validateOverrides(before, sites);
  // Centralized PUBLIC_WEB_URL otherwise defaults to hash routing at runtime.
  // Pin an inferred path mode in the NEW copy before removing legacy URLs.
  const pinPathRouting = !before.WEB_ROUTING_MODE && routing === "path";
  let normalized = source
    .split(/(?<=\n)/)
    .filter((line) => {
      const match = line.match(
        /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/,
      );
      return (
        !match ||
        (!managedKeys.has(match[1]) &&
          !(pinPathRouting && match[1] === "WEB_ROUTING_MODE"))
      );
    })
    .join("");
  if (pinPathRouting) {
    const newline = source.includes("\r\n") ? "\r\n" : "\n";
    normalized += `${normalized && !normalized.endsWith("\n") ? newline : ""}WEB_ROUTING_MODE=path${newline}`;
  }
  const after = parse(normalized);
  for (const key of Object.keys(before)) {
    if (
      !managedKeys.has(key) &&
      !(pinPathRouting && key === "WEB_ROUTING_MODE") &&
      before[key] !== after[key]
    )
      throw Error(
        `No se pudo conservar ${key}; se detuvo la preparación sin mostrar valores privados.`,
      );
  }
  if (pinPathRouting && after.WEB_ROUTING_MODE !== "path")
    throw Error(
      "No se pudo conservar el modo de navegación de los enlaces públicos.",
    );
  for (const key of managedKeys)
    if (key in after)
      throw Error(`La variable pública ${key} no se normalizó correctamente.`);
  return normalized;
}
module.exports = { normalizePrivateEnvironment, managedKeys };
if (require.main === module) {
  try {
    const checkOnly = process.argv[2] === "--check-only";
    const file = process.argv[checkOnly ? 3 : 2];
    const allowed = checkOnly
      ? "/var/www/docia/deploy/shared/api.env"
      : "/var/www/docia/monorepo/deploy/shared/api.env";
    if (file !== allowed || fs.lstatSync(file).isSymbolicLink())
      throw Error("Ruta de entorno privado inesperada.");
    const dotenv = createRequire(
      "/var/www/docia/deploy/current-api/api/package.json",
    )("dotenv");
    const sites = parseEnv(
      fs.readFileSync(
        path.resolve(
          __dirname,
          process.env.DOCIA_MIGRATION_SOURCE === "legacy-cloud"
            ? "../config/environments/legacy-cloud.env"
            : "../config/environments/production.env",
        ),
        "utf8",
      ),
    );
    const normalized = normalizePrivateEnvironment(
      fs.readFileSync(file, "utf8"),
      sites,
      dotenv.parse,
    );
    if (!checkOnly) fs.writeFileSync(file, normalized);
    console.log(
      checkOnly
        ? "Entorno anterior compatible; se conservarán todos los valores privados."
        : "Copia privada preparada; valores de API conservados y URL públicas centralizadas.",
    );
  } catch (error) {
    console.error(
      error.code
        ? "No se pudo comprobar o preparar el entorno privado; no continuar con la instalación."
        : error.message,
    );
    process.exitCode = 1;
  }
}
