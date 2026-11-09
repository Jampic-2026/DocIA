import {
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RequestUser } from "../../../common/types/request-user";
import {
  PAYMENTS_REPOSITORY,
  PaymentsRepository,
} from "../domain/ports/payments.repository";
import {
  AcceptPaymentOrderDto,
  CreateStripePaymentIntentDto,
  CreatePaymentOrderDto,
  ConfirmInPersonPaymentDto,
  RegisterInPersonPaymentDto,
  ReportPaymentIncidentDto,
  ResolvePaymentIncidentDto,
  ReviewPaymentDto,
  SubmitPaymentDto,
} from "../interfaces/http/dto/payment-commands.dto";
import { StripePaymentsProvider } from "../infrastructure/stripe/stripe-payments.provider";
import { PushNotificationsService } from "../../notifications/application/push-notifications.service";

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    @Inject(PAYMENTS_REPOSITORY)
    private readonly repository: PaymentsRepository,
    private readonly stripe: StripePaymentsProvider,
    private readonly config: ConfigService,
    private readonly pushNotifications: PushNotificationsService,
  ) {}

  async orders(user: RequestUser) {
    return { items: await this.repository.listOrders(user) };
  }

  async history(user: RequestUser) {
    return { items: await this.repository.listPayments(user) };
  }

  async configuration(user: RequestUser) {
    const configuration = (await this.repository.configuration(user)) as Record<
      string,
      unknown
    >;
    return {
      ...configuration,
      stripeEnabled: this.config.get<boolean>("stripe.enabled") ?? false,
    };
  }
  async reviewQueue(user: RequestUser) {
    return { items: await this.repository.reviewQueue(user) };
  }
  createOrder(user: RequestUser, input: CreatePaymentOrderDto) {
    return this.repository.createOrder(user, input);
  }
  acceptOrder(
    user: RequestUser,
    orderId: string,
    input: AcceptPaymentOrderDto,
  ) {
    return this.repository.acceptOrder(
      user,
      orderId,
      input.accepted,
      input.reason,
    );
  }
  submit(user: RequestUser, orderId: string, input: SubmitPaymentDto) {
    return this.repository.submit(user, orderId, input);
  }
  async createStripePaymentIntent(
    user: RequestUser,
    orderId: string,
    input: CreateStripePaymentIntentDto,
  ) {
    this.stripe.assertConfigured();
    const order = await this.repository.createCardPayment(user, orderId, {
      stripePaymentIntentId: "",
      amount: 0,
    });
    const payment = order as {
      paymentId: string;
      amount: string;
      currency: string;
      concept: string;
      stripePaymentIntentId?: string | null;
    };
    if (payment.stripePaymentIntentId) {
      const intent = await this.stripe.retrievePaymentIntent(
        payment.stripePaymentIntentId,
      );
      return {
        paymentId: payment.paymentId,
        paymentIntentId: intent.id,
        clientSecret: intent.client_secret,
        amount: payment.amount,
        currency: payment.currency,
      };
    }
    const intent = await this.stripe.createPaymentIntent(
      {
        amount: Number(payment.amount),
        currency: payment.currency,
        metadata: {
          paymentId: payment.paymentId,
          paymentOrderId: orderId,
          userId: user.id,
        },
        description: payment.concept,
      },
      input.idempotencyKey,
    );
    await this.repository.createCardPayment(user, orderId, {
      stripePaymentIntentId: intent.id,
      amount: Number(payment.amount),
      transactionReference: intent.id,
    });
    return {
      paymentId: payment.paymentId,
      paymentIntentId: intent.id,
      clientSecret: intent.client_secret,
      amount: payment.amount,
      currency: payment.currency,
    };
  }

  async createStripeCheckoutSession(
    user: RequestUser,
    orderId: string,
    input: CreateStripePaymentIntentDto,
  ) {
    this.stripe.assertConfigured();
    const order = await this.repository.createCardPayment(user, orderId, {
      stripePaymentIntentId: "",
      amount: 0,
    });
    const payment = order as {
      paymentId: string;
      amount: string;
      currency: string;
      concept: string;
      stripeCheckoutSessionId?: string | null;
    };
    const returnUrl = this.config.getOrThrow<string>("stripe.paymentReturnUrl");
    const session = await this.stripe.createCheckoutSession(
      {
        amount: Number(payment.amount),
        currency: payment.currency,
        description: payment.concept,
        returnUrl,
        metadata: {
          paymentId: payment.paymentId,
          paymentOrderId: orderId,
          userId: user.id,
        },
      },
      input.idempotencyKey,
    );
    await this.repository.createCardPayment(user, orderId, {
      stripePaymentIntentId: "",
      stripeCheckoutSessionId: session.id,
      amount: Number(payment.amount),
      transactionReference: session.id,
    });
    return {
      paymentId: payment.paymentId,
      checkoutSessionId: session.id,
      url: session.url,
      amount: payment.amount,
      currency: payment.currency,
    };
  }

  async syncStripeCheckoutSession(
    user: RequestUser,
    checkoutSessionId: string,
  ) {
    this.stripe.assertConfigured();
    const session =
      await this.stripe.retrieveCheckoutSession(checkoutSessionId);
    if (session.metadata?.userId !== user.id) {
      throw new ForbiddenException(
        "La sesión de pago no pertenece al usuario.",
      );
    }
    if (session.payment_status !== "paid") {
      return {
        checkoutSessionId: session.id,
        status: session.payment_status,
        received: true,
      };
    }
    return this.repository.completeCardPayment({
      paymentId: session.metadata?.paymentId,
      paymentOrderId: session.metadata?.paymentOrderId,
      stripeCheckoutSessionId: session.id,
      stripePaymentIntentId: session.payment_intent?.toString(),
      status: "paid",
      transactionReference: session.payment_intent?.toString() ?? session.id,
    });
  }

  async syncStripePaymentIntent(user: RequestUser, paymentIntentId: string) {
    this.stripe.assertConfigured();
    const intent = await this.stripe.retrievePaymentIntent(paymentIntentId);
    if (intent.metadata?.userId !== user.id) {
      throw new ForbiddenException("El pago no pertenece al usuario.");
    }
    if (intent.status === "succeeded") {
      return this.repository.completeCardPayment({
        paymentId: intent.metadata?.paymentId,
        paymentOrderId: intent.metadata?.paymentOrderId,
        stripePaymentIntentId: intent.id,
        status: "paid",
        transactionReference: intent.latest_charge?.toString() ?? intent.id,
      });
    }
    if (
      intent.status === "requires_payment_method" ||
      intent.status === "canceled"
    ) {
      return this.repository.completeCardPayment({
        paymentId: intent.metadata?.paymentId,
        paymentOrderId: intent.metadata?.paymentOrderId,
        stripePaymentIntentId: intent.id,
        status: "failed",
        transactionReference: intent.id,
        failureReason:
          intent.last_payment_error?.message ?? "Stripe no completó el pago.",
      });
    }
    return {
      paymentIntentId: intent.id,
      status: intent.status,
      received: true,
    };
  }

  async handleStripeWebhook(signature: string | undefined, rawBody: string) {
    const event = this.stripe.constructWebhookEvent(rawBody, signature);
    if (
      event.type === "payment_intent.succeeded" ||
      event.type === "payment_intent.payment_failed"
    ) {
      const intent = event.data.object;
      const status =
        event.type === "payment_intent.succeeded" ? "paid" : "failed";
      try {
        return await this.repository.completeCardPayment({
          paymentId: intent.metadata?.paymentId,
          paymentOrderId: intent.metadata?.paymentOrderId,
          stripePaymentIntentId: intent.id,
          status,
          transactionReference: intent.latest_charge?.toString() ?? intent.id,
          failureReason:
            status === "failed"
              ? (intent.last_payment_error?.message ??
                "Stripe rechazó el pago.")
              : undefined,
        });
      } catch (error) {
        if (error instanceof NotFoundException) {
          return { received: true, ignored: event.type };
        }
        throw error;
      }
    }
    if (event.type === "checkout.session.completed") {
      const session = event.data.object;
      try {
        return await this.repository.completeCardPayment({
          paymentId: session.metadata?.paymentId,
          paymentOrderId: session.metadata?.paymentOrderId,
          stripeCheckoutSessionId: session.id,
          stripePaymentIntentId: session.payment_intent?.toString(),
          status: "paid",
          transactionReference:
            session.payment_intent?.toString() ?? session.id,
        });
      } catch (error) {
        if (error instanceof NotFoundException) {
          return { received: true, ignored: event.type };
        }
        throw error;
      }
    }
    return { received: true, ignored: event.type };
  }
  registerInPerson(
    user: RequestUser,
    orderId: string,
    input: RegisterInPersonPaymentDto,
  ) {
    return this.repository.registerInPerson(user, orderId, input);
  }
  confirmInPerson(
    user: RequestUser,
    paymentId: string,
    input: ConfirmInPersonPaymentDto,
  ) {
    return this.repository.confirmInPerson(
      user,
      paymentId,
      input.confirmed,
      input.description,
      input.reportedAmount,
    );
  }
  async review(user: RequestUser, paymentId: string, input: ReviewPaymentDto) {
    const result = (await this.repository.review(
      user,
      paymentId,
      input.approved,
      input.reason,
    )) as { id: string; status: string; userId?: string };

    if (result.userId) {
      const title = input.approved ? "Pago aprobado" : "Pago rechazado";
      const body = input.approved
        ? "Tu pago fue aprobado."
        : input.reason?.trim()
          ? `Tu pago fue rechazado: ${input.reason.trim()}`
          : "Tu pago fue rechazado. Revisa el motivo e intenta nuevamente.";
      try {
        await this.pushNotifications.sendToUser(result.userId, {
          eventCode: input.approved ? "payment.approved" : "payment.rejected",
          title,
          body,
          relatedEntityType: "payment",
          relatedEntityId: paymentId,
        });
      } catch (err: any) {
        this.logger.warn(
          `Error enviando notificación push de pago: ${err.message}`,
        );
      }
    }

    return result;
  }
  reportIncident(
    user: RequestUser,
    paymentId: string,
    input: ReportPaymentIncidentDto,
  ) {
    return this.repository.reportIncident(user, paymentId, input);
  }
  resolveIncident(
    user: RequestUser,
    incidentId: string,
    input: ResolvePaymentIncidentDto,
  ) {
    return this.repository.resolveIncident(user, incidentId, input);
  }
  async incidents(user: RequestUser) {
    return { items: await this.repository.incidents(user) };
  }
  startIncidentReview(user: RequestUser, incidentId: string) {
    return this.repository.startIncidentReview(user, incidentId);
  }
  async refunds(user: RequestUser) {
    return { items: await this.repository.refunds(user) };
  }
}
