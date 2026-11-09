const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { createHash } = require("node:crypto");
const { rootCertificates } = require("node:tls");
const script = path.resolve(__dirname, "../android-release.cjs");
// Public X.509 certificate extracted from the originally distributed APK; contains no private key.
const originalCertificate = fs.readFileSync(
  path.join(__dirname, "fixtures/docia-signing-certificate.pem"),
  "utf8",
);
const otherCertificate = rootCertificates[0];

function fixture() {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "docia-android-"));
  fs.mkdirSync(path.join(cwd, "android"));
  fs.mkdirSync(path.join(cwd, "runner"));
  fs.writeFileSync(path.join(cwd, "pubspec.yaml"), "version: 1.0.1+2\n");
  const env = {
    ...process.env,
    RUNNER_TEMP: path.join(cwd, "runner"),
    GITHUB_OUTPUT: path.join(cwd, "output"),
    GITHUB_RUN_NUMBER: "42",
    ANDROID_KEYSTORE_BASE64:
      Buffer.from("synthetic-keystore").toString("base64"),
    ANDROID_VERSION_CODE_BASE: "200000",
    ANDROID_KEYSTORE_PASSWORD: " #synthetic:=private\\valueé",
    ANDROID_KEY_ALIAS: "docia",
    ANDROID_KEY_PASSWORD: "synthetic-private-key-password",
    RELEASE_ID: `${"a".repeat(40)}-123-1`,
    ANDROID_BUILD_NUMBER: "200042",
  };
  return {
    cwd,
    env,
    run(command, overrides = {}) {
      return spawnSync(process.execPath, [script, command], {
        cwd,
        encoding: "utf8",
        env: { ...env, ...overrides },
      });
    },
    read(file) {
      return fs.readFileSync(path.join(cwd, file), "utf8");
    },
    close() {
      fs.rmSync(cwd, { recursive: true, force: true });
    },
  };
}

test("restores signing without printing credentials, escapes Java properties, and cleans only its own files", () => {
  const f = fixture();
  try {
    fs.writeFileSync(path.join(f.cwd, "runner/unrelated"), "keep");
    const result = f.run("prepare");
    assert.equal(result.status, 0, result.stderr);
    assert.doesNotMatch(result.stdout + result.stderr, /synthetic|private/);
    assert.match(
      f.read("android/key.properties"),
      /storePassword=\\ \\#synthetic\\:\\=private\\\\value\\u00e9/,
    );
    assert.match(f.read("output"), /build_number=200042/);
    assert.equal(
      f.read("runner/docia-android-signing/release.jks"),
      "synthetic-keystore",
    );
    assert.equal(f.run("clean").status, 0);
    assert.equal(
      fs.existsSync(path.join(f.cwd, "android/key.properties")),
      false,
    );
    assert.equal(
      fs.existsSync(path.join(f.cwd, "runner/docia-android-signing")),
      false,
    );
    assert.equal(f.read("runner/unrelated"), "keep");
  } finally {
    f.close();
  }
});

for (const [name, overrides] of Object.entries({
  "missing signing password": { ANDROID_KEY_PASSWORD: "" },
  "invalid Base64": {
    ANDROID_KEYSTORE_BASE64: "synthetic-private-invalid-base64",
  },
  "out-of-range versionCode": { GITHUB_RUN_NUMBER: "2100000000" },
  "missing monorepo version base": { ANDROID_VERSION_CODE_BASE: "" },
  "regressed monorepo version base": { ANDROID_VERSION_CODE_BASE: "100000" },
})) {
  test(`rejects ${name} without exposing input or writing credentials`, () => {
    const f = fixture();
    try {
      const result = f.run("prepare", overrides);
      assert.equal(result.status, 1);
      assert.doesNotMatch(result.stdout + result.stderr, /synthetic/);
      assert.equal(
        fs.existsSync(path.join(f.cwd, "android/key.properties")),
        false,
      );
    } finally {
      f.close();
    }
  });
}

test("preserves an existing local signing configuration", () => {
  const f = fixture();
  try {
    fs.writeFileSync(
      path.join(f.cwd, "android/key.properties"),
      "local-secret",
    );
    assert.equal(f.run("prepare").status, 1);
    assert.equal(f.run("clean").status, 0);
    assert.equal(f.read("android/key.properties"), "local-secret");
  } finally {
    f.close();
  }
});

function apkFixture(
  f,
  applicationId = "com.jampic.jampic",
  versionCode = "200042",
) {
  fs.mkdirSync(path.join(f.cwd, "build/app/outputs/flutter-apk"), {
    recursive: true,
  });
  fs.writeFileSync(
    path.join(f.cwd, "build/app/outputs/flutter-apk/app-release.apk"),
    Buffer.from("504b030461706b", "hex"),
  );
  fs.writeFileSync(
    path.join(f.cwd, "runner/docia-apk-badging.txt"),
    `package: name='${applicationId}' versionCode='${versionCode}' versionName='1.0.1'\n`,
  );
  fs.writeFileSync(
    path.join(f.cwd, "runner/docia-apk-signature.txt"),
    originalCertificate,
  );
}

