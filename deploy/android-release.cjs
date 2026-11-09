// Release credentials stay in the runner; only the signed APK and public metadata are published.
const fs = require("node:fs");
const path = require("node:path");
const { createHash, X509Certificate } = require("node:crypto");
const { spawnSync } = require("node:child_process");
// Public certificate fingerprint of the APK already distributed by the landing.
const expectedCertificateSha256 =
  "5f4b6102a0a202ca07c250ffc3da0fe14354b7d7611faf249c0e4fa274c35598";

function property(value) {
  return value
    .split("")
    .map((char) => {
      const escapes = {
        "\\": "\\\\",
        "\n": "\\n",
        "\r": "\\r",
        "\t": "\\t",
        "\f": "\\f",
      };
      if (escapes[char]) return escapes[char];
      if (" :=#!".includes(char)) return `\\${char}`;
      const code = char.charCodeAt(0);
      return code < 32 || code > 126
        ? `\\u${code.toString(16).padStart(4, "0")}`
        : char;
    })
    .join("");
}

function version() {
  const match = fs
    .readFileSync("pubspec.yaml", "utf8")
    .match(/^version:\s*(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)(?:\+\d+)?\s*$/m);
  if (!match) throw Error("No se pudo leer la versión de pubspec.yaml.");
  return match[1];
}

function signingPaths() {
  const runnerTemp = process.env.RUNNER_TEMP;
  if (!runnerTemp || !fs.statSync(runnerTemp).isDirectory())
    throw Error("Falta RUNNER_TEMP.");
  const directory = path.join(
    path.resolve(runnerTemp),
    "docia-android-signing",
  );
  return {
    directory,
    keystore: path.join(directory, "release.jks"),
    properties: "android/key.properties",
  };
}

function prepare() {
  const required = [
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
  ];
  if (required.some((key) => !process.env[key]))
    throw Error(
      "Faltan secrets ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS o ANDROID_KEY_PASSWORD.",
    );
  const encoded = process.env.ANDROID_KEYSTORE_BASE64.replace(/\s/g, "");
  const decoded = Buffer.from(encoded, "base64");
  if (!decoded.length || decoded.toString("base64") !== encoded)
    throw Error("ANDROID_KEYSTORE_BASE64 no contiene Base64 válido.");
  const run = process.env.GITHUB_RUN_NUMBER || "";
  const base = Number(process.env.ANDROID_VERSION_CODE_BASE || 0);
  if (!Number.isSafeInteger(base) || base < 200000)
    throw Error(
      "Configurar ANDROID_VERSION_CODE_BASE >= 200000 para conservar la continuidad al migrar de repositorio.",
    );
  const buildNumber = base + Number(run);
  if (
    !/^[1-9]\d*$/.test(run) ||
    !Number.isSafeInteger(buildNumber) ||
    buildNumber > 2100000000
  )
    throw Error(
      "GITHUB_RUN_NUMBER no permite generar un versionCode Android válido.",
    );
  version();
  const files = signingPaths();
  if (fs.existsSync(files.properties))
    throw Error("Ya existe android/key.properties; no se sobrescribirá.");
  fs.mkdirSync(files.directory, { mode: 0o700 });
  fs.writeFileSync(files.keystore, decoded, { mode: 0o600, flag: "wx" });
  const values = {
    storeFile: files.keystore.replace(/\\/g, "/"),
    storePassword: process.env.ANDROID_KEYSTORE_PASSWORD,
    keyAlias: process.env.ANDROID_KEY_ALIAS,
    keyPassword: process.env.ANDROID_KEY_PASSWORD,
  };
  fs.writeFileSync(
    files.properties,
    Object.entries(values)
      .map(([key, value]) => `${key}=${property(value)}\n`)
      .join(""),
    { mode: 0o600, flag: "wx" },
  );
  if (!process.env.GITHUB_OUTPUT) throw Error("Falta GITHUB_OUTPUT.");
  fs.appendFileSync(process.env.GITHUB_OUTPUT, `build_number=${buildNumber}\n`);
  console.log(`Firma release preparada; versionCode=${buildNumber}.`);
}

function verifyCertificate(digests, source) {
  const actual = [...new Set(digests.map((digest) => digest.toLowerCase()))];
  if (actual.length !== 1 || actual[0] !== expectedCertificateSha256) {
    // Certificate fingerprints are public; never include keytool output, aliases or passwords.
    throw Error(
      `${source}: el certificado no coincide. SHA-256 esperado: ${expectedCertificateSha256}; recibido: ${actual.join(", ")}. Revisar ANDROID_KEYSTORE_BASE64 y ANDROID_KEY_ALIAS; no se publicará una firma diferente.`,
    );
  }
}

