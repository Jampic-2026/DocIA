import { ConfigService } from "@nestjs/config";
import { PaymentsService } from "./payments.service";
import { PaymentsRepository } from "../domain/ports/payments.repository";
import { StripePaymentsProvider } from "../infrastructure/stripe/stripe-payments.provider";
import { PushNotificationsService } from "../../notifications/application/push-notifications.service";
import { RequestUser } from "../../../common/types/request-user";

describe("Stripe checkout return URL", () => {
  it("uses the configured domain rather than falling back to localhost", async () => {
    const repository = {
      createCardPayment: jest
        .fn()
        .mockResolvedValue({
          paymentId: "payment",
          amount: "10",
          currency: "BOB",
          concept: "test",
        }),
    };
    const stripe = {
      assertConfigured: jest.fn(),
      createCheckoutSession: jest
        .fn()
        .mockResolvedValue({
          id: "session",
          url: "https://checkout.stripe.com/example",
        }),
    };
    const url = "https://app.example.com/#/payments/return";
    const service = new PaymentsService(
      repository as unknown as PaymentsRepository,
      stripe as unknown as StripePaymentsProvider,
      new ConfigService({ stripe: { paymentReturnUrl: url } }),
      {} as PushNotificationsService,
    );
    const user: RequestUser = {
      id: "user",
      sessionId: "session",
      email: "user@example.com",
      roleCode: "PATIENT",
      roles: [],
      permissions: [],
    };
    await service.createStripeCheckoutSession(user, "order", {
      idempotencyKey: "request",
    });
    expect(stripe.createCheckoutSession).toHaveBeenCalledWith(
      expect.objectContaining({ returnUrl: url }),
      "request",
    );
  });
});
