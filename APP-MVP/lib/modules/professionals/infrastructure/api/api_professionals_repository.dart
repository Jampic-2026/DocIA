import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/professional.dart';
import '../../domain/professionals_repository.dart';

class ApiProfessionalsRepository implements ProfessionalsRepository {
  ApiProfessionalsRepository(this._client);
  final AuthenticatedApiClient _client;

  @override
  Future<List<Professional>> listDirectory() async {
    final response = await _client.get<Map<String, dynamic>>(
      'professionals/professionals',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'El directorio médico no tiene un formato válido.',
      );
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final availability = json['availability'];
          return Professional(
            id: json['id'] as String,
            bookableSlots: (json['bookableSlots'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(
                  (row) => ProfessionalSlot(
                    startAt: DateTime.parse(row['startAt'] as String),
                    endAt: DateTime.parse(row['endAt'] as String),
                    modality: row['modality'] as String,
                  ),
                )
                .toList(),
            requiresReferral: json['requiresReferral'] == true,
            publicDetails:
                json['publicDetails'] as Map<String, dynamic>? ?? const {},
            fullName: json['fullName'] as String,
            specialtyId: json['specialtyId'] as String,
            specialty: json['specialty'] as String,
            yearsExperience: json['yearsExperience'] as int,
            averageRating: (json['averageRating'] as num).toDouble(),
            ratingCount: json['ratingCount'] as int,
            availability: availability is List
                ? availability
                      .whereType<Map<String, dynamic>>()
                      .map(
                        (slot) => ProfessionalAvailability(
                          weekday: slot['weekday'] as int,
                          startTime: slot['startTime'] as String,
                          endTime: slot['endTime'] as String,
                          modality: slot['modality'] as String,
                        ),
                      )
                      .toList(growable: false)
                : const [],
          );
        })
        .toList(growable: false);
  }
}
