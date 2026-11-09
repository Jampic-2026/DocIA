import { ServiceUnavailableException } from "@nestjs/common";
import { DatabaseService } from "../../../../database/database.service";
import { AppHealthController } from "./app-health.controller";

describe("AppHealthController readiness", () => {
  const checkHealth = jest.fn();
  const controller = new AppHealthController({
    checkHealth,
  } as unknown as DatabaseService);

  afterEach(() => {
    jest.resetAllMocks();
  });

  it("checks PostgreSQL before reporting the deployed version", async () => {
    checkHealth.mockResolvedValue(undefined);
    await expect(controller.ready()).resolves.toEqual({
      status: "ok",
      service: "api-docia",
      release: process.env.DOCIA_RELEASE ?? "development",
    });
    expect(checkHealth).toHaveBeenCalledTimes(1);
  });

  it("returns 503 without exposing a database error", async () => {
    checkHealth.mockRejectedValue(new Error("postgresql://user:private@host/db"));
    try {
      await controller.ready();
      throw new Error("Readiness should have failed");
    } catch (error) {
      expect(error).toBeInstanceOf(ServiceUnavailableException);
      const unavailable = error as ServiceUnavailableException;
      expect(unavailable.getStatus()).toBe(503);
      expect(JSON.stringify(unavailable.getResponse())).not.toContain("private");
      expect(unavailable.message).toBe("Servicio no disponible");
    }
  });
});
