import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/delivery_summary.dart';
import '../../domain/deliveries_repository.dart';

class ApiDeliveriesRepository implements DeliveriesRepository {
  ApiDeliveriesRepository(this._client);
  final AuthenticatedApiClient _client;
  @override
  Future<List<DeliverySummary>> list() async {
    final response = await _client.get<Map<String, dynamic>>(
      'deliveries/deliveries',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'Las entregas no tienen un formato v\u00e1lido.',
      );
    }
    return items.cast<Map<String, dynamic>>().map(_map).toList();
  }

  DeliverySummary _map(Map<String, dynamic> json) {
    return DeliverySummary(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      title:
          json['title'] as String? ??
          json['deliveryType'] as String? ??
          json['delivery_type'] as String? ??
          'Entrega',
      recipient:
          json['recipientName'] as String? ??
          json['recipient_name'] as String? ??
          json['patientName'] as String? ??
          json['patient_name'] as String?,
      address:
          json['deliveryAddress'] as String? ??
          json['delivery_address'] as String? ??
          json['address'] as String?,
      scheduledAt: DateTime.tryParse(
        json['scheduledAt'] as String? ?? json['scheduled_at'] as String? ?? '',
      ),
    );
  }
}
