import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Stripe = require("stripe");

@Injectable()
export class StripePaymentsProvider {
  private readonly enabled: boolean;
  private readonly webhookSecret?: string;
  private readonly stripe?: Stripe;

  constructor(private readonly config: ConfigService) {
    this.enabled = config.get<boolean>("stripe.enabled", false);
    this.webhookSecret = config.get<string>("stripe.webhookSecret");
    const secretKey = config.get<string>("stripe.secretKey");
    if (this.enabled && secretKey) {
      this.stripe = new Stripe(secretKey, {
        apiVersion: "2026-07-29.dahlia",
      });
    }
  }

  async createPaymentIntent(
    input: {
      amount: number;
      currency: string;
      description: string;
      metadata: Record<string, string>;
    },
    idempotencyKey?: string,
  ) {
    const stripe = this.getClient();
    return stripe.paymentIntents.create(
      {
        amount: Math.round(input.amount * 100),
        currency: input.currency.toLowerCase(),
        automatic_payment_methods: { enabled: true },
        description: input.description,
        metadata: input.metadata,
      },
      idempotencyKey ? { idempotencyKey } : undefined,
    );
  }

  async retrievePaymentIntent(paymentIntentId: string) {
    return this.getClient().paymentIntents.retrieve(paymentIntentId);
  }

  async retrieveCheckoutSession(checkoutSessionId: string) {
    return this.getClient().checkout.sessions.retrieve(checkoutSessionId);
  }

  async createCheckoutSession(
    input: {
      amount: number;
      currency: string;
      description: string;
      metadata: Record<string, string>;
      returnUrl: string;
    },
    idempotencyKey?: string,
  ) {
    const stripe = this.getClient();
    return stripe.checkout.sessions.create(
      {
        mode: "payment",
        locale: "es",
        billing_address_collection: "required",
        line_items: [
          {
            quantity: 1,
            price_data: {
              currency: input.currency.toLowerCase(),
              unit_amount: Math.round(input.amount * 100),
              product_data: {
                name: input.description,
              },
            },
          },
        ],
        success_url: `${input.returnUrl}?stripe_status=success&session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${input.returnUrl}?stripe_status=cancelled`,
        metadata: input.metadata,
        payment_intent_data: {
          metadata: input.metadata,
          description: input.description,
        },
      },
      idempotencyKey ? { idempotencyKey } : undefined,
    );
  }

  assertConfigured() {
    this.getClient();
  }

  constructWebhookEvent(rawBody: string, signature?: string) {
    const stripe = this.getClient();
    if (!this.webhookSecret) {
      throw new ServiceUnavailableException(
        "Stripe webhook no está configurado.",
      );
    }
    if (!signature) {
      throw new ServiceUnavailableException("Firma Stripe ausente.");
    }
    return stripe.webhooks.constructEvent(
      rawBody,
      signature,
      this.webhookSecret,
    );
  }

  private getClient() {
    if (!this.enabled || !this.stripe) {
      throw new ServiceUnavailableException("Stripe no está habilitado.");
    }
    return this.stripe;
  }
}
