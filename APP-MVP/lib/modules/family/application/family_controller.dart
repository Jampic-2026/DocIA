import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/family_member.dart';
import '../domain/family_repository.dart';
import '../infrastructure/api/api_family_repository.dart';

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => ApiFamilyRepository(ref.watch(authenticatedApiClientProvider)),
);

final familyProvider = FutureProvider<List<FamilyMember>>(
  (ref) => ref.watch(familyRepositoryProvider).list(),
);
