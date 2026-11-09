import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/deliveries_repository.dart';
import '../infrastructure/api/api_deliveries_repository.dart';
import '../domain/delivery_summary.dart';

final deliveriesRepositoryProvider = Provider<DeliveriesRepository>(
  (ref) => ApiDeliveriesRepository(ref.watch(authenticatedApiClientProvider)),
);
final deliveriesProvider = FutureProvider<List<DeliverySummary>>(
  (ref) => ref.watch(deliveriesRepositoryProvider).list(),
);
