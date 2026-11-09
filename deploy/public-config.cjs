// Public URLs only. This module is vendored in the three independent repositories.
const fs = require("node:fs");
const path = require("node:path");
const { root, apiPort } = require("./layout.cjs");
const keys = [
  "PUBLIC_API_URL",
  "PUBLIC_WEB_URL",
  "PUBLIC_LANDING_URL",
  "API_PREFIX",
];
const invalid = () =>
  Error(
    "Configuración pública inválida: definir únicamente PUBLIC_API_URL, PUBLIC_WEB_URL, PUBLIC_LANDING_URL (orígenes HTTPS) y opcional API_PREFIX. No incluir secretos.",
  );

function validate(input) {
  if (
    !input ||
    typeof input !== "object" ||
    Array.isArray(input) ||
    Object.keys(input).some((key) => !keys.includes(key))
  )
    throw invalid();
  const result = {};
  for (const key of keys.slice(0, 3)) {
    let url;
    try {
      url = new URL(input[key]);
    } catch {
      throw invalid();
    }
    if (
      url.protocol !== "https:" ||
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      url.pathname !== "/" ||
      url.port ||
      !/^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$/.test(url.hostname) ||
      ["localhost", "127.0.0.1"].includes(url.hostname)
    )
      throw invalid();
    result[key] = url.origin;
  }
  if (new Set(Object.values(result)).size !== 3) throw invalid();
  const prefix = input.API_PREFIX ?? "api/v1";
  if (
    typeof prefix !== "string" ||
    !/^[a-zA-Z0-9_-]+(?:\/[a-zA-Z0-9_-]+)*$/.test(prefix)
  )
    throw invalid();
  return { ...result, API_PREFIX: prefix };
}

function parseEnv(text) {
  const values = {};
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || line.trimStart().startsWith("#")) continue;
    const match = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
    if (!match || Object.hasOwn(values, match[1])) throw invalid();
    let value = match[2];
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    )
      value = value.slice(1, -1);
    values[match[1]] = value;
  }
  return validate(values);
}

function fromEnvironment(required = false) {
  try {
    if (process.env.DOCIA_PUBLIC_CONFIG_JSON)
      return validate(JSON.parse(process.env.DOCIA_PUBLIC_CONFIG_JSON));
    if (process.env.DOCIA_PUBLIC_CONFIG_FILE)
      return parseEnv(
        fs.readFileSync(process.env.DOCIA_PUBLIC_CONFIG_FILE, "utf8"),
      );
    if (required) throw invalid();
    return null;
  } catch {
    throw invalid();
  }
}

function securityHeaders(apiOrigin) {
  return `add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(self), microphone=(self), geolocation=(self)" always;
add_header Content-Security-Policy "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://js.stripe.com https://www.gstatic.com; style-src 'self' 'unsafe-inline'; font-src 'self' data: https://fonts.gstatic.com; img-src 'self' data: blob: https:; media-src 'self' blob:; connect-src 'self' ${apiOrigin} https://*.stripe.com https://*.stripe.network https://*.googleapis.com https://*.gstatic.com wss:; frame-src https://js.stripe.com https://hooks.stripe.com; worker-src 'self' blob:; form-action 'self' https://*.stripe.com; upgrade-insecure-requests" always;
`;
}

