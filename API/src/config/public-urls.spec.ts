import { appendWebQuery, resolvePublicUrls } from "./public-urls";

describe("domain configuration", () => {
  it("derives CORS, mail, payments and OAuth URLs from the two origins", () => {
    const urls = resolvePublicUrls({
      PUBLIC_API_URL: "https://api.example.com/",
      PUBLIC_WEB_URL: "https://app.example.com/",
      API_PREFIX: "/api/v2/",
    });
    expect(urls.CORS_ORIGINS).toBe("https://app.example.com");
    expect(urls.PASSWORD_RESET_URL).toBe(
      "https://app.example.com/#/password-reset",
    );
    expect(urls.REGISTRATION_URL).toBe(
      "https://app.example.com/#/register/complete",
    );
    expect(urls.STRIPE_PAYMENT_RETURN_URL).toBe(
      "https://app.example.com/#/payments/return",
    );
    expect(urls.GOOGLE_OAUTH_REDIRECT_URI).toBe(
      "https://api.example.com/api/v2/integrations/google/callback",
    );
  });

  it("updates all derived URLs when migrating from DuckDNS to an owned domain", () => {
    const first = resolvePublicUrls({
      PUBLIC_API_URL: "https://next-api.duckdns.org",
      PUBLIC_WEB_URL: "https://next-app.duckdns.org",
    });
    const next = resolvePublicUrls({
      PUBLIC_API_URL: "https://api.example.com",
      PUBLIC_WEB_URL: "https://app.example.com",
    });
    expect(first.REGISTRATION_URL).toContain("next-app.duckdns.org");
    expect(JSON.stringify(next)).not.toContain("duckdns.org");
    expect(next.GOOGLE_OAUTH_REDIRECT_URI).toContain(
      "https://api.example.com/",
    );
  });

  it("supports path routing and explicit third-party or migration overrides", () => {
    const urls = resolvePublicUrls({
      PUBLIC_WEB_URL: "https://app.example.com",
      WEB_ROUTING_MODE: "path",
      CORS_ORIGINS: "https://old.example.com,https://app.example.com",
      PASSWORD_RESET_URL: "https://special.example.com/reset",
    });
    expect(urls.CORS_ORIGINS).toBe(
      "https://app.example.com,https://old.example.com",
    );
    expect(urls.PASSWORD_RESET_URL).toBe("https://special.example.com/reset");
    expect(urls.REGISTRATION_URL).toBe(
      "https://app.example.com/register/complete",
    );
  });

  it.each(["password-reset", "register/complete"])(
    "places tokens inside the hash route for %s",
    (route) => {
      const result = new URL(
        appendWebQuery(`https://app.example.com/#/${route}?lang=es`, {
          token: "a+b/=test",
        }),
      );
      expect(result.search).toBe("");
      const parsedRoute = new URL(result.hash.slice(1), result.origin);
      expect(parsedRoute.pathname).toBe(`/${route}`);
      expect(parsedRoute.searchParams.get("token")).toBe("a+b/=test");
      expect(parsedRoute.searchParams.get("lang")).toBe("es");
    },
  );

  it("retains normal query parameters for path routes", () => {
    const url = new URL(
      appendWebQuery("https://app.example.com/password-reset?lang=es", {
        token: "safe-token",
      }),
    );
    expect(url.searchParams.get("token")).toBe("safe-token");
    expect(url.searchParams.get("lang")).toBe("es");
  });
});
