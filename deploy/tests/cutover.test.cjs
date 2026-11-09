const { test } = require("node:test");
const assert = require("node:assert/strict");
const { transform } = require("../cutover.cjs");
test("API only changes upstream port and keeps TLS and routes", () =>
  assert.equal(
    transform(
      "location / { proxy_pass http://127.0.0.1:3000/api/; } ssl_certificate /old.pem;",
      "api",
    ),
    "location / { proxy_pass http://127.0.0.1:3100/api/; } ssl_certificate /old.pem;",
  ));
test("web supports legacy checkout and release paths", () => {
  for (const from of [
    "/var/www/docia/web/build/web",
    "/var/www/docia/deploy/current-web/web",
  ])
    assert.equal(
      transform(`root ${from};`, "web"),
      "root /var/www/docia-monorepo/deploy/current-web/web;",
    );
});
test("landing switches both static root and APK alias", () =>
  assert.equal(
    transform(
      "root /var/www/docia/deploy/current-landing/landing; alias /var/www/docia/deploy/current-web/web/downloads/;",
      "landing",
    ),
    "root /var/www/docia-monorepo/deploy/current-landing/landing; alias /var/www/docia-monorepo/deploy/current-web/web/downloads/;",
  ));
test("unexpected upstream or root requires review", () => {
  assert.throws(() => transform("proxy_pass http://other:8000;", "api"));
  assert.throws(() => transform("root /var/www/other;", "landing"));
});
