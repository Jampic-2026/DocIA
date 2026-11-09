import { PostgresGuidanceRepository } from "./postgres-guidance.repository";

describe("Authorized access to an existing support Meet room", () => {
  for (const authorized of [true, false]) {
    it(
      authorized
        ? "configures direct entry before returning the URL"
        : "does not change Google access for an unauthorized caller",
      async () => {
        const query = jest
          .fn()
          .mockResolvedValueOnce({
            rows: authorized
              ? [
                  {
                    meetingUrl: "https://meet.google.com/synthetic",
                    spaceName: "spaces/synthetic",
                  },
                ]
              : [],
          })
          .mockResolvedValue({ rows: [] });
        const repository = new PostgresGuidanceRepository({
          transactionAsUser: (_: unknown, work: (client: unknown) => unknown) =>
            work({ query }),
        } as never);
        const meet = {
          allowDirectJoin: jest.fn().mockResolvedValue(undefined),
        };
        const result = repository.joinCall(
          { id: "synthetic" } as never,
          "call",
          meet as never,
        );
        if (authorized) {
          await expect(result).resolves.toEqual({
            meetingUrl: "https://meet.google.com/synthetic",
          });
          expect(meet.allowDirectJoin).toHaveBeenCalledWith("spaces/synthetic");
        } else {
          await expect(result).rejects.toThrow("no disponible");
          expect(meet.allowDirectJoin).not.toHaveBeenCalled();
        }
      },
    );
  }
});
