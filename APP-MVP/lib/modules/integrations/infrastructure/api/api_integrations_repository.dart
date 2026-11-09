import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/google_workspace_status.dart';
import '../../domain/integrations_repository.dart';

class ApiIntegrationsRepository implements IntegrationsRepository {
  ApiIntegrationsRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<GoogleWorkspaceStatus> googleStatus() async {
    final response = await _client.get<Map<String, dynamic>>(
      'integrations/google/status',
    );
    final data = response.data ?? const <String, dynamic>{};
    return GoogleWorkspaceStatus(
      connected: data['connected'] == true,
      expiresAt: data['expiresAt'] is String
          ? DateTime.parse(data['expiresAt'] as String).toLocal()
          : null,
      connectedByName: data['connectedByName'] as String?,
      redirectUri: data['redirectUri'] as String? ?? '',
    );
  }

  @override
  Future<Uri> googleAuthorizationUrl() async {
    final response = await _client.get<Map<String, dynamic>>(
      'integrations/google/authorize',
    );
    final value = response.data?['authorizationUrl'] as String?;
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('Google no devolvió una URL válida.');
    }
    return uri;
  }

  @override
  Future<void> disconnectGoogle() async {
    await _client.delete<Map<String, dynamic>>('integrations/google');
  }
}
