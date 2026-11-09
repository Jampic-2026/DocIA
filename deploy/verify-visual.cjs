// Local visual comparison only; all API operations are intercepted with synthetic fixtures.
const fs = require("node:fs"),
  path = require("node:path"),
  http = require("node:http");
const { createRequire } = require("node:module");
const visualRequire = createRequire(
  require("node:path").resolve(__dirname, "../.validation/package.json"),
);
const { chromium } = visualRequire("playwright-core");
const { PNG } = visualRequire("pngjs");
const root = path.resolve(__dirname, ".."),
  out = path.join(root, ".validation/results");
fs.mkdirSync(out, { recursive: true });
const mime = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".jpg": "image/jpeg",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
};
const permissions = [
  ...fs
    .readFileSync(
      path.join(root, "APP-MVP/lib/core/authorization/permission_codes.dart"),
      "utf8",
    )
    .matchAll(/=\s*'([^']+)'/g),
].map((m) => m[1]);
const report = {
  scope:
    "Local Chrome comparison against the recorded Git baseline builds, identical public .cloud configuration and synthetic API responses; not a test of the live VPS.",
  cases: [],
  failures: [],
  mockedApiRequests: 0,
  blockedExternalRequests: 0,
};
async function serve(directory) {
  const base = path.resolve(directory);
  const server = http.createServer((req, res) => {
    let file = path.resolve(
      base,
      "." + decodeURIComponent(new URL(req.url, "http://local").pathname),
    );
    if (file !== base && !file.startsWith(base + path.sep)) {
      res.writeHead(403).end();
      return;
    }
    if (fs.existsSync(file) && fs.statSync(file).isDirectory())
      file = path.join(file, "index.html");
    if (!fs.existsSync(file)) file = path.join(base, "index.html");
    res.setHeader(
      "Content-Type",
      mime[path.extname(file)] || "application/octet-stream",
    );
    res.setHeader("Cache-Control", "no-store");
    res.end(fs.readFileSync(file));
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  return { server, url: `http://127.0.0.1:${server.address().port}` };
}
function fixture(role) {
  const user = {
    id: `synthetic-${role}`,
    sessionId: "synthetic-session",
    email: `visual-${role}@example.invalid`,
    roleCode: role,
    roles: [role],
    permissions,
  };
  return {
    user,
    accessToken: "synthetic-access-token",
    refreshToken: "synthetic-refresh-token",
    tokenType: "Bearer",
  };
}
async function context(browser, config) {
  const ctx = await browser.newContext({
    viewport: config.viewport,
    deviceScaleFactor: 1,
    colorScheme: config.theme,
    locale: "es-BO",
    timezoneId: "America/La_Paz",
    reducedMotion: "reduce",
  });
  ctx._dociaTraffic = [];
  await ctx.addInitScript(() => {
    window.__dociaCryptoErrors = [];
    const decrypt = SubtleCrypto.prototype.decrypt;
    SubtleCrypto.prototype.decrypt = async function (...args) {
      try {
        return await decrypt.apply(this, args);
      } catch (error) {
        window.__dociaCryptoErrors.push(error.name);
        throw error;
      }
    };
  });
  await ctx.route("**/*", async (route) => {
    const req = route.request(),
      url = new URL(req.url());
    if (url.hostname === "127.0.0.1") return route.continue();
    if (
      url.hostname === "www.gstatic.com" &&
      url.pathname.startsWith("/flutter-canvaskit/")
    ) {
      const relative = url.pathname.replace(
        /^\/flutter-canvaskit\/[^/]+\//,
        "",
      );
      return route.fulfill({
        path: path.join(root, "APP-MVP/build/web/canvaskit", relative),
        contentType: relative.endsWith(".wasm")
          ? "application/wasm"
          : "application/javascript",
      });
    }
    if (url.hostname === "api.doc-ia.cloud") {
      report.mockedApiRequests++;
      ctx._dociaTraffic.push(url.pathname);
      let body = { items: [], total: 0 };
      const session = fixture(config.role || "patient");
      if (/\/auth\/(login|refresh)$/.test(url.pathname)) body = session;
      else if (url.pathname.endsWith("/auth/me")) body = { user: session.user };
      else if (url.pathname.endsWith("/clinical-records/profile"))
        body = {
          patientId: session.user.id,
          allergies: [],
          chronicConditions: [],
          currentMedications: [],
          medicalHistory: [],
          familyHistory: [],
          surgicalHistory: [],
        };
      else if (
        /\/auth\/(registration|password-reset)\/request$/.test(url.pathname)
      )
        body = {
          message: "Solicitud simulada correctamente.",
          developmentToken: "synthetic-visual-token",
        };
      return route.fulfill({
        status: 200,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods":
            "GET, POST, PUT, PATCH, DELETE, OPTIONS",
          "access-control-allow-headers":
            "authorization,content-type,x-request-id,idempotency-key",
        },
        contentType: "application/json",
        body: JSON.stringify(body),
      });
    }
    if (url.hostname === "js.stripe.com")
      return route.fulfill({
        contentType: "application/javascript",
        body: "/* No payments during local visual checks. */",
      });
    if (["fonts.googleapis.com", "fonts.gstatic.com"].includes(url.hostname))
      return route.continue();
    report.blockedExternalRequests++;
    return route.abort();
  });
  return ctx;
}
async function settled(page, app) {
  if (app === "flutter") {
    await page.waitForSelector("flutter-view,flt-glass-pane", {
      timeout: 60000,
    });
    await page.waitForFunction(() => !document.getElementById("docia-splash"), {
      timeout: 30000,
    });
    const placeholder = page.locator("flt-semantics-placeholder");
    if (await placeholder.count())
      await placeholder.evaluate((el) => el.click());
  }
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(1500);
}
async function capture(browser, url, config, side) {
  const ctx = await context(browser, config);
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  try {
    await page.goto(url, { waitUntil: "networkidle", timeout: 60000 });
    await settled(page, config.app);
    if (config.app === "landing") {
      if (config.language === "en") {
        await page.getByRole("button", { name: "EN", exact: true }).click();
        await page.waitForTimeout(650);
      }
      const dark = await page
        .locator("html")
        .evaluate((el) => el.classList.contains("dark"));
      if ((config.theme === "dark") !== dark) {
        await page
          .getByRole("button", { name: "Activar modo oscuro", exact: true })
          .click();
        await page.waitForTimeout(650);
      }
      const webLinks = await page
          .locator('a[href="https://app.doc-ia.cloud"]')
          .count(),
        apkLinks = await page.locator('a[href="/downloads/DocIA.apk"]').count();
      if (!webLinks || !apkLinks)
        throw Error("Missing app/APK download links.");
      if (config.menu) {
        await page
          .getByRole("button", { name: "Abrir menú", exact: true })
          .click();
        await page.waitForTimeout(300);
      }
      await page.evaluate(async () => {
        for (const img of document.images) {
          if (img.loading === "lazy") img.loading = "eager";
        }
        await Promise.all(
          [...document.images].map((img) => img.decode().catch(() => {})),
        );
      });
      const broken = await page
        .locator("img")
        .evaluateAll((imgs) =>
          imgs
            .filter((img) => !img.complete || img.naturalWidth === 0)
            .map((img) => img.getAttribute("src")),
        );
      if (broken.length) throw Error(`Broken images: ${broken.join(", ")}`);
    } else {
      if (config.role) {
        // Compare the established-session UI of both versions. Fresh-key login
        // is checked separately because the baseline has a lazy-key write race.
        if (!config.fresh)
          await page.evaluate(async () => {
            if (!localStorage.getItem("FlutterSecureStorage")) {
              const key = await crypto.subtle.generateKey(
                { name: "AES-GCM", length: 256 },
                true,
                ["encrypt", "decrypt"],
              );
              const raw = new Uint8Array(
                await crypto.subtle.exportKey("raw", key),
              );
              localStorage.setItem(
                "FlutterSecureStorage",
                btoa(String.fromCharCode(...raw)),
              );
            }
          });
        await page
          .getByRole("textbox", { name: "tu@correo.com", exact: true })
          .fill(`visual-${config.role}@example.invalid`);
        await page
          .getByRole("textbox", { name: "••••••••", exact: true })
          .fill("Synthetic-Only-123!");
        await page
          .getByRole("button", { name: "Iniciar sesión", exact: true })
          .click();
        const expected = {
          patient: "/patient",
          doctor_general: "/doctor",
          nurse: "/doctor",
          admin: "/admin",
          operator: "/operations",
        }[config.role];
        await page.waitForURL((u) => u.hash.startsWith("#" + expected), {
          timeout: 20000,
        });
        await page.waitForTimeout(1200);
        const semantics = await page.locator("body").ariaSnapshot();
        if (
          /No se pudo completar|No se pudo conectar|No se pudo cargar|No se pudieron cargar/.test(
            semantics,
          )
        )
          throw Error(
            "The simulated authenticated screen did not load its data.",
          );
        if (!ctx._dociaTraffic.some((url) => !url.includes("/auth/")))
          throw Error(
            "No authenticated data request reached the local fixture.",
          );
        if ((await page.evaluate(() => window.__dociaCryptoErrors)).length)
          throw Error("Session decryption failed.");
      } else if (config.route !== "/login") {
        await page.evaluate((route) => {
          location.hash = route;
        }, config.route);
        await page.waitForTimeout(750);
        if (
          !new URL(page.url()).hash.startsWith("#" + config.route.split("?")[0])
        )
          throw Error("Public route redirected unexpectedly.");
      }
      if (config.validation) {
        await page
          .getByRole("button", { name: "Iniciar sesión", exact: true })
          .click();
        await page
          .getByText("Ingresa tu correo", { exact: true })
          .first()
          .waitFor();
        await page
          .getByText("Ingresa tu contraseña", { exact: true })
          .first()
          .waitFor();
        await page.waitForTimeout(250);
      }
    }
    if (errors.length) throw Error(`Browser errors: ${errors.join(" | ")}`);
    const filename = `${config.id}-${side}.png`,
      file = path.join(out, filename);
    let png;
    if (config.app === "landing" && !config.menu) {
      const height = await page.evaluate(
        () => document.documentElement.scrollHeight,
      );
      const image = new PNG({ width: config.viewport.width, height });
      for (let y = 0; y < height; y += config.viewport.height) {
        const actual = await page.evaluate((y) => {
          document.documentElement.style.setProperty(
            "scroll-behavior",
            "auto",
            "important",
          );
          window.scrollTo({ left: 0, top: y, behavior: "instant" });
          return window.scrollY;
        }, y);
        await page.waitForTimeout(50);
        const offset = y - actual;
        const tile = PNG.sync.read(
          await page.screenshot({
            clip: {
              x: 0,
              y: offset,
              width: config.viewport.width,
              height: Math.min(config.viewport.height - offset, height - y),
            },
            animations: "disabled",
            caret: "hide",
          }),
        );
        PNG.bitblt(tile, image, 0, 0, tile.width, tile.height, 0, y);
      }
      png = PNG.sync.write(image);
      fs.writeFileSync(file, png);
    } else {
      png = await page.screenshot({
        path: file,
        animations: "disabled",
        caret: "hide",
      });
    }
    return {
      png,
      file: filename,
      url: page.url().replace(/http:\/\/127\.0\.0\.1:\d+/, "local"),
      semantics: config.role
        ? await page.locator("body").ariaSnapshot()
        : undefined,
    };
  } finally {
    await ctx.close();
  }
}
async function main() {
  const pixelmatch = (
    await import(
      require("node:url").pathToFileURL(visualRequire.resolve("pixelmatch"))
        .href
    )
  ).default;
  const servers = await Promise.all([
    serve(path.join(root, ".validation/baseline-landing/dist")),
    serve(path.join(root, "Landing/dist")),
    serve(path.join(root, ".validation/baseline-flutter/build/web")),
    serve(path.join(root, "APP-MVP/build/web")),
  ]);
  const browser = await chromium.launch({
    executablePath:
      process.env.DOCIA_CHROME_PATH ||
      "C:/Program Files/Google/Chrome/Application/chrome.exe",
    headless: true,
  });
  try {
    const cases = [];
    for (const viewport of [
      { width: 1440, height: 1000 },
      { width: 390, height: 844 },
    ])
      for (const theme of ["light", "dark"]) {
        for (const language of ["es", "en"]) {
          cases.push({
            app: "landing",
            viewport,
            theme,
            language,
            id: `landing-${viewport.width}-${theme}-${language}`,
          });
          if (viewport.width === 390)
            cases.push({
              app: "landing",
              viewport,
              theme,
              language,
              menu: true,
              id: `landing-menu-${viewport.width}-${theme}-${language}`,
            });
        }
        for (const route of [
          "/login",
          "/register",
          "/password-reset",
          "/register/complete?token=synthetic-visual-token",
          "/password-reset?token=synthetic-visual-token",
        ])
          cases.push({
            app: "flutter",
            viewport,
            theme,
            route,
            id: `flutter-${viewport.width}-${theme}-${route.replace(/\?.*/, "").replaceAll("/", "_")}${route.includes("?") ? "-token" : ""}`,
          });
        cases.push({
          app: "flutter",
          viewport,
          theme,
          route: "/login",
          validation: true,
          id: `flutter-validation-${viewport.width}-${theme}`,
        });
        for (const role of [
          "patient",
          "doctor_general",
          "nurse",
          "admin",
          "operator",
        ])
          cases.push({
            app: "flutter",
            viewport,
            theme,
            role,
            id: `flutter-role-${role}-${viewport.width}-${theme}`,
          });
      }
    const selected = process.env.DOCIA_VISUAL_CASE_ID
      ? cases.filter((config) => config.id === process.env.DOCIA_VISUAL_CASE_ID)
      : process.env.DOCIA_VISUAL_RETRY === "landing"
        ? cases.filter((config) => config.app === "landing")
        : process.env.DOCIA_VISUAL_RETRY === "1"
          ? cases.filter(
              (config) => config.app === "landing" || config.validation,
            )
          : cases;
    if (!selected.length) throw Error("Unknown visual case identifier.");
    if (process.env.DOCIA_VISUAL_RETRY || process.env.DOCIA_VISUAL_CASE_ID) {
      const previous = JSON.parse(
        fs.readFileSync(path.join(root, "docs/VISUAL-REPORT.json"), "utf8"),
      );
      const replaced = new Set(selected.map((config) => config.id));
      report.cases = previous.cases.filter((item) => !replaced.has(item.id));
      report.failures = previous.failures.filter(
        (item) => !replaced.has(item.id),
      );
      report.mockedApiRequests = previous.mockedApiRequests;
      report.blockedExternalRequests = previous.blockedExternalRequests;
    }
    report.browser = browser.version();
    report.capture =
      "Viewport captures for Flutter/menu; scroll-position viewport tiles for long landing pages, exact pixel comparison including antialiasing. Sticky headers are retained in each viewport tile.";
    const firstLogin = await capture(
      browser,
      servers[3].url,
      {
        app: "flutter",
        viewport: { width: 1440, height: 1000 },
        theme: "light",
        role: "admin",
        fresh: true,
        id: "fresh-login",
      },
      "monorepo",
    );
    report.freshLogin = {
      success: true,
      profile: "new browser context without a pre-created encryption key",
      dashboardDataLoaded: true,
      decryptionErrors: 0,
      screenshot: firstLogin.file,
    };
    report.authenticatedComparison =
      "The baseline and monorepo role comparisons use an existing encryption key; the monorepo first-use login is verified separately in a clean context.";
    for (const config of selected) {
      try {
        const offset = config.app === "landing" ? 0 : 2;
        const [before, after] = await Promise.all([
          capture(browser, servers[offset].url, config, "baseline"),
          capture(browser, servers[offset + 1].url, config, "monorepo"),
        ]);
        const a = PNG.sync.read(before.png),
          b = PNG.sync.read(after.png);
        if (a.width !== b.width || a.height !== b.height)
          throw Error("Image dimensions changed.");
        const diff = new PNG({ width: a.width, height: a.height });
        const changed = pixelmatch(
          a.data,
          b.data,
          diff.data,
          a.width,
          a.height,
          { threshold: 0.0, includeAA: true },
        );
        if (changed)
          fs.writeFileSync(
            path.join(out, `${config.id}-diff.png`),
            PNG.sync.write(diff),
          );
        const result = {
          id: config.id,
          width: a.width,
          height: a.height,
          changedPixels: changed,
          totalPixels: a.width * a.height,
          baseline: before.file,
          monorepo: after.file,
        };
        report.cases.push(result);
        if (changed)
          report.failures.push({
            id: config.id,
            error: `${changed} different pixels`,
          });
        if (config.role)
          fs.writeFileSync(
            path.join(out, `${config.id}-semantics.txt`),
            after.semantics,
          );
        console.log(
          `${changed ? "DIFF" : "PASS"} ${config.id}: ${changed} píxeles diferentes.`,
        );
      } catch (error) {
        report.failures.push({ id: config.id, error: error.message });
        console.log(`FAIL ${config.id}: ${error.message}`);
      }
      fs.writeFileSync(
        path.join(root, "docs/VISUAL-REPORT.json"),
        JSON.stringify(report, null, 2) + "\n",
      );
    }
    console.log(
      `RESULTADO: ${report.cases.length} capturas comparadas; ${report.failures.length} incidencias; ${report.mockedApiRequests} solicitudes API simuladas.`,
    );
    require("./write-visual-gallery.cjs").writeGallery(root);
    if (report.failures.length) process.exitCode = 1;
  } finally {
    await browser.close();
    await Promise.all(
      servers.map(({ server }) => new Promise((r) => server.close(r))),
    );
  }
}
main().catch((e) => {
  console.error(e.stack);
  process.exitCode = 1;
});
