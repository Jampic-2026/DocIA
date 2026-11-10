// Deploy verified static builds through Netlify's API; never send VPS or Android secrets.
const fs = require("node:fs");
const path = require("node:path");
const { createHash } = require("node:crypto");
const { copyTree } = require("./package.cjs");
const { fromEnvironment, securityHeaders } = require("./public-config.cjs");
const root = path.resolve(__dirname, "..");
const hash = (body, algorithm = "sha256") =>
  createHash(algorithm).update(body).digest("hex");
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const fail = (message) => {
  throw Error(message);
};
const releaseId = (id) => {
  if (!/^[a-f0-9]{40}-[0-9]+-[0-9]+$/.test(id || ""))
    fail("RELEASE_ID inválido.");
  return id;
};
const componentKey = (component) => {
  if (!["web", "landing"].includes(component)) fail("Indicar web o landing.");
  return component === "web" ? "PUBLIC_WEB_URL" : "PUBLIC_LANDING_URL";
};

function rules(sites, component) {
  componentKey(component);
  const headers =
    component === "web"
      ? [
          ...securityHeaders(sites.PUBLIC_API_URL).matchAll(
            /add_header ([\w-]+) "([^"\n]*)" always;/g,
          ),
        ]
          .map((match) => `  ${match[1]}: ${match[2]}`)
          .join("\n")
      : "  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin";
  return {
    _redirects: `/downloads/DocIA_V1.0.1.apk ${sites.PUBLIC_API_URL}/downloads/DocIA.apk 302!\n/downloads/* ${sites.PUBLIC_API_URL}/downloads/:splat 302!\n/* /index.html 200\n`,
    _headers: `/*\n${headers}\n\n/index.html\n  Cache-Control: no-cache, no-store, must-revalidate\n/main.dart.js\n  Cache-Control: no-cache, no-store, must-revalidate\n/flutter_bootstrap.js\n  Cache-Control: no-cache, no-store, must-revalidate\n/flutter_service_worker.js\n  Cache-Control: no-cache, no-store, must-revalidate\n/docia-release.txt\n  Cache-Control: no-cache, no-store, must-revalidate\n`,
  };
}