function nginxSites(config) {
  const downloads = `location = /downloads/DocIA.apk {
    alias ${root}/current-web/web/downloads/DocIA.apk;
    types { application/vnd.android.package-archive apk; }
    expires -1;
  }
  location = /downloads/DocIA.apk.sha256 {
    alias ${root}/current-web/web/downloads/DocIA.apk.sha256;
    expires -1;
  }
  location = /downloads/android-release.json {
    alias ${root}/current-web/web/downloads/android-release.json;
    expires -1;
  }
  location = /downloads/DocIA_V1.0.1.apk { return 302 /downloads/DocIA.apk; }`;
  const result = {};
  for (const [component, key] of [
    ["api", "PUBLIC_API_URL"],
    ["web", "PUBLIC_WEB_URL"],
    ["landing", "PUBLIC_LANDING_URL"],
  ]) {
    const host = new URL(config[key]).hostname;
    const body =
      component === "api"
        ? `client_max_body_size 50m;
  location / {
    proxy_pass http://127.0.0.1:${apiPort};
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 120s;
  }
  ${downloads}`
        : `# DocIA managed ${component === "landing" ? "landing releases" : "Android downloads"}
  root ${root}/current-${component}/${component};
  index index.html;
  open_file_cache off;
  location / { try_files $uri $uri/ /index.html; }
  location ~ ^/(index\\.html|main\\.dart\\.js|flutter_bootstrap\\.js|flutter_service_worker\\.js|version\\.json|docia-release\\.txt|docia-assets\\.sha256)$ {
    expires -1;
    try_files $uri =404;
  }
  ${downloads}
  ${component === "web" ? securityHeaders(config.PUBLIC_API_URL) : ""}`;
    result[`docia-${component}.conf`] =
      `# Generated from public-sites.env. Review before installing; requires issued certificates.
server {
  listen 80;
  listen [::]:80;
  server_name ${host};
  location /.well-known/acme-challenge/ { root ${root}/acme; }
  location / { return 301 https://${host}$request_uri; }
}
server {
  listen 443 ssl;
  listen [::]:443 ssl;
  server_name ${host};
  ssl_certificate /etc/letsencrypt/live/${host}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${host}/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
  ${body}
}
`;
  }
  const hosts = keys
    .slice(0, 3)
    .map((key) => new URL(config[key]).hostname)
    .join(" ");
  result["docia-http-bootstrap.conf"] =
    `# Temporary HTTP-only site for certificate issuance; remove after enabling HTTPS sites.
server {
  listen 80;
  listen [::]:80;
  server_name ${hosts};
  location /.well-known/acme-challenge/ { root ${root}/acme; }
  location / { return 404; }
}
`;
  return result;
}

function render(config, directory, { apiOnly = false } = {}) {
  const normalized = validate(config);
  fs.mkdirSync(directory, { recursive: true });
  const values = {
    "public-sites.env":
      Object.entries(normalized)
        .map(([key, value]) => `${key}=${value}`)
        .join("\n") + "\n",
    "github-public-config.json": JSON.stringify(normalized, null, 2) + "\n",
    "flutter-production.json":
      JSON.stringify(
        {
          APP_ENV: "production",
          API_BASE_URL: `${normalized.PUBLIC_API_URL}/${normalized.API_PREFIX}/`,
        },
        null,
        2,
      ) + "\n",
    "landing-production.env": `VITE_SITE_URL=${normalized.PUBLIC_LANDING_URL}\nVITE_WEB_APP_URL=${normalized.PUBLIC_WEB_URL}\nVITE_ANDROID_APK_URL=/downloads/DocIA.apk\n`,
    "nginx-web-security.conf": securityHeaders(normalized.PUBLIC_API_URL),
    ...nginxSites(normalized),
  };
  if (apiOnly) {
    delete values["docia-web.conf"];
    delete values["docia-landing.conf"];
    values["docia-http-bootstrap.conf"] = values[
      "docia-http-bootstrap.conf"
    ].replace(
      /server_name [^;]+;/,
      `server_name ${new URL(normalized.PUBLIC_API_URL).hostname};`,
    );
  }
  for (const [name, content] of Object.entries(values))
    fs.writeFileSync(path.join(directory, name), content);
}

module.exports = {
  validate,
  parseEnv,
  fromEnvironment,
  render,
  securityHeaders,
};
if (require.main === module) {
  try {
    if (!["render", "render-api"].includes(process.argv[2]) || !process.argv[3])
      throw Error(
        "Uso: node deploy/public-config.cjs render public-sites.env [directorio-salida]",
      );
    render(
      parseEnv(fs.readFileSync(process.argv[3], "utf8")),
      process.argv[4] || "deploy/generated",
      { apiOnly: process.argv[2] === "render-api" },
    );
    console.log(
      "Configuración pública y plantillas generadas. No se modificó el servidor ni Nginx.",
    );
  } catch (error) {
    console.error(
      error.code
        ? "No se pudo leer o generar la configuración pública."
        : error.message,
    );
    process.exitCode = 1;
  }
}
