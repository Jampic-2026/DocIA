import 'emergency_event.dart';

abstract interface class EmergenciesRepository {
  Future<void> decideAssignment(
    String id, {
    required String decision,
    String? reason,
  });
  Future<void> recordCare(String id, EmergencyCareCommand command);
  Future<List<EmergencyCareRecord>> careHistory(String id);
  Future<List<EmergencyEvent>> list();
  Future<EmergencyEvent> create({
    String? patientId,
    required String riskLevel,
    String? description,
    String? manualAddress,
    double? latitude,
    double? longitude,
  });
  Future<EmergencyEvent> cancel(String id);
  Future<EmergencyEvent> assign(
    String id, {
    String? professionalId,
    String? operatorId,
  });
  Future<EmergencyEvent> updateStatus(
    String id, {
    required String status,
    String? notes,
  });
}

class EmergencyCareCommand {
  const EmergencyCareCommand({
    required this.careType,
    required this.notes,
    required this.symptoms,
    required this.assessment,
    this.procedures,
    this.referralDestination,
  });
  final String careType;
  final String notes;
  final List<String> symptoms;
  final String assessment;
  final String? procedures;
  final String? referralDestination;
}

class EmergencyCareRecord {
  const EmergencyCareRecord({
    required this.id,
    required this.careType,
    required this.notes,
    required this.createdAt,
    required this.content,
  });
  final String id;
  final String careType;
  final String notes;
  final DateTime createdAt;
  final Map<String, dynamic> content;
}
