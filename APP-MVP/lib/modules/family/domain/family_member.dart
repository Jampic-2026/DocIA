class FamilyMember {
  const FamilyMember({
    required this.id,
    this.patientId,
    this.linkKind = 'outgoing',
    required this.fullName,
    required this.relationship,
    required this.isDependent,
    required this.status,
    required this.canViewHistory,
    required this.canBookAppointments,
    required this.canHandleEmergencies,
    this.age,
    this.birthDate,
    this.documentNumber,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.insuranceProvider,
    this.insuranceNumber,
    this.profileNotes,
  });

  final String id;
  final String? patientId;
  final String linkKind;
  final String fullName;
  final String relationship;
  final int? age;
  final String? birthDate;
  final String? documentNumber;
  final String? bloodType;
  final double? heightCm;
  final double? weightKg;
  final String? insuranceProvider;
  final String? insuranceNumber;
  final String? profileNotes;
  final bool isDependent;
  final String status;
  final bool canViewHistory;
  final bool canBookAppointments;
  final bool canHandleEmergencies;
}
