import { RequestUser } from "../../../../common/types/request-user";
import { PaymentOrder, PaymentRecord } from "../payment-record";

export const PAYMENTS_REPOSITORY = Symbol("PAYMENTS_REPOSITORY");

export interface PaymentsRepository {
  listOrders(user: RequestUser): Promise<PaymentOrder[]>;
  listPayments(user: RequestUser): Promise<PaymentRecord[]>;
  configuration(user: RequestUser): Promise<unknown>;
  reviewQueue(user: RequestUser): Promise<unknown[]>;
  createOrder(user: RequestUser, input: CreateOrderInput): Promise<unknown>;
  acceptOrder(
    user: RequestUser,
    orderId: string,
    accepted: boolean,
    reason?: string,
  ): Promise<unknown>;
  submit(
    user: RequestUser,
    orderId: string,
    input: {
      method: "qr" | "cash";
      amount: number;
      receiptUrl?: string;
      transactionReference?: string;
      collectionContext?: string;
    },
  ): Promise<unknown>;
  createCardPayment(
    user: RequestUser,
    orderId: string,
    input: {
      stripePaymentIntentId: string;
      stripeCheckoutSessionId?: string;
      amount: number;
      transactionReference?: string;
    },
  ): Promise<unknown>;
  completeCardPayment(input: {
    paymentId?: string;
    paymentOrderId?: string;
    stripePaymentIntentId?: string;
    stripeCheckoutSessionId?: string;
    status: "paid" | "failed";
    transactionReference?: string;
    failureReason?: string;
  }): Promise<unknown>;
  registerInPerson(
    user: RequestUser,
    orderId: string,
    input: {
      method: "qr" | "cash";
      amount: number;
      receiptUrl?: string;
      transactionReference?: string;
      collectionContext: string;
    },
  ): Promise<unknown>;
  confirmInPerson(
    user: RequestUser,
    paymentId: string,
    confirmed: boolean,
    description?: string,
    reportedAmount?: number,
  ): Promise<unknown>;
  review(
    user: RequestUser,
    paymentId: string,
    approved: boolean,
    reason?: string,
  ): Promise<unknown>;
  reportIncident(
    user: RequestUser,
    paymentId: string,
    input: {
      incidentType: string;
      reportedAmount?: number;
      description: string;
    },
  ): Promise<unknown>;
  resolveIncident(
    user: RequestUser,
    incidentId: string,
    input: ResolveIncidentInput,
  ): Promise<unknown>;
  incidents(user: RequestUser): Promise<unknown[]>;
  startIncidentReview(user: RequestUser, incidentId: string): Promise<unknown>;
  refunds(user: RequestUser): Promise<unknown[]>;
}

export type ResolveIncidentInput = {
  action: "reject" | "adjust" | "refund_fiat" | "return_coins";
  resolution: string;
  amount?: number;
  coinAmount?: number;
};

export type CreateOrderInput = {
  serviceId: string;
  patientId?: string;
  appointmentId?: string;
  emergencyId?: string;
  relatedEntityType?: string;
  relatedEntityId?: string;
};
