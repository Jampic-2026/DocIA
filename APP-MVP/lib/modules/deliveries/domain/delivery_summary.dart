class DeliverySummary {
  const DeliverySummary({
    required this.id,
    required this.status,
    required this.title,
    this.recipient,
    this.address,
    this.scheduledAt,
  });

  final String id;
  final String status;
  final String title;
  final String? recipient;
  final String? address;
  final DateTime? scheduledAt;
}