function filesIn(directory) {
  const result = new Map();
  const visit = (relative = "") => {
    for (const name of fs.readdirSync(path.join(directory, relative)).sort()) {
      if (/[?#\\\s]/.test(name) || name === "." || name === "..")
        fail("Ruta estática inválida.");
      if (
        /^(?:\.env(?:\..*)?|\.git|secrets|node_modules|key\.properties|local\.properties)$/.test(
          name,
        ) ||
        /\.(?:jks|keystore|p12|pfx|key|apk|aab)$/.test(name)
      )
        fail(
          "El sitio contiene un archivo privado o una descarga que debe permanecer en el VPS.",
        );
      const key = relative ? `${relative}/${name}` : name;
      const file = path.join(directory, key);
      const stat = fs.lstatSync(file);
      if (stat.isSymbolicLink()) fail("El sitio no puede incluir enlaces.");
      if (stat.isDirectory()) visit(key);
      else if (stat.isFile()) result.set(key, file);
      else fail("El sitio no puede incluir archivos especiales.");
    }
  };
  visit();
  return result;
}

function stage(component, sites, id, directory = root) {
  componentKey(component);
  releaseId(id);
  const output = path.join(directory, "payload", component);
  if (fs.existsSync(output))
    fail("El directorio estático ya existe; usar un checkout limpio.");
  copyTree(
    path.join(
      directory,
      component === "web" ? "APP-MVP/build/web" : "Landing/dist",
    ),
    output,
    (name) => name === "downloads",
  );
  if (
    !fs.existsSync(path.join(output, "index.html")) ||
    (component === "web" &&
      !fs.existsSync(path.join(output, "flutter_bootstrap.js")))
  )
    fail("Build estático incompleto.");
  fs.writeFileSync(
    path.join(output, "docia-release.txt"),
    `${component}-${id}\n`,
  );
  for (const [name, body] of Object.entries(rules(sites, component)))
    fs.writeFileSync(path.join(output, name), body);
  return output;
}

function client(token, fetcher = fetch) {
  if (!token?.trim() || /[\r\n]/.test(token))
    fail("Falta NETLIFY_AUTH_TOKEN válido.");
  return async (endpoint, method = "GET", body) => {
    let response;
    try {
      response = await fetcher(`https://api.netlify.com/api/v1${endpoint}`, {
        method,
        redirect: "error",
        signal: AbortSignal.timeout(30000),
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": Buffer.isBuffer(body)
            ? "application/octet-stream"
            : "application/json",
        },
        body:
          body === undefined
            ? undefined
            : Buffer.isBuffer(body)
              ? body
              : JSON.stringify(body),
      });
    } catch {
      fail(
        "Netlify: fallo de conexión o timeout; no se imprimió la respuesta privada.",
      );
    }
    if (!response.ok) {
      const hints = {
        401: "revisar NETLIFY_AUTH_TOKEN",
        403: "revisar permisos y plan",
        404: "revisar los IDs de los sitios",
        422: "revisar configuración, cuota y estado del sitio",
        429: "límite de solicitudes o cuota; reintentar más tarde",
      };
      fail(
        `Netlify HTTP ${response.status}: ${hints[response.status] || "operación rechazada; revisar el panel de Netlify"}.`,
      );
    }
    if (response.status === 204) return {};
    try {
      return await response.json();
    } catch {
      fail("Netlify devolvió una respuesta no válida.");
    }
  };
}

function settings(env) {
  const ids = [env.NETLIFY_WEB_SITE_ID, env.NETLIFY_LANDING_SITE_ID];
  if (
    ids.some(
      (id) =>
        !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(
          id || "",
        ),
    ) ||
    ids[0] === ids[1]
  )
    fail(
      "Configurar dos Project IDs distintos: NETLIFY_WEB_SITE_ID y NETLIFY_LANDING_SITE_ID.",
    );
  return { web: ids[0], landing: ids[1] };
}

async function preflight(api, ids, sites) {
  const result = {};
  for (const component of ["web", "landing"]) {
    const site = await api(`/sites/${ids[component]}`);
    if (
      site.id !== ids[component] ||
      site.ssl_url !== sites[componentKey(component)]
    )
      fail(
        `Netlify ${component}: su URL HTTPS no coincide con config/environments/production.env.`,
      );
    if (site.build_settings?.repo_url)
      fail(
        `Netlify ${component}: desconectar el build Git; GitHub Actions publica los artefactos verificados.`,
      );
    if (site.published_deploy?.locked)
      fail(
        `Netlify ${component}: desbloquear la publicación en el panel antes de desplegar.`,
      );
    if (!site.published_deploy?.id)
      fail(
        `Netlify ${component}: publicar primero una página inicial desde Deploy manually para disponer de una versión de recuperación.`,
      );
    deployId(site.published_deploy.id);
    result[component] = site;
  }
  return result;
}

function deployId(value) {
  if (!/^[a-zA-Z0-9-]{1,80}$/.test(value || ""))
    fail("Netlify devolvió un ID de deploy inválido.");
  return value;
}
function draftOrigin(value, siteOrigin) {
  let url;
  try {
    url = new URL(value);
  } catch {
    fail("Netlify no devolvió la URL HTTPS del borrador.");
  }
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    url.pathname !== "/" ||
    url.port ||
    !/^[a-zA-Z0-9-]+--[a-zA-Z0-9-]+\.netlify\.app$/.test(url.hostname) ||
    url.origin === siteOrigin
  )
    fail("Netlify devolvió una URL de borrador inesperada.");
  return url.origin;
}

async function verify(
  origin,
  component,
  directory,
  id,
  fetcher = fetch,
  phase = "público",
) {
  const files = filesIn(directory);
  const probes = [
    "docia-release.txt",
    "index.html",
    ...(component === "web"
      ? ["flutter_bootstrap.js", "main.dart.js"]
      : [...files.keys()].filter((name) =>
          /^assets\/.*\.(js|css)$/.test(name),
        )),
  ];
  for (const name of probes) {
    const file = files.get(name);
    if (!file) fail(`${component}: falta un recurso obligatorio del sitio.`);
    let response, body;
    try {
      response = await fetcher(
        `${origin}/${name}?deployment=${releaseId(id)}`,
        { redirect: "manual", signal: AbortSignal.timeout(30000) },
      );
      if (response.ok) body = Buffer.from(await response.arrayBuffer());
    } catch {
      fail(
        `${component} (${phase}): no se pudo comprobar ${origin}/${name} por HTTPS.`,
      );
    }
    if (!response.ok) {
      const hint = [301, 302, 303, 307, 308, 401, 403].includes(response.status)
        ? "Revisar visibilidad de producción y previews, contraseña, login y reglas de acceso de Netlify."
        : response.status === 404
          ? "El recurso no está disponible; revisar los archivos del deploy en Netlify."
          : "Revisar el estado del deploy y las reglas de acceso en Netlify.";
      fail(
        `${component} (${phase}): HTTP ${response.status} en ${origin}/${name}. ${hint}`,
      );
    }
    if (hash(body) !== hash(fs.readFileSync(file))) {
      const html = /^\s*</.test(body.subarray(0, 512).toString("utf8"));
      const hint =
        name === "docia-release.txt" && html
          ? "Se recibió HTML en lugar del marcador; revisar login/protección de previews y reglas SPA."
          : name === "docia-release.txt"
            ? "El marcador recibido tiene bytes diferentes; revisar la versión y los archivos del deploy."
            : "Revisar transformaciones, snippets y los archivos del deploy.";
      fail(
        `${component} (${phase}): HTTP ${response.status}, el contenido de ${origin}/${name} no coincide con la release. ${hint} No se imprime el cuerpo recibido.`,
      );
    }
  }
}

