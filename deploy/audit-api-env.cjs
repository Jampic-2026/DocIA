// Inventory names and destinations only; never read a real .env or write credentials.
const fs = require("node:fs");
const path = require("node:path");
const { createHash } = require("node:crypto");
const publicKeys = new Set(["PUBLIC_API_URL", "PUBLIC_WEB_URL", "API_PREFIX"]);
const derivedKeys = new Set([
  "PASSWORD_RESET_URL",
  "REGISTRATION_URL",
  "STRIPE_PAYMENT_RETURN_URL",
  "GOOGLE_OAUTH_REDIRECT_URI",
]);
const pm2Keys = {
  NODE_ENV: "production",
  HOST: "127.0.0.1",
  PORT: "3100",
  STORAGE_ROOT: "/var/www/docia-monorepo/deploy/shared/storage",
};
const databaseKeys = new Set([
  "DATABASE_URL",
  "DB_HOST",
  "DB_PORT",
  "DB_NAME",
  "DB_USER",
  "DB_PASSWORD",
  "DB_SSL",
]);
function entries(source) {
  const found = [
    ...source.matchAll(
      /^\s*(#\s*)?(?:export\s+)?([A-Z][A-Z0-9_]*)\s*=([^\r\n]*)/gm,
    ),
  ].map((match) => ({
    key: match[2],
    optional: !!match[1],
    example: match[3],
  }));
  const unique = new Map();
  for (const item of found) {
    const previous = unique.get(item.key);
    if (previous && !previous.optional && !item.optional)
      throw Error(`Variable activa duplicada: ${item.key}.`);
    if (!previous || !item.optional) unique.set(item.key, item);
  }
  return [...unique.values()];
}
function destination(key) {
  if (publicKeys.has(key))
    return {
      destination:
        "config/environments/production.env → release/PUBLIC_CONFIG.env",
      classification: "public",
      note: "Se retira de la copia privada; Nest carga la configuración pública de la release.",
    };
  if (derivedKeys.has(key))
    return {
      destination: "API/src/config/public-urls.ts",
      classification: "derived-public",
      note: "Se deriva de las URL centrales y WEB_ROUTING_MODE. El instalador detiene rutas personalizadas que no coincidan.",
    };
  if (key in pm2Keys)
    return {
      destination: "deploy/ecosystem.config.cjs → process environment",
      classification: "deployment",
      effectiveValue: pm2Keys[key],
      note: "La copia privada conserva el valor anterior, pero este ajuste de la instalación nueva tiene prioridad.",
    };
  if (key.startsWith("DB_ADMIN_"))
    return {
      destination: "Entorno administrativo para scripts/create-database.ts",
      classification: "administrative",
      note: "Se conserva si existía. No lo usa el servidor HTTP ni db:migrate; el despliegue no crea bases.",
    };
  if (databaseKeys.has(key))
    return {
      destination:
        "deploy/shared/api.env y, con credenciales separadas, deploy/shared/migrations.env",
      classification: "private-database",
      note: "Cada archivo se copia de su propio equivalente anterior: no se copian credenciales runtime sobre las de migraciones.",
    };
  return {
    destination: "deploy/shared/api.env → release/api/.env",
    classification: "private-runtime",
    note: "Se conserva exactamente el valor del entorno anterior; no se toma del ejemplo ni se exporta a Flutter o landing.",
  };
}
function inventory(root) {
  const source = fs.readFileSync(path.join(root, "API/.env.example"), "utf8");
  const variables = entries(source),
    names = new Set(variables.map((item) => item.key));
  if (names.size !== variables.length)
    throw Error("Hay variables duplicadas en API/.env.example.");
  const contract = JSON.parse(
    fs.readFileSync(path.join(root, "config/api-env-contract.json"), "utf8"),
  );
  const currentByName = new Map(variables.map((item) => [item.key, item]));
  const contractFailures = contract.variables
    .filter(
      (item) =>
        !currentByName.has(item.key) ||
        createHash("sha256")
          .update(currentByName.get(item.key).example)
          .digest("hex") !== item.exampleSha256,
    )
    .map((item) => item.key);
  if (contractFailures.length)
    throw Error(
      `Se alteró el contrato del ejemplo original: ${contractFailures.join(", ")}`,
    );
  const schema = [
    ...fs
      .readFileSync(path.join(root, "API/src/config/env.validation.ts"), "utf8")
      .matchAll(/^    ([A-Z][A-Z0-9_]*):/gm),
  ].map((match) => match[1]);
  const missingExample = schema.filter((key) => !names.has(key));
  const unvalidated = variables
    .map((item) => item.key)
    .filter((key) => !schema.includes(key) && !key.startsWith("DB_ADMIN_"));
  if (missingExample.length || unvalidated.length)
    throw Error(
      `Revisar cobertura de configuración: ${[...missingExample, ...unvalidated].join(", ")}`,
    );
  const originalFile = path.resolve(root, "../API/.env.example");
  let originalComparison = {
    available: false,
    originalVariables: contract.variables.length,
  };
  if (fs.existsSync(originalFile)) {
    const original = entries(fs.readFileSync(originalFile, "utf8")),
      byName = new Map(variables.map((item) => [item.key, item]));
    const missing = original
      .filter((item) => !byName.has(item.key))
      .map((item) => item.key);
    const changedExamples = original
      .filter(
        (item) =>
          byName.has(item.key) && byName.get(item.key).example !== item.example,
      )
      .map((item) => item.key);
    originalComparison = {
      available: true,
      originalVariables: original.length,
      missing,
      changedExamples,
      added: variables
        .filter((item) => !original.some((other) => other.key === item.key))
        .map((item) => item.key),
    };
    if (missing.length || changedExamples.length)
      throw Error(
        `Cambió el contrato del ejemplo original: ${[...missing, ...changedExamples].join(", ")}`,
      );
  }
  return {
    scope:
      "Variable names and public deployment defaults only. Actual private values remain on the VPS and were not read.",
    originalComparison,
    originalContractVariables: contract.variables.length,
    totalVariables: variables.length,
    variables: variables.map(({ key, optional }) => ({
      key,
      optional,
      ...destination(key),
    })),
  };
}
module.exports = { inventory, entries, destination };
if (require.main === module) {
  try {
    const root = path.resolve(__dirname, "..");
    const report = inventory(root);
    if (process.argv.includes("--write-report")) {
      fs.writeFileSync(
        path.join(root, "docs/API-ENV-REPORT.json"),
        JSON.stringify(report, null, 2) + "\n",
      );
      const rows = report.variables.map(
        (item) =>
          `| \`${item.key}\` | ${item.optional ? "Opcional/comentada" : "Activa en el ejemplo"} | ${item.destination} | ${item.effectiveValue ? `\`${item.effectiveValue}\` (PM2)` : item.note} |`,
      );
      fs.writeFileSync(
        path.join(root, "docs/API-ENV-MAP.md"),
        `# Destino de cada variable de API\n\nGenerado desde \`API/.env.example\`; no lee valores privados del servidor. Las ${report.originalComparison.originalVariables || ""} variables del ejemplo original se conservan. Se documentan además HOST y FCM_SERVICE_ACCOUNT_PATH.\n\n| Variable | Ejemplo | Archivo o consumidor de producción | Conservación / prioridad |\n| --- | --- | --- | --- |\n${rows.join("\n")}\n\nLos valores de ejemplo sirven para documentación y desarrollo; no sustituyen las credenciales actuales. \`api.env\` y \`migrations.env\` se copian por separado desde el despliegue anterior. La preparación comprueba cada valor no gestionado después de retirar las URL centrales, incluidas claves desconocidas, contraseñas con # y valores multilínea.\n\n\`PUBLIC_LANDING_URL\` pertenece al archivo público central y no es una variable que la API original necesitara. \`DOCIA_SITES_FILE\` y \`DOCIA_RELEASE\` los fija PM2 por release; \`DOTENV_CONFIG_PATH\` lo fija el comando de migraciones.\n\nPara regenerar: \`npm run audit:api-env\`. Para probar la conservación de valores: \`npm run test:api-env\`, después de instalar las dependencias de API.\n`,
      );
    }
    console.log(
      `Inventario correcto: ${report.totalVariables} variables; sin omisiones ni cambios en los ejemplos originales.`,
    );
  } catch (error) {
    console.error(
      error.code
        ? "No se pudo revisar el inventario de variables."
        : error.message,
    );
    process.exitCode = 1;
  }
}
