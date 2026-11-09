class Appointment {
  const Appointment({
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

  final String id;
  final String patientId;
  final String patientName;
  final String professionalId;
  final String professionalName;
  final String specialty;
  final DateTime startAt;
  final DateTime endAt;
  final AppointmentModality modality;
  final AppointmentStatus status;
  final String? reason;
}

enum AppointmentModality {
  inPerson,
  telemedicine,
  homeVisit,
}

enum AppointmentStatus {
  scheduled,
  confirmed,
  rescheduled,
  cancelled,
  inProgress,
  completed,
  noShow,
}