async function publish(
  component,
  api,
  ids,
  sites,
  id,
  directory = root,
  { fetcher = fetch, sleep = pause, attempts = 30 } = {},
) {
  componentKey(component);
  releaseId(id);
  const prepared = path.join(directory, "payload", component);
  const files = filesIn(prepared),
    digests = {},
    byDigest = new Map();
  if (
    fs.readFileSync(path.join(prepared, "docia-release.txt"), "utf8").trim() !==
    `${component}-${id}`
  )
    fail("El sitio pertenece a otra release.");
  for (const [name, file] of files) {
    const digest = hash(fs.readFileSync(file), "sha1");
    digests[`/${name}`] = digest;
    byDigest.set(digest, { name, file });
  }
  const site = (await preflight(api, ids, sites))[component];
  const previous = site.published_deploy?.id
    ? deployId(site.published_deploy.id)
    : undefined;
  let created = await api(`/sites/${ids[component]}/deploys`, "POST", {
    files: digests,
    draft: true,
    async: true,
    title: `${component}-${id}`,
  });
  const current = deployId(created.id);
  const wait = async (predicate) => {
    for (let attempt = 0; attempt < attempts; attempt++) {
      created = await api(`/deploys/${current}`);
      if (created.state === "error")
        fail(
          `Netlify ${component}: falló el procesamiento; revisar el deploy en el panel.`,
        );
      if (predicate(created)) return;
      await sleep(2000);
    }
    fail(
      `Netlify ${component}: timeout esperando el procesamiento del deploy.`,
    );
  };
  await wait((data) =>
    ["prepared", "uploading", "uploaded", "processing", "ready"].includes(
      data.state,
    ),
  );
  for (const digest of created.required || []) {
    const file = byDigest.get(digest);
    if (!file) fail("Netlify solicitó un archivo ajeno al build.");
    await api(
      `/deploys/${current}/files/${file.name.split("/").map(encodeURIComponent).join("/")}`,
      "PUT",
      fs.readFileSync(file.file),
    );
  }
  await wait((data) => data.state === "ready");
  const preview = draftOrigin(
    created.deploy_ssl_url,
    sites[componentKey(component)],
  );
  console.log(`[DocIA] Netlify ${component}: verificando borrador ${preview}.`);
  await verify(preview, component, prepared, id, fetcher, "borrador");
  const latest = await api(`/sites/${ids[component]}`);
  if ((latest.published_deploy?.id || undefined) !== previous)
    fail(
      `Netlify ${component}: otra publicación cambió el sitio; reejecutar Actions.`,
    );
  try {
    await api(`/sites/${ids[component]}/deploys/${current}/restore`, "POST");
    let healthy = false;
    let lastError;
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        await verify(
          sites[componentKey(component)],
          component,
          prepared,
          id,
          fetcher,
        );
        healthy = true;
        break;
      } catch (error) {
        lastError = error;
        await sleep(2000);
      }
    }
    if (!healthy)
      fail(
        `Netlify ${component}: falló la salud de la URL pública. ${lastError.message}`,
      );
  } catch (error) {
    const latest = await api(`/sites/${ids[component]}`);
    if (latest.published_deploy?.id === current) {
      await api(`/sites/${ids[component]}/deploys/${previous}/restore`, "POST");
    }
    throw error;
  }
}

module.exports = { stage, rules, client, settings, preflight, publish, verify };
if (require.main === module) {
  (async () => {
    const sites = fromEnvironment(true),
      command = process.argv[2],
      component = process.argv[3];
    if (command === "stage") stage(component, sites, process.env.RELEASE_ID);
    else {
      const ids = settings(process.env),
        api = client(process.env.NETLIFY_AUTH_TOKEN);
      if (command === "preflight") await preflight(api, ids, sites);
      else if (command === "publish")
        await publish(component, api, ids, sites, process.env.RELEASE_ID);
      else
        fail("Uso: netlify-deploy.cjs stage|publish web|landing, o preflight.");
    }
    console.log(
      `[DocIA] Netlify ${command}${component ? ` ${component}` : ""}: OK.`,
    );
  })().catch((error) => {
    console.error(
      error.code || !(error instanceof Error)
        ? "[DocIA] No se pudo preparar o publicar el sitio estático."
        : `[DocIA] ${error.message}`,
    );
    process.exitCode = 1;
  });
}
