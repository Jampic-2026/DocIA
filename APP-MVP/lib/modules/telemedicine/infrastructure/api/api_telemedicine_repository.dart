import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/telemedicine_repository.dart';
import '../../domain/telemedicine_room.dart';
import '../../domain/telemedicine_activity.dart';

class ApiTelemedicineRepository implements TelemedicineRepository {
  ApiTelemedicineRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<TelemedicineRoom>> listRooms() async {
    final response = await _client.get<Map<String, dynamic>>(
      'appointments/telemedicine-rooms',
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items.map((item) {
      final json = item as Map<String, dynamic>;
      return TelemedicineRoom(
        id: json['id'] as String,
        appointmentId: json['appointmentId'] as String,
        meetingUrl: json['meetingUrl'] as String,
        status: json['status'] as String,
        startAt: DateTime.parse(json['startAt'] as String).toLocal(),
        endAt: DateTime.parse(json['endAt'] as String).toLocal(),
        professionalName: json['professionalName'] as String,
        specialty: json['specialty'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> registerJoin(String roomId) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/telemedicine-rooms/$roomId/join',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<void> createRoom(String appointmentId) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/appointments/$appointmentId/telemedicine-room',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<void> registerLeave(String roomId) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/telemedicine-rooms/$roomId/leave',
      data: const {},
    );
  }

  @override
  Future<void> closeRoom(String roomId) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/telemedicine-rooms/$roomId/close',
      data: const {},
    );
  }

  @override
  Future<void> registerConnectionFailure(String roomId) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/telemedicine-rooms/$roomId/connection-failure',
      data: const {},
    );
  }

  @override
  Future<void> shareFile(String roomId, String clinicalDocumentId) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/telemedicine-rooms/$roomId/files',
      data: {'clinicalDocumentId': clinicalDocumentId},
    );
  }

  @override
  Future<TelemedicineActivity> activity(String roomId) async {
    final response = await _client.get<Map<String, dynamic>>(
      'appointments/telemedicine-rooms/$roomId/activity',
    );
    final data = response.data ?? const {};
    final participants = data['participants'],
        events = data['events'],
        files = data['files'];
    return TelemedicineActivity(
      participants: participants is List
          ? participants
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => TelemedicineParticipant(
                    userId: item['userId'] as String,
                    name: item['name'] as String? ?? 'Participante',
                    connectionFailures: item['connectionFailures'] as int,
                    joinedAt: item['joinedAt'] == null
                        ? null
                        : DateTime.parse(item['joinedAt'] as String).toLocal(),
                    leftAt: item['leftAt'] == null
                        ? null
                        : DateTime.parse(item['leftAt'] as String).toLocal(),
                  ),
                )
                .toList()
          : const [],
      events: events is List
          ? events
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => TelemedicineEvent(
                    id: item['id'] as String,
                    eventType: item['eventType'] as String,
                    createdAt: DateTime.parse(
                      item['createdAt'] as String,
                    ).toLocal(),
                  ),
                )
                .toList()
          : const [],
      files: files is List
          ? files
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => TelemedicineSharedFile(
                    id: item['id'] as String,
                    clinicalDocumentId: item['clinicalDocumentId'] as String,
                    documentType: item['documentType'] as String,
                    fileName: item['fileName'] as String?,
                    fileUrl: item['fileUrl'] as String,
                  ),
                )
                .toList()
          : const [],
    );
  }
}
