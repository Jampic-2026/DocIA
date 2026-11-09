import 'partner_summary.dart';

abstract interface class PartnersRepository {
  Future<List<PartnerSummary>> list();
  Future<List<Map<String, dynamic>>> diagnosticOrders();
  Future<void> createDiagnosticOrder({
    required String patientId,
    String? appointmentId,
    String? partnerId,
    required String orderType,
    required String description,
  });
}
