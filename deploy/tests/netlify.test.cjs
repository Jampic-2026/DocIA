const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const {
  stage,
  rules,
  client,
  settings,
  preflight,
  publish,
} = require("../netlify-deploy.cjs");
const { render } = require("../public-config.cjs");
const sites = {
  PUBLIC_API_URL: "https://docia-api.duckdns.org",
  PUBLIC_WEB_URL: "https://docia-app.netlify.app",
  PUBLIC_LANDING_URL: "https://docia.netlify.app",
  API_PREFIX: "api/v1",
};
const id = "a".repeat(40) + "-1-1";
const ids = {
  web: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  landing: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
};

function fixture(t, component = "web") {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), "docia-netlify-test-"),
  );
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const output = path.join(
    directory,
    component === "web" ? "APP-MVP/build/web" : "Landing/dist",
  );
  fs.mkdirSync(path.join(output, "assets"), { recursive: true });
  fs.writeFileSync(
    path.join(output, "index.html"),
    '<script src="/assets/app.js"></script>',
  );
  fs.writeFileSync(path.join(output, "assets/app.js"), "const app = true;");
  if (component === "web")
    for (const name of ["main.dart.js", "flutter_bootstrap.js"])
      fs.writeFileSync(path.join(output, name), "flutter;");
  return {
    directory,
    output,
    prepared: () => stage(component, sites, id, directory),
  };
}

test("both Netlify builds redirect APK requests to the VPS, preserve SPA routing and web security headers", () => {
  for (const component of ["web", "landing"]) {
    const output = rules(sites, component);
    assert.match(
      output._redirects,
      /https:\/\/docia-api.duckdns.org\/downloads\/:splat 302!/,
    );
    assert.match(output._redirects, /\/\* \/index.html 200/);
    assert.match(output._headers, /Cache-Control: no-cache, no-store/);
    if (component === "web")
      assert.match(
        output._headers,
        /connect-src 'self' https:\/\/docia-api.duckdns.org /,
      );
  }
});
test("API-only renderer never creates Netlify virtual hosts and serves APK from the isolated release", (t) => {
  const { directory } = fixture(t);
  render(sites, directory, { apiOnly: true });
  assert.equal(fs.existsSync(path.join(directory, "docia-web.conf")), false);
  assert.equal(
    fs.existsSync(path.join(directory, "docia-landing.conf")),
    false,
  );
  const nginx = fs.readFileSync(path.join(directory, "docia-api.conf"), "utf8");
  assert.match(nginx, /proxy_pass http:\/\/127.0.0.1:3200;/);
  assert.match(
    nginx,
    /alias \/var\/www\/docia\/monorepo\/deploy\/current-web\/web\/downloads\/DocIA.apk;/,
  );
  const bootstrap = fs.readFileSync(
    path.join(directory, "docia-http-bootstrap.conf"),
    "utf8",
  );
  assert.doesNotMatch(bootstrap, /netlify.app|doc-ia.cloud/);
});
test("staging excludes APKs and stamps the exact build without changing its UI assets", (t) => {
  const { output, prepared } = fixture(t);
  fs.mkdirSync(path.join(output, "downloads"));
  fs.writeFileSync(path.join(output, "downloads/old.apk"), "old");
  const result = prepared();
  assert.equal(fs.existsSync(path.join(result, "downloads")), false);
  assert.equal(
    fs.readFileSync(path.join(result, "docia-release.txt"), "utf8"),
    `web-${id}\n`,
  );
  assert.equal(
    fs.readFileSync(path.join(result, "assets/app.js"), "utf8"),
    fs.readFileSync(path.join(output, "assets/app.js"), "utf8"),
  );
  assert.throws(prepared, /ya existe/);
});
test("private files inside static output block staging", (t) => {
  const { output, prepared } = fixture(t);
  fs.writeFileSync(path.join(output, ".env"), "synthetic-private-value");
  assert.throws(prepared, /privado/);
});
test("requires distinct Project IDs instead of site names or URLs", () => {
  assert.deepEqual(
    settings({
      NETLIFY_WEB_SITE_ID: ids.web,
      NETLIFY_LANDING_SITE_ID: ids.landing,
    }),
    ids,
  );
  for (const value of [ids.web, "https://docia.netlify.app", "../escape"])
    assert.throws(
      () =>
        settings({
          NETLIFY_WEB_SITE_ID: ids.web,
          NETLIFY_LANDING_SITE_ID: value,
        }),
      /Project IDs/,
    );
});
test("API errors and transport errors never disclose tokens or provider responses", async () => {
  for (const status of [401, 403, 404, 422, 429, 500]) {
    const api = client("synthetic-private-token", async (url, options) => {
      assert.equal(options.redirect, "error");
      assert.equal(
        options.headers.Authorization,
        "Bearer synthetic-private-token",
      );
      return new Response("synthetic-private-response", { status });
    });
    await assert.rejects(
      api("/sites/site"),
      (error) =>
        error.message.includes(`HTTP ${status}`) &&
        !error.message.includes("synthetic-private"),
    );
  }
  await assert.rejects(
    client("synthetic-private-token", async () => {
      throw Error("synthetic-private-token");
    })("/sites/site"),
    /timeout/,
  );
});
test("preflight rejects wrong URLs and Git-connected projects before publishing", async () => {
  for (const mode of ["url", "git", "locked"]) {
    await assert.rejects(
      preflight(
        async () => ({
          id: ids.web,
          ssl_url:
            mode === "url" ? "https://other.netlify.app" : sites.PUBLIC_WEB_URL,
          build_settings:
            mode === "git" ? { repo_url: "git@github.com:org/repo" } : {},
          published_deploy: { locked: mode === "locked" },
        }),
        ids,
        sites,
      ),
      /coincide|desconectar|desbloquear/,
    );
  }
});

