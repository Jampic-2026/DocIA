import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/professional.dart';
import '../domain/professionals_repository.dart';
import '../infrastructure/api/api_professionals_repository.dart';

final professionalsRepositoryProvider = Provider<ProfessionalsRepository>(
  (ref) => ApiProfessionalsRepository(ref.watch(authenticatedApiClientProvider)),
);

final professionalDirectoryProvider = FutureProvider<List<Professional>>(
  (ref) => ref.watch(professionalsRepositoryProvider).listDirectory(),
);
