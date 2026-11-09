class ConsentPreference {
  const ConsentPreference({
    required this.code,
    required this.name,
    required this.description,
    required this.version,
    required this.isRequired,
    required this.status,
    this.acceptedAt,
    this.revokedAt,
  });

  final String code;
  final String name;
  final String? description;
  final String version;
  final bool isRequired;
  final String status;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  bool get isAccepted => status == 'accepted';

  factory ConsentPreference.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;

    return ConsentPreference(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      version: json['version'] as String,
      isRequired: json['isRequired'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      acceptedAt: parseDate(json['acceptedAt']),
      revokedAt: parseDate(json['revokedAt']),
    );
  }
}
