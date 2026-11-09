import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/incident.dart';
import '../../domain/incidents_repository.dart';

class ApiIncidentsRepository implements IncidentsRepository {
  ApiIncidentsRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<Incident>> list() async {
    final response = await _client.get<Map<String, dynamic>>('incidents');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Incident.fromJson)
        .toList();
  }

  @override
  Future<Incident> create({
    required String module,
    required String incidentType,
    required String severity,
    required String description,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'incidents',
      data: {
        'module': module,
        'incidentType': incidentType,
        'severity': severity,
        'description': description,
      },
    );
    return Incident.fromJson(response.data!);
  }

  @override
  Future<Incident> close(String id) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'incidents/$id/close',
      data: const <String, dynamic>{},
    );
    return Incident.fromJson(response.data!);
  }
}
