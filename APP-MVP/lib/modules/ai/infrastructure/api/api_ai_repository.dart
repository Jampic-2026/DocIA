import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/ai_repository.dart';

class ApiAiRepository implements AiRepository {
  ApiAiRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<AiReply> send({
    required String message,
    String? conversationId,
    bool useClinicalContext = false,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'ai/messages',
      data: {
        'message': message,
        'useClinicalContext': useClinicalContext,
        if (conversationId != null) 'conversationId': conversationId,
      },
    );
    final json = response.data!;
    return AiReply(
      conversationId: json['conversationId'] as String,
      message: json['message'] as String,
      riskLevel: json['riskLevel'] as String,
      recommendedAction: json['recommendedAction'] as String?,
      coinCost: int.tryParse(json['coinCost']?.toString() ?? ''),
      balance: int.tryParse(json['balance']?.toString() ?? ''),
      assessmentId: json['assessmentId'] as String?,
      classificationStatus: json['classificationStatus'] as String?,
      questions: (json['questions'] as List? ?? []).cast<String>(),
    );
  }

  @override
  Future<AiVoiceSession> startVoiceSession({String? topic}) async {
    final response = await _client.post<Map<String, dynamic>>(
      'ai/voice-sessions',
      data: {if (topic != null && topic.trim().isNotEmpty) 'topic': topic},
    );
    final json = response.data ?? const {};
    return AiVoiceSession(
      id: json['id'] as String,
      meetingUrl: json['meetingUrl'] as String,
      maxBillableMinutes: int.parse(json['maxBillableMinutes'].toString()),
      warningAtMinutes: int.parse(json['warningAtMinutes'].toString()),
      cutoffAtMinutes: int.parse(json['cutoffAtMinutes'].toString()),
      costPerStartedMinute: int.parse(json['costPerStartedMinute'].toString()),
      message: json['message'] as String? ?? '',
    );
  }

  @override
  Future<AiVoiceSessionResult> endVoiceSession(String sessionId) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'ai/voice-sessions/end',
      data: {'sessionId': sessionId},
    );
    final json = response.data ?? const {};
    return AiVoiceSessionResult(
      id: json['id'] as String,
      billedMinutes: int.parse(json['billedMinutes'].toString()),
      coinCost: int.parse(json['coinCost'].toString()),
      cutoffReached: json['cutoffReached'] == true,
    );
  }

  @override
  Future<List<AiConversation>> conversations() async {
    final response = await _client.get<Map<String, dynamic>>(
      'ai/ai-conversations',
    );
    final items = response.data?['items'];
    return items is List
        ? items
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => AiConversation(
                  id: item['id'] as String,
                  title: item['title'] as String? ?? 'Conversación',
                  status: item['status'] as String,
                  createdAt: DateTime.parse(
                    item['createdAt'] as String,
                  ).toLocal(),
                  lastMessage: item['lastMessage'] as String?,
                ),
              )
              .toList()
        : const [];
  }

  @override
  Future<List<AiStoredMessage>> messages(String conversationId) async {
    final response = await _client.get<Map<String, dynamic>>(
      'ai/ai-conversations/$conversationId/messages',
    );
    final items = response.data?['items'];
    return items is List
        ? items
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => AiStoredMessage(
                  text: item['message'] as String,
                  sender: item['sender'] as String,
                  safetyFlags:
                      (item['safetyFlags'] as Map<String, dynamic>?) ??
                      const {},
                  createdAt: DateTime.parse(
                    item['createdAt'] as String,
                  ).toLocal(),
                ),
              )
              .toList()
        : const [];
  }

  @override
  Future<void> close(String conversationId) async {
    await _client.patch<Map<String, dynamic>>(
      'ai/ai-conversations/$conversationId/close',
    );
  }
}
