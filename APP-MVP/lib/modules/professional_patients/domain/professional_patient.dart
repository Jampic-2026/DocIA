class ProfessionalPatient {
  const ProfessionalPatient({
    required this.id,
    required this.fullName,
    required this.age,
    required this.latestAssessment,
    required this.lastVisitAt,
    required this.appointmentId,
  });

  final String id;
  final String fullName;
  final int? age;
  final String? latestAssessment;
  final DateTime? lastVisitAt;
  final String? appointmentId;

  factory ProfessionalPatient.fromJson(Map<String, dynamic> json) {
    final lastVisit = json['lastVisitAt'] as String?;
    return ProfessionalPatient(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      age: json['age'] as int?,
      latestAssessment: json['latestAssessment'] as String?,
      lastVisitAt: lastVisit == null ? null : DateTime.parse(lastVisit),
      appointmentId: json['appointmentId'] as String?,
    );
  }
}
