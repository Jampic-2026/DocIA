import { RequestUser } from "../../../common/types/request-user";
import { BenefitsRepository } from "../domain/ports/benefits.repository";
import { BenefitsService } from "./benefits.service";

describe("BenefitsService", () => {
  const repository: jest.Mocked<BenefitsRepository> = {
    list: jest.fn(),
    listUsages: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    apply: jest.fn(),
    validations: jest.fn(),
    validate: jest.fn(),
    setPartner: jest.fn(),
    reverse: jest.fn(),
  };
  const service = new BenefitsService(repository);

  beforeEach(() => jest.clearAllMocks());

  it("returns the benefits available to the current user", async () => {
    repository.list.mockResolvedValue([
      {
        id: "benefit-id",
        code: "WELCOME10",
        name: "Bienvenida",
        description: "Descuento inicial",
        discountPercent: "10.00",
        discountAmount: "0.00",
        discountCoinAmount: "0",
        benefitType: "discount",
        maxUsesPerUser: 1,
        isStackable: false,
        validFrom: null,
        validUntil: null,
        conditions: {},
        usedCount: 0,
        available: true,
        partnerNames: [],
      },
    ]);

    await expect(service.list(user)).resolves.toEqual({
      items: [expect.objectContaining({ code: "WELCOME10" })],
    });
    expect(repository.list).toHaveBeenCalledWith(user);
  });

  it("delegates benefit validation with the authenticated actor", async () => {
    repository.validate.mockResolvedValue({ status: "approved" });

    await expect(
      service.validate(user, "validation-id", { status: "approved" }),
    ).resolves.toEqual({ status: "approved" });
    expect(repository.validate).toHaveBeenCalledWith(user, "validation-id", {
      status: "approved",
    });
  });
});

const user: RequestUser = {
  id: "user-id",
  sessionId: "session-id",
  email: "patient@jampic.local",
  roleCode: "patient",
  roles: ["patient"],
  permissions: ["benefits.read"],
};
