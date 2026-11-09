import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/account_profile.dart';
import '../domain/account_repository.dart';
import '../infrastructure/api/api_account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => ApiAccountRepository(ref.watch(authenticatedApiClientProvider)),
);

final accountProfileProvider = FutureProvider<AccountProfile>(
  (ref) => ref.watch(accountRepositoryProvider).getProfile(),
);
