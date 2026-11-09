class AppNotification {
  const AppNotification({
    required this.id,
    required this.eventCode,
    required this.channel,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.readAt,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  final String id;
  final String eventCode;
  final String channel;
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? relatedEntityType, relatedEntityId;

  bool get isRead => readAt != null || status == 'read';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      eventCode: json['eventCode'] as String,
      channel: json['channel'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      status: json['status'] as String,
      relatedEntityType: json['relatedEntityType'] as String?,
      relatedEntityId: json['relatedEntityId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      readAt: json['readAt'] is String
          ? DateTime.parse(json['readAt'] as String).toLocal()
          : null,
    );
  }
}

class NotificationPreference {
  const NotificationPreference({
    required this.eventCode,
    required this.channel,
    required this.enabled,
  });

  final String eventCode;
  final String channel;
  final bool enabled;

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      eventCode: json['eventCode'] as String,
      channel: json['channel'] as String,
      enabled: json['enabled'] as bool,
    );
  }
}
