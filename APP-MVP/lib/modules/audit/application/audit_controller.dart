import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/audit_event.dart';
import '../domain/audit_repository.dart';
import '../infrastructure/api/api_audit_repository.dart';

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => ApiAuditRepository(ref.watch(authenticatedApiClientProvider)),
);

final auditEventsProvider = FutureProvider<List<AuditEvent>>(
  (ref) => ref.watch(auditRepositoryProvider).listEvents(),
);
