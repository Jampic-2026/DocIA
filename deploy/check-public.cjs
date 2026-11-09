// Called by the cutover script; no credentials or response bodies are printed.
const fs = require("node:fs");
const { execFileSync } = require("node:child_process");
const { createHash } = require("node:crypto");
const { parseEnv } = require("./public-config.cjs");
const { root } = require("./layout.cjs");
const get = (url) =>
  execFileSync(
    "curl",
    ["--fail", "--silent", "--connect-timeout", "3", "--max-time", "90", url],
    { maxBuffer: 160 * 1024 * 1024, stdio: ["ignore", "pipe", "ignore"] },
  );
async function main() {
  const conf = parseEnv(
    fs.readFileSync(`${root}/current-api/PUBLIC_CONFIG.env`, "utf8"),
  );
  for (const component of ["api", "web", "landing"]) {
    const release = fs
      .readFileSync(`${root}/current-${component}/DEPLOYMENT_ID`, "utf8")
      .trim();
    const sites = parseEnv(
      fs.readFileSync(`${root}/current-${component}/PUBLIC_CONFIG.env`, "utf8"),
    );
    if (JSON.stringify(conf) !== JSON.stringify(sites))
      throw Error(
        "Los tres componentes requieren la misma configuración pública.",
      );
    if (component === "api") {
      for (const origin of [`http://127.0.0.1:3100`, conf.PUBLIC_API_URL]) {
        const body = JSON.parse(
          get(`${origin}/${conf.API_PREFIX}/health/ready`),
        );
        if (
          body.status !== "ok" ||
          body.service !== "api-docia" ||
          body.release !== release
        )
          throw Error("API: salud o versión incorrecta.");
      }
    } else {
      const origin =
        component === "web" ? conf.PUBLIC_WEB_URL : conf.PUBLIC_LANDING_URL;
      if (
        get(`${origin}/docia-release.txt?deployment=${release}`)
          .toString()
          .trim() !== release
      )
        throw Error(`${component}: marcador incorrecto.`);
      if (component === "web")
        get(`${origin}/flutter_bootstrap.js?deployment=${release}`);
      else
        for (const line of fs
          .readFileSync(
            `${root}/current-landing/landing/docia-assets.sha256`,
            "utf8",
          )
          .trim()
          .split("\n")) {
          const [sha, asset] = line.trim().split(/\s+/);
          if (
            !/^[0-9a-f]{64}$/.test(sha) ||
            !/^(index\.html|assets\/[a-zA-Z0-9._/-]+)$/.test(asset) ||
            asset.includes("..")
          )
            throw Error("Manifiesto inválido.");
          if (
            createHash("sha256")
              .update(get(`${origin}/${asset}?deployment=${release}`))
              .digest("hex") !== sha
          )
            throw Error("Landing: asset incorrecto.");
        }
      const sha = fs
        .readFileSync(
          `${root}/current-web/web/downloads/DocIA.apk.sha256`,
          "utf8",
        )
        .trim();
      if (
        get(`${origin}/downloads/DocIA.apk.sha256`).toString().trim() !== sha ||
        createHash("sha256")
          .update(get(`${origin}/downloads/DocIA.apk`))
          .digest("hex") !== sha
      )
        throw Error(`${component}: APK incorrecto.`);
    }
  }
  console.log("SALUD_PUBLICA_OK: API, web, landing y APK.");
}
main().catch((error) => {
  console.error(
    error.status || error.code || error instanceof SyntaxError
      ? "No se pudo verificar la publicación pública."
      : error.message,
  );
  process.exitCode = 1;
});