function verifyKeystore() {
  if (!process.env.ANDROID_KEYSTORE_PASSWORD || !process.env.ANDROID_KEY_ALIAS)
    throw Error(
      "Faltan ANDROID_KEYSTORE_PASSWORD o ANDROID_KEY_ALIAS para verificar la firma.",
    );
  const files = signingPaths();
  const executable = process.platform === "win32" ? "keytool.exe" : "keytool";
  const keytool = process.env.JAVA_HOME
    ? path.join(process.env.JAVA_HOME, "bin", executable)
    : executable;
  const result = spawnSync(
    keytool,
    [
      "-exportcert",
      "-keystore",
      files.keystore,
      "-alias",
      process.env.ANDROID_KEY_ALIAS,
      "-storepass:env",
      "ANDROID_KEYSTORE_PASSWORD",
    ],
    { timeout: 15000, maxBuffer: 65536, windowsHide: true },
  );
  if (result.error || result.status !== 0 || !result.stdout?.length)
    throw Error(
      "No se pudo leer el certificado del keystore. Revisar JAVA_HOME, ANDROID_KEYSTORE_PASSWORD y ANDROID_KEY_ALIAS. La salida de keytool se mantiene privada.",
    );
  let certificate;
  try {
    certificate = new X509Certificate(result.stdout);
  } catch {
    throw Error("keytool no devolvió un certificado X.509 válido.");
  }
  const digest = createHash("sha256").update(certificate.raw).digest("hex");
  verifyCertificate([digest], "Keystore");
  console.log(
    `Keystore verificado antes del build. Certificado SHA-256: ${digest}`,
  );
}

function packageApk() {
  const id = process.env.RELEASE_ID || "";
  if (!/^[0-9a-f]{40}-\d+-\d+$/.test(id)) throw Error("RELEASE_ID inválido.");
  const code = process.env.ANDROID_BUILD_NUMBER || "";
  if (!/^[1-9]\d*$/.test(code) || Number(code) > 2100000000)
    throw Error("ANDROID_BUILD_NUMBER inválido.");
  const versionName = version();
  const badging = fs.readFileSync(
    path.join(process.env.RUNNER_TEMP, "docia-apk-badging.txt"),
    "utf8",
  );
  const identity = badging.match(
    /^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'/m,
  );
  if (
    !identity ||
    identity[1] !== "com.jampic.jampic" ||
    identity[2] !== code ||
    identity[3] !== versionName
  )
    throw Error("El APK no tiene el applicationId o la versión esperados.");
  const signature = fs.readFileSync(
    path.join(process.env.RUNNER_TEMP, "docia-apk-signature.txt"),
    "utf8",
  );
  // Read X.509 certificates, never the version-dependent human-readable digest labels.
  // All certificates must match: an additional signer or source stamp cannot hide a different key.
  const pemCertificates = [
    ...signature.matchAll(
      /-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g,
    ),
  ];
  const headers = signature.match(/-----BEGIN CERTIFICATE-----/g) || [];
  if (!pemCertificates.length || pemCertificates.length !== headers.length)
    throw Error(
      `apksigner no devolvió certificados PEM completos (${Buffer.byteLength(signature)} bytes de salida). El workflow debe usar --print-certs-pem. No se publicará el APK.`,
    );
  const certificates = pemCertificates.map(([pem]) => {
    let certificate;
    try {
      certificate = new X509Certificate(pem);
    } catch {
      throw Error(
        "apksigner devolvió un certificado PEM inválido. No se publicará el APK.",
      );
    }
    return createHash("sha256").update(certificate.raw).digest("hex");
  });
  verifyCertificate(certificates, "APK");
  console.log(
    `Certificado del APK verificado desde PEM. SHA-256: ${certificates[0]}`,
  );
  const apk = fs.readFileSync("build/app/outputs/flutter-apk/app-release.apk");
  if (apk.length < 4 || apk.readUInt32LE(0) !== 0x04034b50)
    throw Error("El artefacto Android no es un APK válido.");
  const sha256 = createHash("sha256").update(apk).digest("hex");
  fs.mkdirSync("android-release", { recursive: true });
  fs.writeFileSync("android-release/DocIA.apk", apk);
  fs.writeFileSync("android-release/DocIA.apk.sha256", `${sha256}\n`);
  fs.writeFileSync(
    "android-release/android-release.json",
    `${JSON.stringify(
      {
        release: `web-${id}`,
        applicationId: identity[1],
        versionName,
        versionCode: Number(code),
        apk: "DocIA.apk",
        sha256,
        signingCertificateSha256: expectedCertificateSha256,
      },
      null,
      2,
    )}\n`,
  );
  console.log(
    `APK ${versionName} (${code}) preparado para la misma publicación que la web.`,
  );
}

function clean() {
  const files = signingPaths();
  // Only remove properties created for this runner's temporary keystore.
  if (fs.existsSync(files.properties)) {
    const marker = `storeFile=${property(files.keystore.replace(/\\/g, "/"))}`;
    if (
      fs.readFileSync(files.properties, "utf8").split(/\r?\n/).includes(marker)
    )
      fs.unlinkSync(files.properties);
  }
  if (fs.existsSync(files.keystore)) fs.unlinkSync(files.keystore);
  if (fs.existsSync(files.directory)) fs.rmdirSync(files.directory);
}

try {
  const command = {
    prepare,
    "verify-keystore": verifyKeystore,
    package: packageApk,
    clean,
  }[process.argv[2]];
  if (!command)
    throw Error(
      "Uso: android-release.cjs prepare|verify-keystore|package|clean",
    );
  command();
} catch (error) {
  // Filesystem/decoder errors can contain data or filenames from secrets.
  console.error(
    error.code
      ? "No se pudo preparar el APK: revisar archivos y permisos del runner."
      : error.message,
  );
  process.exitCode = 1;
}
