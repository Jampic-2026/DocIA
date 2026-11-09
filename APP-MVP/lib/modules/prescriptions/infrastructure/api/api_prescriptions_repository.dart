import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/prescription.dart';
import '../../domain/prescriptions_repository.dart';

class ApiPrescriptionsRepository implements PrescriptionsRepository {
  ApiPrescriptionsRepository(this._client);
  final AuthenticatedApiClient _client;

  @override
  Future<List<Prescription>> list() async {
    final response = await _client.get<Map<String, dynamic>>(
      'prescriptions/prescriptions',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'La lista de recetas no tiene un formato válido.',
      );
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final medicationItems = json['items'];
          return Prescription(
            id: json['id'] as String,
            patientName: json['patientName'] as String,
            professionalName: json['professionalName'] as String,
            status: json['status'] as String,
            createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
            issuedAt: json['issuedAt'] == null
                ? null
                : DateTime.parse(json['issuedAt'] as String).toLocal(),
            expiresAt: json['expiresAt'] == null
                ? null
                : DateTime.parse(json['expiresAt'] as String).toLocal(),
            items: medicationItems is List
                ? medicationItems
                      .whereType<Map<String, dynamic>>()
                      .map((item) {
                        return PrescriptionItem(
                          id: item['id'] as String,
                          medicationName: item['medicationName'] as String,
                          dose: item['dose'] as String?,
                          frequency: item['frequency'] as String?,
                          duration: item['duration'] as String?,
                          instructions: item['instructions'] as String?,
                        );
                      })
                      .toList(growable: false)
                : const [],
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> createDraft(CreatePrescriptionCommand command) async {
    await _client.post<Map<String, dynamic>>(
      'prescriptions/prescriptions',
      data: {
        'patientId': command.patientId,
        'appointmentId': command.appointmentId,
        'items': [
          {
            'medicationName': command.medicationName,
            'dose': command.dose,
            'frequency': command.frequency,
            'duration': command.duration,
            'instructions': command.instructions,
          },
        ],
      },
    );
  }

  @override
  Future<Map<String, dynamic>> safetyReview(String id) async =>
      (await _client.get<Map<String, dynamic>>(
        'prescriptions/prescriptions/$id/safety-review',
      )).data!;
  @override
  Future<void> issue(
    String id,
    DateTime expiresAt, {
    String? allergyFingerprint,
    String? allergyReviewReason,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'prescriptions/prescriptions/$id/issue',
      data: {
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (allergyFingerprint != null)
          'allergyFingerprint': allergyFingerprint,
        if (allergyReviewReason != null)
          'allergyReviewReason': allergyReviewReason,
      },
    );
  }
}
