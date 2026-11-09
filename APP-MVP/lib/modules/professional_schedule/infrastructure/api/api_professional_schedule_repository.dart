import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/professional_schedule.dart';
import '../../domain/professional_schedule_repository.dart';

class ApiProfessionalScheduleRepository
    implements ProfessionalScheduleRepository {
  ApiProfessionalScheduleRepository(this._client);
  final AuthenticatedApiClient _client;
  int _int(Object? value) => int.tryParse(value.toString()) ?? 0;

  @override
  Future<ProfessionalSchedule> getSchedule() async {
    final response = await _client.get<Map<String, dynamic>>(
      'professionals/schedule',
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('La agenda no tiene un formato válido.');
    }
    final availability = data['availability'];
    final blocks = data['timeBlocks'];
    return ProfessionalSchedule(
      availability: availability is List
          ? availability
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => AvailabilitySlot(
                    id: item['id'] as String,
                    weekday: _int(item['weekday']),
                    startTime: item['startTime'] as String,
                    endTime: item['endTime'] as String,
                    modality: item['modality'] as String,
                  ),
                )
                .toList(growable: false)
          : const [],
      timeBlocks: blocks is List
          ? blocks
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => ProfessionalTimeBlock(
                    id: item['id'] as String,
                    startAt: DateTime.parse(
                      item['startAt'] as String,
                    ).toLocal(),
                    endAt: DateTime.parse(item['endAt'] as String).toLocal(),
                    reason: item['reason'] as String?,
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  @override
  Future<void> addAvailability({
    required int weekday,
    required String startTime,
    required String endTime,
    required String modality,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'professionals/professional-availability',
      data: {
        'weekday': weekday,
        'startTime': startTime,
        'endTime': endTime,
        'modality': modality,
      },
    );
  }

  @override
  Future<void> removeAvailability(String id) => _client
      .delete<Map<String, dynamic>>(
        'professionals/professional-availability/$id',
        data: const <String, dynamic>{},
      )
      .then((_) {});

  @override
  Future<void> addTimeBlock({
    required DateTime startAt,
    required DateTime endAt,
    String? reason,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'professionals/professional-time-blocks',
      data: {
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        'reason': reason,
      },
    );
  }

  @override
  Future<void> removeTimeBlock(String id) => _client
      .delete<Map<String, dynamic>>(
        'professionals/professional-time-blocks/$id',
        data: const <String, dynamic>{},
      )
      .then((_) {});
}
