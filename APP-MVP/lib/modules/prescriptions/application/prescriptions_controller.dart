import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/prescription.dart';
import '../domain/prescriptions_repository.dart';
import '../infrastructure/api/api_prescriptions_repository.dart';

final prescriptionsRepositoryProvider = Provider<PrescriptionsRepository>(
  (ref) =>
      ApiPrescriptionsRepository(ref.watch(authenticatedApiClientProvider)),
);

final prescriptionsProvider = FutureProvider<List<Prescription>>(
  (ref) => ref.watch(prescriptionsRepositoryProvider).list(),
);
