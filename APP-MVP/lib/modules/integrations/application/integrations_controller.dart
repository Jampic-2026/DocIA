import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/google_workspace_status.dart';
import '../domain/integrations_repository.dart';
import '../infrastructure/api/api_integrations_repository.dart';

final integrationsRepositoryProvider = Provider<IntegrationsRepository>(
  (ref) => ApiIntegrationsRepository(ref.watch(authenticatedApiClientProvider)),
);

final googleWorkspaceStatusProvider = FutureProvider<GoogleWorkspaceStatus>(
  (ref) => ref.watch(integrationsRepositoryProvider).googleStatus(),
);
