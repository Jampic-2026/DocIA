import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/incident.dart';
import '../domain/incidents_repository.dart';
import '../infrastructure/api/api_incidents_repository.dart';

final incidentsRepositoryProvider = Provider<IncidentsRepository>(
  (ref) => ApiIncidentsRepository(ref.watch(authenticatedApiClientProvider)),
);

class IncidentsController extends AsyncNotifier<List<Incident>> {
  @override
  Future<List<Incident>> build() {
    return ref.read(incidentsRepositoryProvider).list();
  }

  Future<void> create({
    required String module,
    required String incidentType,
    required String severity,
    required String description,
  }) async {
    await ref
        .read(incidentsRepositoryProvider)
        .create(
          module: module,
          incidentType: incidentType,
          severity: severity,
          description: description,
        );
    ref.invalidateSelf();
  }

  Future<void> close(String id) async {
    await ref.read(incidentsRepositoryProvider).close(id);
    ref.invalidateSelf();
  }
}

final incidentsControllerProvider =
    AsyncNotifierProvider<IncidentsController, List<Incident>>(
      IncidentsController.new,
    );
