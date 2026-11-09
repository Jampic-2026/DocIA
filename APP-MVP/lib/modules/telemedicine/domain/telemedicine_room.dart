class TelemedicineRoom {
  const TelemedicineRoom({
    required this.id,
    required this.appointmentId,
    required this.meetingUrl,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.professionalName,
    required this.specialty,
  });

  final String id;
  final String appointmentId;
  final String meetingUrl;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String professionalName;
  final String? specialty;
}
