import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/payment_record.dart';
import '../../domain/payments_repository.dart';

class ApiPaymentsRepository implements PaymentsRepository {
  ApiPaymentsRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<PaymentOrder>> listOrders() async {
    final response = await _client.get<Map<String, dynamic>>('payments/orders');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PaymentOrder.fromJson)
        .toList();
  }

  @override
  Future<List<PaymentRecord>> listHistory() async {
    final response = await _client.get<Map<String, dynamic>>(
      'payments/history',
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList();
  }

  @override
  Future<List<PaymentRecord>> reviewQueue() async {
    final response = await _client.get<Map<String, dynamic>>(
      'payments/review-queue',
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList();
  }

  @override
  Future<PaymentConfiguration> configuration() async {
    final response = await _client.get<Map<String, dynamic>>(
      'payments/configuration',
    );
    return PaymentConfiguration.fromJson(response.data ?? const {});
  }

  @override
  Future<PaymentOrder> createOrder({
    required String serviceId,
    String? appointmentId,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'payments/orders',
      data: {
        'serviceId': serviceId,
        if (appointmentId != null) 'appointmentId': appointmentId,
        if (relatedEntityType != null) 'relatedEntityType': relatedEntityType,
        if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
      },
    );
    return PaymentOrder.fromJson(response.data ?? const {});
  }

  @override
  Future<void> submitQrPayment(
    String orderId, {
    required double amount,
    required String receiptUrl,
    String? transactionReference,
    String? collectionContext,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'payments/orders/$orderId/payments',
      data: {
        'method': 'qr',
        'amount': amount,
        'receiptUrl': receiptUrl,
        if (transactionReference?.trim().isNotEmpty ?? false)
          'transactionReference': transactionReference!.trim(),
        if (collectionContext?.trim().isNotEmpty ?? false)
          'collectionContext': collectionContext!.trim(),
      },
    );
  }

  @override
  Future<StripePaymentIntent> createStripePaymentIntent(String orderId) async {
    final response = await _client.post<Map<String, dynamic>>(
      'payments/orders/$orderId/stripe/payment-intent',
      data: <String, dynamic>{},
    );
    return StripePaymentIntent.fromJson(response.data ?? const {});
  }

  @override
  Future<StripeCheckoutSession> createStripeCheckoutSession(
    String orderId,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      'payments/orders/$orderId/stripe/checkout-session',
      data: <String, dynamic>{},
    );
    return StripeCheckoutSession.fromJson(response.data ?? const {});
  }

  @override
  Future<void> syncStripeCheckoutSession(String sessionId) async {
    await _client.post<Map<String, dynamic>>(
      'payments/stripe/checkout-sessions/$sessionId/sync',
      data: <String, dynamic>{},
    );
  }

  @override
  Future<void> syncStripePaymentIntent(String paymentIntentId) async {
    await _client.post<Map<String, dynamic>>(
      'payments/stripe/payment-intents/$paymentIntentId/sync',
      data: <String, dynamic>{},
    );
  }

  @override
  Future<void> reviewPayment(
    String paymentId, {
    required bool approved,
    String? reason,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'payments/$paymentId/review',
      data: {
        'approved': approved,
        if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
      },
    );
  }
}
