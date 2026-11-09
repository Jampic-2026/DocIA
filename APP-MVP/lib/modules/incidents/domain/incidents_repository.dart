import 'incident.dart';

abstract interface class IncidentsRepository {
  Future<List<Incident>> list();
  Future<Incident> create({
    required String module,
    required String incidentType,
    required String severity,
    required String description,
  });
  Future<Incident> close(String id);
}
