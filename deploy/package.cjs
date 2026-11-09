// Package only reviewed build outputs; never copy environment credentials or source repositories.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { createHash } = require("node:crypto");
const { spawnSync } = require("node:child_process");
const { parseEnv } = require("./public-config.cjs");
const fingerprint =
  "5f4b6102a0a202ca07c250ffc3da0fe14354b7d7611faf249c0e4fa274c35598";
const digest = (file) =>
  createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const forbidden = (name) =>
  /^(?:\.env(?:\..*)?|\.git|node_modules|secrets|key\.properties|local\.properties)$/.test(
    name,
  ) || /\.(?:jks|keystore|p12|pfx|key)$/.test(name);

function copyTree(source, destination, exclude = () => false) {
  const stat = fs.lstatSync(source);
  if (stat.isSymbolicLink() || (!stat.isDirectory() && !stat.isFile()))
    throw Error("El build contiene enlaces o archivos especiales.");
  if (forbidden(path.basename(source)))
    throw Error("El build contiene un archivo de configuración privado.");
  if (exclude(path.basename(source))) return;
  if (stat.isDirectory()) {
    fs.mkdirSync(destination, { recursive: true });
    for (const entry of fs.readdirSync(source))
      copyTree(
        path.join(source, entry),
        path.join(destination, entry),
        exclude,
      );
  } else {
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(source, destination);
  }
}

function publicConfig(root) {
  const values = parseEnv(
    fs.readFileSync(
      path.join(root, "config/environments/production.env"),
      "utf8",
    ),
  );
  return (
    Object.entries(values)
      .map(([key, value]) => `${key}=${value}`)
      .join("\n") + "\n"
  );
}

function packageRelease(component, root, id) {
  if (
    !["api", "web", "landing"].includes(component) ||
    !/^[0-9a-f]{40}-\d+-\d+$/.test(id)
  )
    throw Error("Componente o RELEASE_ID inválido.");
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "docia-package-"));
  try {
    const name = `${component}-${id}`;
    fs.writeFileSync(path.join(temporary, "DEPLOYMENT_ID"), name + "\n");
    fs.writeFileSync(
      path.join(temporary, "PUBLIC_CONFIG.env"),
      publicConfig(root),
    );
    const output = path.join(temporary, component);
    if (component === "api") {
      const api = path.join(root, "API");
      for (const item of [
        "dist",
        "package.json",
        "package-lock.json",
        "scripts/run-migrations.ts",
        "src/config/database-url.ts",
        "db/migrations",
      ])
        copyTree(path.join(api, item), path.join(output, item));
      if (!fs.existsSync(path.join(output, "dist/main.js")))
        throw Error("Falta el build API.");
      copyTree(
        path.join(root, "deploy/ecosystem.config.cjs"),
        path.join(temporary, "ecosystem.config.cjs"),
      );
    } else if (component === "web") {
      copyTree(path.join(root, "APP-MVP/build/web"), output);
      if (!fs.existsSync(path.join(output, "flutter_bootstrap.js")))
        throw Error("Falta el bootstrap Flutter.");
      const android = path.join(root, "android-release");
      const metadata = JSON.parse(
        fs.readFileSync(path.join(android, "android-release.json"), "utf8"),
      );
      const checksum = fs
        .readFileSync(path.join(android, "DocIA.apk.sha256"), "utf8")
        .trim();
      if (
        metadata.release !== name ||
        metadata.applicationId !== "com.jampic.jampic" ||
        metadata.signingCertificateSha256 !== fingerprint ||
        !Number.isInteger(metadata.versionCode) ||
        metadata.versionCode < 200000 ||
        digest(path.join(android, "DocIA.apk")) !== checksum ||
        metadata.sha256 !== checksum
      )
        throw Error("APK, firma, versión o release no coinciden con la web.");
      for (const item of [
        "DocIA.apk",
        "DocIA.apk.sha256",
        "android-release.json",
      ])
        copyTree(
          path.join(android, item),
          path.join(output, "downloads", item),
        );
    } else {
      copyTree(
        path.join(root, "Landing/dist"),
        output,
        (name) => name === "downloads",
      );
      const entries = [];
      const visit = (directory, prefix = "") => {
        for (const name of fs.readdirSync(directory).sort()) {
          const file = path.join(directory, name);
          const relative = prefix + name;
          if (fs.statSync(file).isDirectory()) visit(file, relative + "/");
          else if (
            relative === "index.html" ||
            /^assets\/[a-zA-Z0-9._/-]+\.(?:js|css)$/.test(relative)
          )
            entries.push(`${digest(file)}  ${relative}`);
        }
      };
      visit(output);
      if (
        !entries.some((entry) => entry.endsWith("  index.html")) ||
        !entries.some((entry) => /  assets\/.*\.js$/.test(entry))
      )
        throw Error("Landing incompleta: faltan HTML o JavaScript.");
      fs.writeFileSync(
        path.join(output, "docia-assets.sha256"),
        entries.join("\n") + "\n",
      );
    }
    if (component !== "api") {
      if (!fs.existsSync(path.join(output, "index.html")))
        throw Error("Falta index.html.");
      fs.writeFileSync(path.join(output, "docia-release.txt"), name + "\n");
    }
    const release = path.join(root, "release");
    fs.mkdirSync(release, { recursive: true });
    const archive = path.join(release, name + ".tar.gz");
    const entries = [component, "DEPLOYMENT_ID", "PUBLIC_CONFIG.env"];
    if (component === "api") entries.push("ecosystem.config.cjs");
    const result = spawnSync(
      "tar",
      ["-czf", archive, "-C", temporary, ...entries],
      { windowsHide: true },
    );
    if (result.error || result.status !== 0)
      throw Error("No se pudo crear el artefacto.");
    fs.writeFileSync(
      path.join(release, name + ".sha256"),
      digest(archive) + "\n",
    );
    return archive;
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

module.exports = { packageRelease, copyTree };
if (require.main === module) {
  try {
    packageRelease(
      process.argv[2],
      path.resolve(__dirname, ".."),
      process.env.RELEASE_ID || "",
    );
    console.log(
      `Artefacto ${process.argv[2]} preparado con su configuración pública; sin credenciales.`,
    );
  } catch (error) {
    console.error(
      error.code || error instanceof SyntaxError
        ? "No se pudo preparar el artefacto: revisar archivos de build y configuración pública."
        : error.message,
    );
    process.exitCode = 1;
  }
}
