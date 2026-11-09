import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/appointment.dart';
import '../../domain/appointments_repository.dart';
import '../../domain/appointment_care_actions.dart';
import 'appointment_dto.dart';

class ApiAppointmentsRepository implements AppointmentsRepository {
  ApiAppointmentsRepository(this._client);

  final AuthenticatedApiClient _client;
  @override
  Future<void> markNoShow(
    String appointmentId, {
    required String reason,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'appointments/appointments/$appointmentId/no-show',
      data: {'reason': reason},
    );
  }

  @override
  Future<List<Appointment>> list() async {
    final response = await _client.get<Map<String, dynamic>>(
      'appointments/appointments',
    );
    final data = response.data;
    final items = data?['items'];

    if (items is! List) {
      throw const FormatException(
        'La respuesta de citas no contiene una lista válida.',
      );
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(AppointmentDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  Future<Appointment> create(CreateAppointmentCommand command) async {
    final response = await _client.post<Map<String, dynamic>>(
      'appointments/appointments',
      data: {
        'professionalId': command.professionalId,
        if (command.serviceId != null) 'serviceId': command.serviceId,
        if (command.patientId != null) 'patientId': command.patientId,
        'specialtyId': command.specialtyId,
        'modality': switch (command.modality) {
          AppointmentModality.inPerson => 'in_person',
          AppointmentModality.telemedicine => 'telemedicine',
          AppointmentModality.homeVisit => 'home_visit',
        },
        'startAt': command.startAt.toUtc().toIso8601String(),
        'endAt': command.endAt.toUtc().toIso8601String(),
        if (command.reason?.trim().isNotEmpty ?? false)
          'reason': command.reason!.trim(),
      },
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('La cita creada no tiene un formato válido.');
    }
    return AppointmentDto.fromJson(data).toDomain();
  }

  @override
  Future<Appointment> cancel(String appointmentId, {String? reason}) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'appointments/appointments/$appointmentId/cancel',
      data: {if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim()},
    );
    return AppointmentDto.fromJson(response.data!).toDomain();
  }

  @override
  Future<Appointment> reschedule(
    String appointmentId, {
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'appointments/appointments/$appointmentId/reschedule',
      data: {
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
      },
    );
    return AppointmentDto.fromJson(response.data!).toDomain();
  }

  @override
  Future<AppointmentCareActions> careActions() async {
    final response = await _client.get<Map<String, dynamic>>(
      'appointments/appointment-followups',
    );
    final data = response.data ?? const {};
    final followups = data['followups'],
        referrals = data['referrals'],
        ratings = data['ratings'];
    return AppointmentCareActions(
      followups: followups is List
          ? followups
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => AppointmentFollowup(
                    id: item['id'] as String,
                    sourceAppointmentId: item['sourceAppointmentId'] as String,
                    professionalName: item['professionalName'] as String,
                    status: item['status'] as String,
                    dueAt: item['dueAt'] == null
                        ? null
                        : DateTime.parse(item['dueAt'] as String).toLocal(),
                    instructions: item['instructions'] as String?,
                  ),
                )
                .toList()
          : const [],
      referrals: referrals is List
          ? referrals
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => MedicalReferral(
                    id: item['id'] as String,
                    specialty: item['specialty'] as String,
                    reason: item['reason'] as String,
                    priority: item['priority'] as String,
                    referralType: item['referralType'] as String,
                    status: item['status'] as String,
                    professionalName: item['professionalName'] as String,
                    validUntil: item['validUntil'] == null
                        ? null
                        : DateTime.parse(
                            item['validUntil'] as String,
                          ).toLocal(),
                  ),
                )
                .toList()
          : const [],
      ratings: ratings is List
          ? ratings
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => AppointmentRating(
                    id: item['id'] as String,
                    appointmentId: item['appointmentId'] as String,
                    rating: item['rating'] as int,
                    comment: item['comment'] as String?,
                  ),
                )
                .toList()
          : const [],
    );
  }

  @override
  Future<void> rate(
    String appointmentId, {
    required int rating,
    String? comment,
    bool publicComment = false,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/appointments/$appointmentId/rating',
      data: {
        'rating': rating,
        'publicComment': publicComment,
        'comment': comment,
      },
    );
  }

  @override
  Future<void> createReferral({
    required String patientId,
    required String specialtyId,
    required String reason,
    required String priority,
    required String referralType,
    DateTime? validUntil,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'appointments/referrals',
      data: {
        'patientId': patientId,
        'specialtyId': specialtyId,
        'reason': reason,
        'priority': priority,
        'referralType': referralType,
        if (validUntil != null) 'validUntil': validUntil.toIso8601String(),
      },
    );
  }
}
