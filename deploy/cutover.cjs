// Explicit root-only, bounded edits to the three existing DocIA virtual hosts.
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { parseEnv } = require("./public-config.cjs");
const { root } = require("./layout.cjs");
const run = (file, args = []) => execFileSync(file, args, { stdio: "inherit" });
function transform(text, component) {
  if (component === "api") {
    if (!/proxy_pass\s+http:\/\/(?:127\.0\.0\.1|localhost):3000\b/.test(text))
      throw Error("No se encontró el upstream esperado de la API en 3000.");
    return text.replace(
      /(proxy_pass\s+http:\/\/(?:127\.0\.0\.1|localhost):)3000\b/g,
      "$13100",
    );
  }
  const directory = component === "web" ? "web" : "landing";
  const oldRoot =
    component === "web"
      ? "/var/www/docia/web/build/web"
      : "/var/www/docia/landing/dist";
  const releaseRoot = `/var/www/docia/deploy/current-${directory}/${directory}`;
  const target = `${root}/current-${directory}/${directory}`;
  if (!text.includes(oldRoot) && !text.includes(releaseRoot))
    throw Error(`No se encontró el root esperado de ${component}.`);
  return text
    .replaceAll(releaseRoot, target)
    .replaceAll(oldRoot, target)
    .replaceAll(
      "/var/www/docia/deploy/current-web/web/downloads",
      `${root}/current-web/web/downloads`,
    );
}
module.exports = { transform };
if (require.main === module) {
  let originals = [],
    backup,
    changed = false;
  try {
    if (process.getuid?.() !== 0) throw Error("Ejecutar como root.");
    const mode = process.argv[2];
    const args = process.argv.slice(3);
    if (mode === "restore") {
      backup = fs.realpathSync(args[0] || "");
      if (!backup.startsWith("/root/docia-monorepo-nginx-backups/"))
        throw Error("Ruta de respaldo inválida.");
      const records = JSON.parse(
        fs.readFileSync(path.join(backup, "manifest.json"), "utf8"),
      );
      if (records.length !== 3) throw Error("Respaldo inválido.");
      for (const item of records) {
        if (
          !/^\/etc\/nginx\/(?:sites-available|sites-enabled|conf\.d)\/[^/]+$/.test(
            item.file,
          )
        )
          throw Error("Destino de respaldo inválido.");
        if (fs.realpathSync(item.file) !== item.file)
          throw Error("El destino de Nginx cambió desde el respaldo.");
      }
      originals = records.map((item, i) => ({
        ...item,
        text: fs.readFileSync(item.file),
        restore: fs.readFileSync(path.join(backup, `${i}.conf`)),
      }));
      changed = true;
      for (const item of originals) fs.writeFileSync(item.file, item.restore);
      run("nginx", ["-t"]);
      run("systemctl", ["reload", "nginx"]);
      const config = `${root}/shared/server.conf`;
      fs.writeFileSync(
        config,
        fs
          .readFileSync(config, "utf8")
          .replace(/^PUBLIC_CHECKS=1$/m, "PUBLIC_CHECKS=0")
          .replace(/^RUN_MIGRATIONS=1$/m, "RUN_MIGRATIONS=0"),
      );
      changed = false;
      console.log(
        "NGINX_RESTAURADO. Producción vuelve al despliegue anterior; verificar su salud.",
      );
    } else if (mode === "activate") {
      if (args.length !== 3)
        throw Error(
          "Uso: node deploy/cutover.cjs activate API_CONF WEB_CONF LANDING_CONF",
        );
      const sites = parseEnv(
        fs.readFileSync(
          path.resolve(__dirname, "../config/environments/production.env"),
          "utf8",
        ),
      );
      originals = args.map((arg, i) => {
        const file = fs.realpathSync(arg);
        if (
          !/^\/etc\/nginx\/(?:sites-available|sites-enabled|conf\.d)\/[^/]+$/.test(
            file,
          )
        )
          throw Error("Archivo fuera de los directorios de Nginx permitidos.");
        const component = ["api", "web", "landing"][i],
          text = fs.readFileSync(file, "utf8");
        const host = new URL(
          sites[["PUBLIC_API_URL", "PUBLIC_WEB_URL", "PUBLIC_LANDING_URL"][i]],
        ).hostname;
        const names = [...text.matchAll(/\bserver_name\s+([^;]+);/g)].flatMap(
          (m) => m[1].trim().split(/\s+/),
        );
        const allowed =
          component === "landing" ? [host, `www.${host}`] : [host];
        if (
          !names.includes(host) ||
          names.some((name) => !allowed.includes(name))
        )
          throw Error(
            "El virtual host incluye nombres ajenos al componente DocIA.",
          );
        return { file, text, next: transform(text, component) };
      });
      if (new Set(originals.map((item) => item.file)).size !== 3)
        throw Error("Se requieren tres archivos distintos.");
      for (const component of ["api", "web", "landing"])
        if (!fs.existsSync(`${root}/current-${component}/DEPLOYMENT_ID`))
          throw Error("Publicar primero los tres componentes en modo privado.");
      run("nginx", ["-t"]);
      fs.mkdirSync("/root/docia-monorepo-nginx-backups", {
        recursive: true,
        mode: 0o700,
      });
      backup = fs.mkdtempSync("/root/docia-monorepo-nginx-backups/cutover-");
      originals.forEach((item, i) =>
        fs.writeFileSync(path.join(backup, `${i}.conf`), item.text, {
          mode: 0o600,
        }),
      );
      fs.writeFileSync(
        path.join(backup, "manifest.json"),
        JSON.stringify(originals.map(({ file }) => ({ file }))),
        { mode: 0o600 },
      );
      changed = true;
      for (const item of originals) fs.writeFileSync(item.file, item.next);
      run("nginx", ["-t"]);
      run("systemctl", ["reload", "nginx"]);
      let healthy = false;
      for (let attempt = 0; attempt < 5; attempt++) {
        try {
          run(process.execPath, [path.join(__dirname, "check-public.cjs")]);
          healthy = true;
          break;
        } catch {
          if (attempt < 4) run("sleep", ["2"]);
        }
      }
      if (!healthy)
        throw Error("Falló la salud pública después de la recarga.");
      const config = `${root}/shared/server.conf`;
      fs.writeFileSync(
        config,
        fs
          .readFileSync(config, "utf8")
          .replace(/^PUBLIC_CHECKS=0$/m, "PUBLIC_CHECKS=1"),
      );
      changed = false;
      console.log(`CAMBIO_OK. Respaldo para restore: ${backup}`);
    } else throw Error("Indicar activate o restore.");
  } catch (error) {
    if (changed) {
      try {
        for (const item of originals) fs.writeFileSync(item.file, item.text);
        run("nginx", ["-t"]);
        run("systemctl", ["reload", "nginx"]);
        console.error("Se restauró la configuración previa a este intento.");
      } catch {
        console.error(
          `Restauración fallida: revisar el respaldo privado ${backup}.`,
        );
      }
    }
    console.error(
      error.code || error.status
        ? "Operación fallida; revisar el diagnóstico de Nginx y la salud de DocIA."
        : error.message,
    );
    process.exitCode = 1;
  }
}
