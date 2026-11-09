import { GuidanceService } from "./guidance.service";
describe("Clinical context and consent", () => {
  it("does not read antecedents when clinical rules are disabled even with patient opt-in", async () => {
    const repository = {
      policy: jest
        .fn()
        .mockResolvedValue({
          policy: { rules: [] },
          enabled: false,
          revision: 1,
        }),
      context: jest.fn(),
    };
    const service = new GuidanceService(
      repository as never,
      {} as never,
      {} as never,
    );
    const result = await service.evaluate(
      {} as never,
      "patient",
      "Synthetic text",
      true,
    );
    expect(repository.context).not.toHaveBeenCalled();
    expect(result.contextUsed).toBe(false);
    expect(result.evaluation.classificationStatus).toBe("disabled");
  });
  it("requires consent before allowing the patient to obtain a human support meeting URL", async () => {
    const repository = { joinCall: jest.fn() },
      consents = {
        assertAccepted: jest
          .fn()
          .mockRejectedValue(new Error("consent required")),
      };
    const service = new GuidanceService(
      repository as never,
      {} as never,
      consents as never,
    );
    await expect(
      service.joinCall({ roles: ["patient"] } as never, "call"),
    ).rejects.toThrow("consent required");
    expect(repository.joinCall).not.toHaveBeenCalled();
  });
});
