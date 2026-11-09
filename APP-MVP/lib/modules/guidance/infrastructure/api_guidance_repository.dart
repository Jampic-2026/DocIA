import '../../../core/network/authenticated_api_client.dart';
import '../domain/guidance_repository.dart';

class ApiGuidanceRepository implements GuidanceRepository {
  ApiGuidanceRepository(this.client);
  final AuthenticatedApiClient client;
  @override
  Future<List<SupportCall>> calls() async {
    final response = await client.get<Map<String, dynamic>>(
      'guidance/support-calls',
    );
    return (response.data?['items'] as List? ?? [])
        .map(
          (item) => SupportCall(
            id: item['id'] as String,
            status: item['status'] as String,
            priority: item['priority'] as String,
            reason: item['reason'] as String? ?? '',
            requestedBy: item['requestedBy'] as String,
            professionalId: item['professionalId'] as String?,
            assignedUserId: item['assignedUserId'] as String?,
            resultNotes: item['resultNotes'] as String?,
            durationSeconds: item['durationSeconds'] as int?,
          ),
        )
        .toList();
  }

  @override
  Future<String> requestCall(
    String reason, {
    String? assessmentId,
    String? emergencyId,
  }) async {
    final response = await client.post<Map<String, dynamic>>(
      'guidance/support-calls',
      data: {
        'reason': reason,
        if (assessmentId != null) 'assessmentId': assessmentId,
        if (emergencyId != null) 'emergencyId': emergencyId,
      },
    );
    return response.data!['id'] as String;
  }

  @override
  Future<List<SupportStaff>> staff() async {
    final response = await client.get<Map<String, dynamic>>(
      'guidance/support-staff',
    );
    return (response.data?['items'] as List? ?? [])
        .map(
          (item) => SupportStaff(
            item['id'] as String,
            item['name'] as String,
            available: item['available'] == true,
            reasons: (item['reasons'] as List? ?? []).cast<String>(),
          ),
        )
        .toList();
  }

  @override
  Future<void> transition(
    String id,
    String action, {
    String? professionalId,
    String? notes,
  }) async {
    await client.patch<Map<String, dynamic>>(
      'guidance/support-calls/$id',
      data: {
        'action': action,
        if (professionalId != null) 'professionalId': professionalId,
        if (notes != null) 'notes': notes,
      },
    );
  }

  @override
  Future<String> join(String id) async {
    final response = await client.post<Map<String, dynamic>>(
      'guidance/support-calls/$id/join',
      data: const <String, dynamic>{},
    );
    return response.data!['meetingUrl'] as String;
  }

  @override
  Future<void> decision(String id, String decision, {String? relatedId}) async {
    await client.post<Map<String, dynamic>>(
      'guidance/assessments/$id/decision',
      data: {
        'decision': decision,
        if (relatedId != null) 'relatedId': relatedId,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> policy() async =>
      (await client.get<Map<String, dynamic>>('guidance/risk-policy')).data!;
  @override
  Future<void> savePolicy(List<Map<String, dynamic>> rules) async {
    await client.patch<Map<String, dynamic>>(
      'guidance/risk-policy',
      data: {'rules': rules},
    );
  }

  @override
  Future<void> approvePolicy(int revision, String reference) async {
    await client.post<Map<String, dynamic>>(
      'guidance/risk-policy/approve',
      data: {'revision': revision, 'reference': reference},
    );
  }
}