test("rejects a valid APK signed with another certificate before publication", () => {
  const f = fixture();
  try {
    apkFixture(f);
    fs.writeFileSync(
      path.join(f.cwd, "runner/docia-apk-signature.txt"),
      otherCertificate,
    );
    const result = f.run("package");
    assert.equal(result.status, 1);
    assert.match(result.stderr, /certificado/);
    assert.match(result.stderr, /SHA-256 esperado:/);
    assert.match(result.stderr, /recibido: [0-9a-f]{64}/);
    assert.equal(fs.existsSync(path.join(f.cwd, "android-release")), false);
  } finally {
    f.close();
  }
});

for (const [name, report] of [
  ["PEM without digest labels", originalCertificate],
  [
    "SDK range labels",
    `Signer (minSdkVersion=33, maxSdkVersion=2147483647)\n${originalCertificate}`,
  ],
  [
    "CRLF and unrelated text",
    `\uFEFFVerifies\r\n${originalCertificate.replace(/\n/g, "\r\n")}\r\nOther diagnostic text`,
  ],
  ["repeated original certificate", originalCertificate + originalCertificate],
]) {
  test(`hashes the original X.509 certificate with ${name}`, () => {
    const f = fixture();
    try {
      apkFixture(f);
      fs.writeFileSync(
        path.join(f.cwd, "runner/docia-apk-signature.txt"),
        report,
      );
      const result = f.run("package");
      assert.equal(result.status, 0, result.stderr);
    } finally {
      f.close();
    }
  });
}

test("rejects a rotated or additional certificate even when the original is present", () => {
  const f = fixture();
  try {
    apkFixture(f);
    fs.appendFileSync(
      path.join(f.cwd, "runner/docia-apk-signature.txt"),
      otherCertificate,
    );
    assert.equal(f.run("package").status, 1);
  } finally {
    f.close();
  }
});

test("does not confuse a matching source stamp with the APK signing certificate", () => {
  const f = fixture();
  try {
    apkFixture(f);
    fs.writeFileSync(
      path.join(f.cwd, "runner/docia-apk-signature.txt"),
      `Signer #1\n${otherCertificate}\nSource Stamp Signer\n${originalCertificate}\nsynthetic-private-value`,
    );
    const result = f.run("package");
    assert.equal(result.status, 1);
    assert.match(result.stderr, /certificado no coincide/);
    assert.doesNotMatch(
      result.stdout + result.stderr,
      /synthetic-private-value/,
    );
  } finally {
    f.close();
  }
});

for (const [name, report] of [
  ["empty report", ""],
  [
    "digest labels without PEM",
    "Signer #1 certificate SHA-256 digest: 5f4b6102a0a202ca07c250ffc3da0fe14354b7d7611faf249c0e4fa274c35598\n",
  ],
  [
    "invalid certificate",
    "-----BEGIN CERTIFICATE-----\nc3ludGhldGljLXByaXZhdGU=\n-----END CERTIFICATE-----",
  ],
  [
    "truncated additional certificate",
    `${originalCertificate}\n-----BEGIN CERTIFICATE-----\nsynthetic-private-value`,
  ],
]) {
  test(`refuses to publish with ${name} without exposing report contents`, () => {
    const f = fixture();
    try {
      apkFixture(f);
      fs.writeFileSync(
        path.join(f.cwd, "runner/docia-apk-signature.txt"),
        report,
      );
      const result = f.run("package");
      assert.equal(result.status, 1);
      assert.match(result.stderr, /PEM/);
      assert.doesNotMatch(
        result.stdout + result.stderr,
        /synthetic|c3ludGhldGlj/,
      );
      assert.equal(fs.existsSync(path.join(f.cwd, "android-release")), false);
    } finally {
      f.close();
    }
  });
}

test("checks required keystore credentials without exposing values", () => {
  const f = fixture();
  try {
    const result = f.run("verify-keystore", { ANDROID_KEY_ALIAS: "" });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Faltan/);
    assert.doesNotMatch(result.stdout + result.stderr, /synthetic/);
  } finally {
    f.close();
  }
});

test("packages only APK, checksum and public metadata with the verified Android identity", () => {
  const f = fixture();
  try {
    apkFixture(f);
    const result = f.run("package");
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(
      fs.readdirSync(path.join(f.cwd, "android-release")).sort(),
      ["DocIA.apk", "DocIA.apk.sha256", "android-release.json"].sort(),
    );
    const metadata = JSON.parse(f.read("android-release/android-release.json"));
    const digest = createHash("sha256")
      .update(fs.readFileSync(path.join(f.cwd, "android-release/DocIA.apk")))
      .digest("hex");
    assert.equal(metadata.sha256, digest);
    assert.equal(metadata.versionCode, 200042);
    assert.equal(metadata.release, `web-${f.env.RELEASE_ID}`);
    assert.equal(f.read("android-release/DocIA.apk.sha256").trim(), digest);
    assert.doesNotMatch(
      JSON.stringify(metadata),
      /password|keystore|synthetic/,
    );
  } finally {
    f.close();
  }
});

for (const [name, applicationId, code] of [
  ["different applicationId", "com.example.other", "200042"],
  ["wrong versionCode", "com.jampic.jampic", "2"],
]) {
  test(`rejects an APK with ${name}`, () => {
    const f = fixture();
    try {
      apkFixture(f, applicationId, code);
      assert.equal(f.run("package").status, 1);
      assert.equal(fs.existsSync(path.join(f.cwd, "android-release")), false);
    } finally {
      f.close();
    }
  });
}
