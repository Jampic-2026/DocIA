class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.module,
    required this.action,
    required this.entityType,
    required this.actorName,
    required this.actorRole,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String module;
  final String action;
  final String? entityType;
  final String? actorName;
  final String? actorRole;
  final String? reason;
  final DateTime createdAt;

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: json['id'] as String,
        module: json['module'] as String,
        action: json['action'] as String,
        entityType: json['entityType'] as String?,
        actorName: json['actorName'] as String?,
        actorRole: json['actorRole'] as String?,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
