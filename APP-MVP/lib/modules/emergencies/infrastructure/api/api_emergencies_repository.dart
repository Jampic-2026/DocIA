import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/emergencies_repository.dart';
import '../../domain/emergency_event.dart';

class ApiEmergenciesRepository implements EmergenciesRepository {
  ApiEmergenciesRepository(this._client);
  final AuthenticatedApiClient _client;
  EmergencyEvent _map(Map<String, dynamic> json) => EmergencyEvent(
    id: json['id'] as String,
    status: json['status'] as String,
    patientId: json['patientId'] as String?,
    acceptedAt: DateTime.tryParse(
      json['acceptedAt']?.toString() ?? '',
    )?.toLocal(),
    riskLevel: json['riskLevel'] as String,
    description: json['description'] as String?,
    manualAddress: json['manualAddress'] as String?,
    latitude: _number(json['latitude']),
    longitude: _number(json['longitude']),
    assignedTeamName: json['assignedTeamName'] as String?,
    assignedTeamPhone: json['assignedTeamPhone'] as String?,
    patientName: json['patientName'] as String?,
    patientPhone: json['patientPhone'] as String?,
    assignedProfessionalId: json['assignedProfessionalId'] as String?,
    assignedOperatorId: json['assignedOperatorId'] as String?,
    reference: json['reference'] as String?,
    coverageAvailable: json['coverageAvailable'] as bool?,
    openedAt: DateTime.parse(json['openedAt'] as String).toLocal(),
  );
  static double? _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  @override
  Future<void> decideAssignment(
    String id, {
    required String decision,
    String? reason,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'emergencies/events/$id/assignment-decision',
      data: {'decision': decision, 'reason': reason},
    );
  }

  @override
  Future<void> recordCare(String id, EmergencyCareCommand command) async {
    await _client.post<Map<String, dynamic>>(
      'emergencies/events/$id/care-records',
      data: {
        'careType': command.careType,
        'notes': command.notes,
        'symptoms': command.symptoms,
        'assessment': command.assessment,
        'procedures': command.procedures,
        'referralDestination': command.referralDestination,
      },
    );
  }

  @override
  Future<List<EmergencyCareRecord>> careHistory(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      'emergencies/events/$id/care-records',
    );
    return (response.data!['items'] as List)
        .map(
          (item) => EmergencyCareRecord(
            id: item['id'] as String,
            careType: item['care_type'] as String,
            notes: item['notes'] as String,
            createdAt: DateTime.parse(item['created_at'] as String).toLocal(),
            content: Map<String, dynamic>.from(item['content'] as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<EmergencyEvent>> list() async {
    final response = await _client.get<Map<String, dynamic>>(
      'emergencies/events',
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_map)
        .toList(growable: false);
  }

  @override
  Future<EmergencyEvent> create({
    String? patientId,
    required String riskLevel,
    String? description,
    String? manualAddress,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'emergencies/events',
      data: {
        'riskLevel': riskLevel,
        if (patientId != null) 'patientId': patientId,
        if (description?.trim().isNotEmpty ?? false)
          'description': description!.trim(),
        if (manualAddress?.trim().isNotEmpty ?? false)
          'manualAddress': manualAddress!.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    return _map(response.data!);
  }

  @override
  Future<EmergencyEvent> cancel(String id) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'emergencies/events/$id/cancel',
    );
    return _map(response.data!);
  }

  @override
  Future<EmergencyEvent> assign(
    String id, {
    String? professionalId,
    String? operatorId,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'emergencies/events/$id/assign',
      data: {
        if (professionalId != null) 'professionalId': professionalId,
        if (operatorId != null) 'operatorId': operatorId,
      },
    );
    return _map(response.data!);
  }

  @override
  Future<EmergencyEvent> updateStatus(
    String id, {
    required String status,
    String? notes,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'emergencies/events/$id/status',
      data: {
        'status': status,
        if (notes?.trim().isNotEmpty ?? false) 'notes': notes!.trim(),
      },
    );
    return _map(response.data!);
  }
}
