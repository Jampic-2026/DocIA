export type PaymentOrder = {
  id: string;
  concept: string;
  chargeMode: string;
  coinAmount: string | null;
  amount: string | null;
  currency: string;
  status: string;
  dueAt: Date | null;
  acceptedAt: Date | null;
  createdAt: Date;
  serviceName: string | null;
  relatedEntityType: string | null;
  qrImageUrl: string | null;
  latestPaymentMethod: string | null;
  latestPaymentStatus: string | null;
  latestPaymentRejectionReason: string | null;
};

export type PaymentRecord = {
  id: string;
  paymentOrderId: string;
  concept: string;
  method: string;
  amount: string;
  currency: string;
  status: string;
  transactionReference: string | null;
  paidAt: Date | null;
  rejectionReason: string | null;
  createdAt: Date;
};
