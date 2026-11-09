import { TelemedicineService } from "./telemedicine.service";
describe("Automatic telemedicine room provisioning", () => {
  it("keeps failed provider jobs pending and completes only successful work", async () => {
    const repository = {
      claimRoomJobs: jest.fn().mockResolvedValue([
        { appointmentId: "failed", requestedBy: "booker" },
        { appointmentId: "ok", requestedBy: "booker" },
      ]),
      createRoom: jest
        .fn()
        .mockRejectedValueOnce(new Error("provider down"))
        .mockResolvedValueOnce({ id: "room" }),
      completeRoomJob: jest.fn(),
      failRoomJob: jest.fn(),
    };
    const service = new TelemedicineService(
      repository as never,
      {} as never,
      {} as never,
    );
    await service.processRoomJobs();
    expect(repository.createRoom).toHaveBeenCalledTimes(2);
    expect(repository.completeRoomJob).toHaveBeenCalledTimes(1);
    expect(repository.completeRoomJob).toHaveBeenCalledWith("ok");
    expect(repository.failRoomJob).toHaveBeenCalledWith("failed");
  });
  it("requires patient telemedicine consent before recording an entry", async () => {
    const repository = { registerJoin: jest.fn() },
      consents = {
        assertAccepted: jest
          .fn()
          .mockRejectedValue(new Error("consent absent")),
      };
    const service = new TelemedicineService(
      repository as never,
      consents as never,
      {} as never,
    );
    await expect(
      service.registerJoin({ roles: ["patient"] } as never, "room"),
    ).rejects.toThrow("consent absent");
    expect(repository.registerJoin).not.toHaveBeenCalled();
  });
});
