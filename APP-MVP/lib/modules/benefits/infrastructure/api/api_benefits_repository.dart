import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/benefit.dart';
import '../../domain/benefits_repository.dart';

class ApiBenefitsRepository implements BenefitsRepository {
  ApiBenefitsRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<Benefit>> list() async {
    final response = await _client.get<Map<String, dynamic>>('benefits');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Benefit.fromJson)
        .toList();
  }

  @override
  Future<List<BenefitUsage>> listUsages() async {
    final response = await _client.get<Map<String, dynamic>>('benefits/usages');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(BenefitUsage.fromJson)
        .toList();
  }
}
