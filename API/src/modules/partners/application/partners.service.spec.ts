import { RequestUser } from "../../../common/types/request-user";
import { PartnersRepository } from "../domain/ports/partners.repository";
import { PartnersService } from "./partners.service";

describe("PartnersService", () => {
  const repository = {
    list: jest.fn(),
    resource: jest.fn(),
    createPlan: jest.fn(),
    updatePlan: jest.fn(),
    createSubscription: jest.fn(),
    setPlanBenefit: jest.fn(),
    removePlanBenefit: jest.fn(),
    cancelSubscription: jest.fn(),
    renewSubscription: jest.fn(),
    recordUsage: jest.fn(),
    processSubscriptionLifecycle: jest.fn(),
    createPartner: jest.fn(),
    updatePartner: jest.fn(),
    addDocument: jest.fn(),
    reviewDocument: jest.fn(),
    assignUser: jest.fn(),
    createRequest: jest.fn(),
    confirmRequest: jest.fn(),
    respondRequest: jest.fn(),
    createDiagnosticOrder: jest.fn(),
    completeDiagnosticOrder: jest.fn(),
  } satisfies jest.Mocked<PartnersRepository>;
  const service = new PartnersService(repository);

  beforeEach(() => jest.clearAllMocks());

  it("wraps persisted partner resources in a stable items response", async () => {
    repository.resource.mockResolvedValue([{ id: "request-id" }]);

    await expect(service.resource(user, "partner_requests")).resolves.toEqual({
      items: [{ id: "request-id" }],
    });
    expect(repository.resource).toHaveBeenCalledWith(user, "partner_requests");
  });

  it("delegates the diagnostic result to the assigned partner flow", async () => {
    const input = {
      documentType: "laboratory_result",
      fileUrl: "https://files.jampic.test/result.pdf",
    };
    repository.completeDiagnosticOrder.mockResolvedValue({
      status: "completed",
    });

    await expect(
      service.completeDiagnosticOrder(user, "diagnostic-id", input),
    ).resolves.toEqual({ status: "completed" });
    expect(repository.completeDiagnosticOrder).toHaveBeenCalledWith(
      user,
      "diagnostic-id",
      input,
    );
  });
});

const user: RequestUser = {
  id: "partner-user-id",
  sessionId: "session-id",
  email: "partner@jampic.local",
  roleCode: "health_partner",
  roles: ["health_partner"],
  permissions: ["partners.read", "partners.manage"],
};
