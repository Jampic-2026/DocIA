class EmergencyEvent {
  const EmergencyEvent({
    required this.id,
    required this.status,
    required this.riskLevel,
    required this.openedAt,
    this.description,
    this.manualAddress,
    this.latitude,
    this.longitude,
    this.assignedTeamName,
    this.assignedTeamPhone,
    this.patientName,
    this.patientPhone,
    this.assignedProfessionalId,
    this.assignedOperatorId,
    this.reference,
    this.coverageAvailable,
    this.patientId,
    this.acceptedAt,
  });
  final String? patientId;
  final DateTime? acceptedAt;
  final String id;
  final String status;
  final String riskLevel;
  final String? description;
  final String? manualAddress;
  final double? latitude;
  final double? longitude;
  final String? assignedTeamName;
  final String? assignedTeamPhone;
  final String? patientName;
  final String? patientPhone;
  final String? assignedProfessionalId;
  final String? assignedOperatorId;
  final String? reference;
  final bool? coverageAvailable;
  final DateTime openedAt;

  bool get isActive =>
      !const {'closed', 'cancelled', 'false_alarm'}.contains(status);
}
