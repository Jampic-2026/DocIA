import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/emergencies_repository.dart';
import '../infrastructure/api/api_emergencies_repository.dart';

final emergenciesRepositoryProvider = Provider<EmergenciesRepository>(
  (ref) => ApiEmergenciesRepository(ref.watch(authenticatedApiClientProvider)),
);

final emergencyEventsProvider = FutureProvider(
  (ref) => ref.watch(emergenciesRepositoryProvider).list(),
);
final emergencyCareProvider = FutureProvider.family(
  (ref, String id) => ref.watch(emergenciesRepositoryProvider).careHistory(id),
);
