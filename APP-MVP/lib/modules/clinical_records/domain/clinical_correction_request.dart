class ClinicalCorrectionRequest {
  const ClinicalCorrectionRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.entityType,
    required this.entityId,
    required this.requestedChange,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.recordTitle,
    this.resolution,
    this.resolvedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String entityType;
  final String entityId;
  final String? recordTitle;
  final String requestedChange;
  final String reason;
  final String status;
  final String? resolution;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}
