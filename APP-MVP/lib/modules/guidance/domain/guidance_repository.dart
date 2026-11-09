class SupportCall {
  const SupportCall({
    required this.id,
    required this.status,
    required this.priority,
    required this.reason,
    required this.requestedBy,
    this.professionalId,
    this.assignedUserId,
    this.resultNotes,
    this.durationSeconds,
  });
  final String id, status, priority, reason, requestedBy;
  final String? professionalId, assignedUserId, resultNotes;
  final int? durationSeconds;
}

class SupportStaff {
  const SupportStaff(
    this.id,
    this.name, {
    this.available = false,
    this.reasons = const [],
  });
  final String id, name;
  final bool available;
  final List<String> reasons;
}

abstract interface class GuidanceRepository {
  Future<List<SupportCall>> calls();
  Future<String> requestCall(
    String reason, {
    String? assessmentId,
    String? emergencyId,
  });
  Future<List<SupportStaff>> staff();
  Future<void> transition(
    String id,
    String action, {
    String? professionalId,
    String? notes,
  });
  Future<String> join(String id);
  Future<void> decision(String id, String decision, {String? relatedId});
  Future<Map<String, dynamic>> policy();
  Future<void> savePolicy(List<Map<String, dynamic>> rules);
  Future<void> approvePolicy(int revision, String reference);
}