function service(directory, component, mode) {
  const calls = [],
    uploads = [],
    current = {
      value: mode === "first-failure" ? undefined : "previous-deploy",
    };
  const site = (name) => ({
    id: ids[name],
    ssl_url: sites[name === "web" ? "PUBLIC_WEB_URL" : "PUBLIC_LANDING_URL"],
    published_deploy: current.value ? { id: current.value } : null,
  });
  const api = async (endpoint, method = "GET", body) => {
    calls.push({ endpoint, method, body });
    if (method === "GET" && endpoint.startsWith("/sites/"))
      return site(endpoint.endsWith(ids.web) ? "web" : "landing");
    if (method === "POST" && endpoint.endsWith("/deploys")) {
      assert.equal(body.draft, true);
      assert.equal(body.async, true);
      return { id: "new-deploy" };
    }
    if (method === "GET" && endpoint === "/deploys/new-deploy")
      return {
        id: "new-deploy",
        state:
          mode === "processing-error"
            ? "error"
            : mode === "timeout"
              ? "preparing"
              : uploads.length
                ? "ready"
                : "prepared",
        required: uploads.length
          ? []
          : Object.values(calls.find((call) => call.body?.files).body.files),
        deploy_ssl_url: "https://new-deploy--docia.netlify.app",
      };
    if (method === "PUT") {
      uploads.push(endpoint);
      return {};
    }
    if (method === "POST" && endpoint.endsWith("/restore")) {
      current.value = endpoint.split("/").at(-2);
      return {};
    }
    throw Error(`Unexpected mock API request: ${method} ${endpoint}`);
  };
  const fetcher = async (address) => {
    const url = new URL(address),
      draft = url.hostname.startsWith("new-deploy--");
    if (
      (mode === "draft-failure" && draft) ||
      (["public-failure", "first-failure"].includes(mode) && !draft)
    )
      return new Response("wrong release", { status: 200 });
    const file = path.join(
      directory,
      "payload",
      component,
      url.pathname.slice(1),
    );
    return new Response(fs.readFileSync(file));
  };
  return { api, fetcher, calls, current };
}
for (const component of ["web", "landing"])
  test(`publishes ${component} only after verifying the draft and all mandatory assets`, async (t) => {
    const { directory, prepared } = fixture(t, component);
    prepared();
    const mock = service(directory, component);
    await publish(component, mock.api, ids, sites, id, directory, {
      fetcher: mock.fetcher,
      sleep: async () => {},
      attempts: 2,
    });
    assert.equal(mock.current.value, "new-deploy");
    assert.equal(
      mock.calls.filter((call) => call.endpoint.endsWith("/restore")).length,
      1,
    );
  });
for (const mode of [
  "draft-failure",
  "public-failure",
  "first-failure",
  "processing-error",
  "timeout",
])
  test(`handles ${mode} without leaving an unhealthy publication active`, async (t) => {
    const { directory, prepared } = fixture(t);
    prepared();
    const mock = service(directory, "web", mode);
    await assert.rejects(
      publish("web", mock.api, ids, sites, id, directory, {
        fetcher: mock.fetcher,
        sleep: async () => {},
        attempts: 2,
      }),
    );
    assert.equal(
      mock.current.value,
      mode === "first-failure" ? undefined : "previous-deploy",
    );
    if (["draft-failure", "processing-error", "timeout"].includes(mode))
      assert.equal(
        mock.calls.some((call) => call.endpoint.endsWith("/restore")),
        false,
      );
  });
