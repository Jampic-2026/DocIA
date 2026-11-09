import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/benefit.dart';
import '../domain/benefits_repository.dart';
import '../infrastructure/api/api_benefits_repository.dart';

final benefitsRepositoryProvider = Provider<BenefitsRepository>(
  (ref) => ApiBenefitsRepository(ref.watch(authenticatedApiClientProvider)),
);

final benefitsProvider = FutureProvider<List<Benefit>>(
  (ref) => ref.watch(benefitsRepositoryProvider).list(),
);

final benefitUsagesProvider = FutureProvider<List<BenefitUsage>>(
  (ref) => ref.watch(benefitsRepositoryProvider).listUsages(),
);
