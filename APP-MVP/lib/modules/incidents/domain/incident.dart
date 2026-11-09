class Incident {
  const Incident({
    required this.id,
    required this.module,
    required this.incidentType,
    required this.severity,
    required this.description,
    required this.status,
    required this.createdAt,
    this.resolution,
    this.resolvedAt,
  });

  final String id;
  final String module;
  final String incidentType;
  final String severity;
  final String description;
  final String status;
  final String? resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  bool get canClose => status == 'open' || status == 'pending';

  factory Incident.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;
    return Incident(
      id: json['id'] as String,
      module: json['module'] as String,
      incidentType: json['incidentType'] as String,
      severity: json['severity'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      resolution: json['resolution'] as String?,
      resolvedAt: date(json['resolvedAt']),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
