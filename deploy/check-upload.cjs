// Inspect source without printing matching content; build caches are intentionally excluded.
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const skip = new Set([
  ".git",
  "node_modules",
  "build",
  "dist",
  ".dart_tool",
  ".gradle",
  ".validation",
  "generated",
  "release",
  "android-release",
  "coverage",
  ".idea",
]);
let count = 0;
const errors = [];
function visit(dir) {
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    if (
      skip.has(item.name) ||
      item.name === "local.properties" ||
      item.name === ".flutter-plugins-dependencies"
    )
      continue;
    const file = path.join(dir, item.name),
      relative = path.relative(root, file).replaceAll("\\", "/");
    if (item.isSymbolicLink()) {
      errors.push(`${relative}: enlace simbólico`);
      continue;
    }
    if (item.isDirectory()) {
      if (item.name === "secrets") errors.push(`${relative}: carpeta privada`);
      else visit(file);
      continue;
    }
    if (
      /^(?:\.env(?:\.(?!example$).*)?|key\.properties|local\.properties)$/.test(
        item.name,
      ) ||
      /\.(jks|keystore|p12|pfx|key|apk|aab)$/.test(item.name) ||
      /^client_secret.*\.json$/.test(item.name)
    ) {
      errors.push(`${relative}: archivo privado o binario de distribución`);
      continue;
    }
    if (fs.statSync(file).size > 2 * 1024 * 1024) continue;
    const body = fs
      .readFileSync(file, "utf8")
      .split(/\r?\n/)
      .filter((line) => !line.trimStart().startsWith("#"))
      .join("\n");
    if (
      /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(body) ||
      /"type"\s*:\s*"service_account"/.test(body)
    )
      errors.push(`${relative}: credencial privada`);
    count++;
  }
}
visit(root);
if (errors.length) {
  console.error(errors.join("\n"));
  process.exitCode = 1;
} else
  console.log(
    `Revisión de ${count} archivos: sin entornos privados, claves de firma ni repositorios anidados en el código fuente.`,
  );
