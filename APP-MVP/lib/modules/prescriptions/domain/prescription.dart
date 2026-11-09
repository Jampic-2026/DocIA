class Prescription {
  const Prescription({
    required this.id,
    required this.patientName,
    required this.professionalName,
    required this.status,
    required this.createdAt,
    required this.items,
    this.issuedAt,
    this.expiresAt,
  });
  final String id;
  final String patientName;
  final String professionalName;
  final String status;
  final DateTime createdAt;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final List<PrescriptionItem> items;
}

class PrescriptionItem {
  const PrescriptionItem({
    required this.id,
    required this.medicationName,
    this.dose,
    this.frequency,
    this.duration,
    this.instructions,
  });
  final String id;
  final String medicationName;
  final String? dose;
  final String? frequency;
  final String? duration;
  final String? instructions;
}
