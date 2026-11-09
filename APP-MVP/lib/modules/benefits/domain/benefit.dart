class Benefit {
  const Benefit({
    required this.id,
    required this.code,
    required this.name,
    required this.benefitType,
    required this.usedCount,
    required this.available,
    required this.partnerNames,
    required this.isStackable,
    this.description,
    this.discountPercent,
    this.discountAmount,
    this.discountCoinAmount,
    this.maxUsesPerUser,
    this.validUntil,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String benefitType;
  final double? discountPercent;
  final double? discountAmount;
  final int? discountCoinAmount;
  final int? maxUsesPerUser;
  final int usedCount;
  final bool available;
  final bool isStackable;
  final DateTime? validUntil;
  final List<String> partnerNames;

  factory Benefit.fromJson(Map<String, dynamic> json) {
    double? decimal(Object? value) =>
        value == null ? null : double.tryParse(value.toString());
    return Benefit(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      benefitType: json['benefitType'] as String,
      discountPercent: decimal(json['discountPercent']),
      discountAmount: decimal(json['discountAmount']),
      discountCoinAmount: int.tryParse(
        json['discountCoinAmount']?.toString() ?? '',
      ),
      maxUsesPerUser: json['maxUsesPerUser'] as int?,
      usedCount: json['usedCount'] as int? ?? 0,
      available: json['available'] as bool? ?? false,
      isStackable: json['isStackable'] as bool? ?? false,
      validUntil: json['validUntil'] is String
          ? DateTime.tryParse(json['validUntil'] as String)
          : null,
      partnerNames: (json['partnerNames'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }
}

class BenefitUsage {
  const BenefitUsage({
    required this.id,
    required this.benefitName,
    required this.discountApplied,
    required this.coinDiscountApplied,
    required this.status,
    required this.usedAt,
  });

  final String id;
  final String benefitName;
  final double discountApplied;
  final int coinDiscountApplied;
  final String status;
  final DateTime usedAt;

  factory BenefitUsage.fromJson(Map<String, dynamic> json) {
    return BenefitUsage(
      id: json['id'] as String,
      benefitName: json['benefitName'] as String,
      discountApplied: double.tryParse(json['discountApplied'].toString()) ?? 0,
      coinDiscountApplied:
          int.tryParse(json['coinDiscountApplied'].toString()) ?? 0,
      status: json['status'] as String,
      usedAt: DateTime.parse(json['usedAt'] as String).toLocal(),
    );
  }
}
