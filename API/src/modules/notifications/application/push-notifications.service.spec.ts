import { PushNotificationsService } from "./push-notifications.service";
import { PushProvider, PushRepository } from "../domain/ports/push";

describe("Push delivery retries", () => {
  function setup() {
    const repository: jest.Mocked<PushRepository> = {
      claim: jest.fn().mockResolvedValue([
        {
          notificationId: "synthetic-event",
          userId: "synthetic-user",
          eventCode: "emergencies",
          title: "Synthetic",
          body: "Synthetic",
        },
      ]),
      patientUserId: jest.fn(),
      activeTokensForUser: jest.fn().mockResolvedValue(["synthetic-token"]),
      deactivateTokens: jest.fn(),
      complete: jest.fn(),
      fail: jest.fn(),
    };
    const provider: PushProvider = { enabled: true, send: jest.fn() };
    const service = new PushNotificationsService(repository, provider);
    const process = () =>
      (
        service as unknown as { processOutbox(): Promise<void> }
      ).processOutbox();
    return { repository, provider, process };
  }
  it("keeps transient provider failures retryable rather than marking them delivered", async () => {
    const { repository, provider, process } = setup();
    jest
      .spyOn(provider, "send")
      .mockResolvedValue({ invalidTokens: [], transientFailures: 1 });
    await process();
    expect(repository.complete).not.toHaveBeenCalled();
    expect(repository.fail).toHaveBeenCalledWith(
      "synthetic-event",
      expect.any(String),
    );
  });
  it("retires permanently invalid tokens and completes the processed outbox entry", async () => {
    const { repository, provider, process } = setup();
    jest.spyOn(provider, "send").mockResolvedValue({
      invalidTokens: ["synthetic-token"],
      transientFailures: 0,
    });
    await process();
    expect(repository.deactivateTokens).toHaveBeenCalledWith("synthetic-user", [
      "synthetic-token",
    ]);
    expect(repository.complete).toHaveBeenCalledWith("synthetic-event");
    expect(repository.fail).not.toHaveBeenCalled();
  });
});
