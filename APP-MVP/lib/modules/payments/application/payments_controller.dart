import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/payment_record.dart';
import '../domain/payments_repository.dart';
import '../infrastructure/api/api_payments_repository.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => ApiPaymentsRepository(ref.watch(authenticatedApiClientProvider)),
);

final paymentOrdersProvider = FutureProvider<List<PaymentOrder>>(
  (ref) => ref.watch(paymentsRepositoryProvider).listOrders(),
);

final paymentHistoryProvider = FutureProvider<List<PaymentRecord>>(
  (ref) => ref.watch(paymentsRepositoryProvider).listHistory(),
);

final paymentReviewQueueProvider = FutureProvider<List<PaymentRecord>>(
  (ref) => ref.watch(paymentsRepositoryProvider).reviewQueue(),
);

final paymentConfigurationProvider = FutureProvider<PaymentConfiguration>(
  (ref) => ref.watch(paymentsRepositoryProvider).configuration(),
);

final createStripePaymentIntentProvider =
    FutureProvider.family<StripePaymentIntent, String>(
  (ref, orderId) =>
      ref.watch(paymentsRepositoryProvider).createStripePaymentIntent(orderId),
);
