abstract interface class AiRepository {
  Future<AiReply> send({
    required String message,
    String? conversationId,
    bool useClinicalContext = false,
  });
  Future<List<AiConversation>> conversations();
  Future<List<AiStoredMessage>> messages(String conversationId);
  Future<void> close(String conversationId);
  Future<AiVoiceSession> startVoiceSession({String? topic});
  Future<AiVoiceSessionResult> endVoiceSession(String sessionId);
}

class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.lastMessage,
  });
  final String id, title, status;
  final DateTime createdAt;
  final String? lastMessage;
}

class AiStoredMessage {
  const AiStoredMessage({
    required this.text,
    required this.sender,
    required this.createdAt,
    this.safetyFlags = const {},
  });
  final String text, sender;
  final DateTime createdAt;
  final Map<String, dynamic> safetyFlags;
}

class AiReply {
  const AiReply({
    required this.conversationId,
    required this.message,
    required this.riskLevel,
    this.recommendedAction,
    this.coinCost,
    this.balance,
    this.assessmentId,
    this.classificationStatus,
    this.questions = const [],
  });

  final String conversationId;
  final String message;
  final String riskLevel;
  final String? recommendedAction;
  final int? coinCost;
  final int? balance;
  final String? assessmentId, classificationStatus;
  final List<String> questions;
}

class AiVoiceSession {
  const AiVoiceSession({
    required this.id,
    required this.meetingUrl,
    required this.maxBillableMinutes,
    required this.warningAtMinutes,
    required this.cutoffAtMinutes,
    required this.costPerStartedMinute,
    required this.message,
  });

  final String id;
  final String meetingUrl;
  final int maxBillableMinutes;
  final int warningAtMinutes;
  final int cutoffAtMinutes;
  final int costPerStartedMinute;
  final String message;
}

class AiVoiceSessionResult {
  const AiVoiceSessionResult({
    required this.id,
    required this.billedMinutes,
    required this.coinCost,
    required this.cutoffReached,
  });

  final String id;
  final int billedMinutes;
  final int coinCost;
  final bool cutoffReached;
}
