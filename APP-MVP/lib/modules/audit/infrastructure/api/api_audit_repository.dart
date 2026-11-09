import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/audit_event.dart';
import '../../domain/audit_repository.dart';

class ApiAuditRepository implements AuditRepository {
  ApiAuditRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<AuditEvent>> listEvents() async {
    final response =
        await _client.get<Map<String, dynamic>>('audit/audit-events');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => AuditEvent.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
