import { ConfigService } from "@nestjs/config";
import { GoogleMeetProvider } from "./google-meet.provider";

describe("Meet direct entry", () => {
  function setup() {
    const provider = new GoogleMeetProvider(
      new ConfigService({
        telemedicine: {
          enabled: true,
          google: {
            clientId: "synthetic",
            clientSecret: "synthetic",
            redirectUri: "https://example.invalid/callback",
          },
        },
      }),
      {} as never,
    );
    const internals = provider as unknown as {
      validAccessToken(): Promise<string>;
      googleRequest(url: string, init: RequestInit): Promise<Response>;
    };
    jest.spyOn(internals, "validAccessToken").mockResolvedValue("synthetic");
    const request = jest
      .spyOn(internals, "googleRequest")
      .mockResolvedValue(
        new Response(
          JSON.stringify({
            name: "spaces/synthetic",
            meetingUri: "https://meet.google.com/synthetic",
          }),
          { status: 200 },
        ),
      );
    return { provider, request };
  }
  it("creates rooms with direct entry through the Meet link", async () => {
    const { provider, request } = setup();
    await provider.createSpace();
    const [, init] = request.mock.calls[0];
    expect(init.method).toBe("POST");
    expect(JSON.parse(String(init.body))).toEqual({
      config: { accessType: "OPEN", entryPointAccess: "ALL" },
    });
  });
  it("updates existing rooms using a mask limited to entry configuration", async () => {
    const { provider, request } = setup();
    await provider.allowDirectJoin("spaces/synthetic");
    expect(request.mock.calls[0][0]).toBe(
      "https://meet.googleapis.com/v2/spaces/synthetic?updateMask=config.accessType,config.entryPointAccess",
    );
    expect(request.mock.calls[0][1].method).toBe("PATCH");
  });
  it("rejects invalid space names before requesting Google", async () => {
    const { provider, request } = setup();
    await expect(
      provider.allowDirectJoin("https://example.invalid"),
    ).rejects.toThrow("Identificador");
    expect(request).not.toHaveBeenCalled();
  });
  it("does not report success when Google rejects the configuration", async () => {
    const { provider, request } = setup();
    request.mockResolvedValue(new Response("{}", { status: 403 }));
    await expect(provider.allowDirectJoin("spaces/synthetic")).rejects.toThrow(
      "no pudo habilitar",
    );
  });
});
