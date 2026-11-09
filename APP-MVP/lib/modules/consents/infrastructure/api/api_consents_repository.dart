import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/consent_preference.dart';
import '../../domain/consents_repository.dart';

class ApiConsentsRepository implements ConsentsRepository {
  ApiConsentsRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<ConsentPreference>> list() async {
    final response = await _client.get<Map<String, dynamic>>('consents');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ConsentPreference.fromJson)
        .toList();
  }

  @override
  Future<void> accept(String code) async {
    await _client.post<Map<String, dynamic>>(
      'consents/$code/accept',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<void> revoke(String code) async {
    await _client.post<Map<String, dynamic>>(
      'consents/$code/revoke',
      data: const <String, dynamic>{},
    );
  }
}
