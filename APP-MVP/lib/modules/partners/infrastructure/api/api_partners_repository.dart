import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/partner_summary.dart';
import '../../domain/partners_repository.dart';

class ApiPartnersRepository implements PartnersRepository {
  @override
  Future<List<Map<String, dynamic>>> diagnosticOrders() async {
    final result = await _client.get<Map<String, dynamic>>(
      'partners/diagnostic-orders',
    );
    return (result.data!['items'] as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> createDiagnosticOrder({
    required String patientId,
    String? appointmentId,
    String? partnerId,
    required String orderType,
    required String description,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'partners/diagnostic-orders',
      data: {
        'patientId': patientId,
        if (appointmentId != null) 'appointmentId': appointmentId,
        if (partnerId != null) 'partnerId': partnerId,
        'orderType': orderType,
        'description': description,
      },
    );
  }

  ApiPartnersRepository(this._client);
  final AuthenticatedApiClient _client;
  @override
  Future<List<PartnerSummary>> list() async {
    final response = await _client.get<Map<String, dynamic>>(
      'partners/health-partners',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException('Las empresas no tienen un formato válido.');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (j) => PartnerSummary(
            id: j['id'] as String,
            name: j['name'] as String,
            partnerType: j['partnerType'] as String,
            isActive: j['isActive'] as bool,
            siteCount: j['siteCount'] as int,
            taxId: j['taxId'] as String?,
            phone: j['phone'] as String?,
            email: j['email'] as String?,
            address: j['address'] as String?,
            subscriptionStatus: j['subscriptionStatus'] as String?,
            planName: j['planName'] as String?,
          ),
        )
        .toList();
  }
}
