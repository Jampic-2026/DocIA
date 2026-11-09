class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.concept,
    required this.chargeMode,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.coinAmount,
    this.amount,
    this.dueAt,
    this.serviceName,
    this.relatedEntityType,
    this.qrImageUrl,
    this.latestPaymentMethod,
    this.latestPaymentStatus,
    this.latestPaymentRejectionReason,
  });

  final String id;
  final String concept;
  final String chargeMode;
  final int? coinAmount;
  final double? amount;
  final String currency;
  final String status;
  final DateTime? dueAt;
  final DateTime createdAt;
  final String? serviceName;
  final String? relatedEntityType;
  final String? qrImageUrl;
  final String? latestPaymentMethod;
  final String? latestPaymentStatus;
  final String? latestPaymentRejectionReason;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      id: json['id'] as String,
      concept: json['concept'] as String,
      chargeMode: json['chargeMode'] as String,
      coinAmount: int.tryParse(json['coinAmount']?.toString() ?? ''),
      amount: double.tryParse(json['amount']?.toString() ?? ''),
      currency: json['currency'] as String,
      status: json['status'] as String,
      dueAt: json['dueAt'] is String
          ? DateTime.tryParse(json['dueAt'] as String)?.toLocal()
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      serviceName: json['serviceName'] as String?,
      relatedEntityType: json['relatedEntityType'] as String?,
      qrImageUrl: json['qrImageUrl'] as String?,
      latestPaymentMethod: json['latestPaymentMethod'] as String?,
      latestPaymentStatus: json['latestPaymentStatus'] as String?,
      latestPaymentRejectionReason:
          json['latestPaymentRejectionReason'] as String?,
    );
  }
}

class PaymentConfiguration {
  const PaymentConfiguration({
    this.qrImageUrl,
    this.qrAccountName,
    this.qrBankName,
    this.cashEnabled = false,
    this.stripeEnabled = false,
  });

  final String? qrImageUrl;
  final String? qrAccountName;
  final String? qrBankName;
  final bool cashEnabled;
  final bool stripeEnabled;

  bool get hasQr => qrImageUrl?.trim().isNotEmpty ?? false;

  factory PaymentConfiguration.fromJson(Map<String, dynamic> json) {
    String? value(String key) {
      final raw = json[key];
      if (raw == null) return null;
      final text = raw.toString().trim();
      if (text.isEmpty || text == 'null') return null;
      return text;
    }

    return PaymentConfiguration(
      qrImageUrl: value('payments.qr_image_url'),
      qrAccountName: value('payments.qr_account_name'),
      qrBankName: value('payments.qr_bank_name'),
      cashEnabled:
          json['payments.cash_enabled'] == true ||
          json['payments.cash_enabled']?.toString() == 'true',
      stripeEnabled: json['stripeEnabled'] == true,
    );
  }
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.paymentOrderId,
    required this.concept,
    required this.method,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.transactionReference,
    this.receiptUrl,
    this.paidAt,
    this.rejectionReason,
  });

  final String id;
  final String paymentOrderId;
  final String concept;
  final String method;
  final double amount;
  final String currency;
  final String status;
  final String? transactionReference;
  final String? receiptUrl;
  final DateTime? paidAt;
  final String? rejectionReason;
  final DateTime createdAt;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      paymentOrderId: json['paymentOrderId'] as String,
      concept: json['concept'] as String,
      method: json['method'] as String,
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] as String,
      status: json['status'] as String,
      transactionReference: json['transactionReference'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      paidAt: json['paidAt'] is String
          ? DateTime.tryParse(json['paidAt'] as String)?.toLocal()
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

class StripePaymentIntent {
  const StripePaymentIntent({
    required this.paymentId,
    required this.paymentIntentId,
    required this.clientSecret,
    required this.amount,
    required this.currency,
  });

  final String paymentId;
  final String paymentIntentId;
  final String clientSecret;
  final double amount;
  final String currency;

  factory StripePaymentIntent.fromJson(Map<String, dynamic> json) {
    return StripePaymentIntent(
      paymentId: json['paymentId'] as String,
      paymentIntentId: json['paymentIntentId'] as String,
      clientSecret: json['clientSecret'] as String,
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] as String,
    );
  }
}

class StripeCheckoutSession {
  const StripeCheckoutSession({
    required this.paymentId,
    required this.checkoutSessionId,
    required this.url,
    required this.amount,
    required this.currency,
  });

  final String paymentId;
  final String checkoutSessionId;
  final String url;
  final double amount;
  final String currency;

  factory StripeCheckoutSession.fromJson(Map<String, dynamic> json) {
    return StripeCheckoutSession(
      paymentId: json['paymentId'] as String,
      checkoutSessionId: json['checkoutSessionId'] as String,
      url: json['url'] as String,
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] as String,
    );
  }
}
