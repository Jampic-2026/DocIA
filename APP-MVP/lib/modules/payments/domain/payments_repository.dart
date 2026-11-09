import 'payment_record.dart';

abstract interface class PaymentsRepository {
  Future<List<PaymentOrder>> listOrders();
  Future<List<PaymentRecord>> listHistory();
  Future<List<PaymentRecord>> reviewQueue();
  Future<PaymentConfiguration> configuration();
  Future<PaymentOrder> createOrder({
    required String serviceId,
    String? appointmentId,
    String? relatedEntityType,
    String? relatedEntityId,
  });
  Future<void> submitQrPayment(
    String orderId, {
    required double amount,
    required String receiptUrl,
    String? transactionReference,
    String? collectionContext,
  });
  Future<StripePaymentIntent> createStripePaymentIntent(String orderId);
  Future<StripeCheckoutSession> createStripeCheckoutSession(String orderId);
  Future<void> syncStripePaymentIntent(String paymentIntentId);
  Future<void> syncStripeCheckoutSession(String sessionId);
  Future<void> reviewPayment(String paymentId, {required bool approved, String? reason});
}
