// Only validated public URLs enter the frontend build environment.
const fs = require("node:fs");
const { fromEnvironment } = require("./public-config.cjs");
try {
  const sites = fromEnvironment(true);
  if (!process.env.GITHUB_ENV)
    throw Error(
      "Falta GITHUB_ENV. Para builds locales usar .env.local o los archivos generados.",
    );
  fs.appendFileSync(
    process.env.GITHUB_ENV,
    `VITE_SITE_URL=${sites.PUBLIC_LANDING_URL}\nVITE_WEB_APP_URL=${sites.PUBLIC_WEB_URL}\nVITE_ANDROID_APK_URL=/downloads/DocIA.apk\n`,
  );
  console.log(
    "URLs públicas de landing preparadas desde la configuración central.",
  );
} catch (error) {
  console.error(
    error.code
      ? "No se pudo preparar el entorno público de landing."
      : error.message,
  );
  process.exitCode = 1;
}
