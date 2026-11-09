import '../../domain/appointment.dart';

class AppointmentDto {
  const AppointmentDto({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.professionalId,
    required this.professionalName,
    required this.specialty,
    required this.startAt,
    required this.endAt,
    required this.modality,
    required this.status,
    this.reason,
  });

  factory AppointmentDto.fromJson(Map<String, dynamic> json) {
    return AppointmentDto(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      patientName: json['patientName'] as String,
      professionalId: json['professionalId'] as String,
      professionalName: json['professionalName'] as String,
      specialty: json['specialty'] as String,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      modality: json['modality'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final String patientId;
  final String patientName;
  final String professionalId;
  final String professionalName;
  final String specialty;
  final DateTime startAt;
  final DateTime endAt;
  final String modality;
  final String status;
  final String? reason;

  Appointment toDomain() {
    return Appointment(
      id: id,
      patientId: patientId,
      patientName: patientName,
      professionalId: professionalId,
      professionalName: professionalName,
      specialty: specialty,
      startAt: startAt.toLocal(),
      endAt: endAt.toLocal(),
      modality: _modalityFrom(modality),
      status: _statusFrom(status),
      reason: reason,
    );
  }
}

AppointmentModality _modalityFrom(String value) => switch (value) {
      'telemedicine' => AppointmentModality.telemedicine,
      'home_visit' => AppointmentModality.homeVisit,
      'in_person' => AppointmentModality.inPerson,
      _ => throw FormatException('Modalidad de cita desconocida: $value'),
    };

AppointmentStatus _statusFrom(String value) => switch (value) {
      'scheduled' => AppointmentStatus.scheduled,
      'confirmed' => AppointmentStatus.confirmed,
      'rescheduled' => AppointmentStatus.rescheduled,
      'cancelled' => AppointmentStatus.cancelled,
      'in_progress' => AppointmentStatus.inProgress,
      'completed' => AppointmentStatus.completed,
      'no_show' => AppointmentStatus.noShow,
      _ => throw FormatException('Estado de cita desconocido: $value'),
    };
