import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/authorization/permission_codes.dart';
import '../../../core/network/api_client_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/ai_message.dart';
import '../domain/ai_repository.dart';
import '../infrastructure/api/api_ai_repository.dart';

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => ApiAiRepository(ref.watch(authenticatedApiClientProvider)),
);
final aiConversationsProvider = FutureProvider<List<AiConversation>>(
  (ref) => ref.watch(aiRepositoryProvider).conversations(),
);

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isTyping = false,
    this.conversationId,
    this.errorMessage,
    this.isClosed = false,
    this.remainingCoins,
    this.riskLevel,
    this.recommendedAction,
    this.assessmentId,
    this.classificationStatus,
  });

  final List<AiMessage> messages;
  final bool isTyping;
  final String? conversationId;
  final String? errorMessage;
  final bool isClosed;
  final int? remainingCoins;
  final String? riskLevel,
      recommendedAction,
      assessmentId,
      classificationStatus;

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? isTyping,
    String? conversationId,
    String? errorMessage,
    bool clearError = false,
    bool? isClosed,
    int? remainingCoins,
    String? riskLevel,
    String? recommendedAction,
    String? assessmentId,
    String? classificationStatus,
  }) => AiChatState(
    messages: messages ?? this.messages,
    isTyping: isTyping ?? this.isTyping,
    conversationId: conversationId ?? this.conversationId,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    isClosed: isClosed ?? this.isClosed,
    remainingCoins: remainingCoins ?? this.remainingCoins,
    riskLevel: riskLevel ?? this.riskLevel,
    recommendedAction: recommendedAction ?? this.recommendedAction,
    assessmentId: assessmentId ?? this.assessmentId,
    classificationStatus: classificationStatus ?? this.classificationStatus,
  );
}

class AiAssistantController extends Notifier<AiChatState> {
  int _generation = 0;
  @override
  AiChatState build() => AiChatState(
    messages: [
      AiMessage(
        text:
            '¡Hola! Soy tu asistente de orientación de Doc IA. Cuéntame qué '
            'síntomas o molestias presentas. Esta orientación es preliminar '
            'y no reemplaza una consulta médica.',
        isUser: false,
        time: DateTime.now(),
      ),
    ],
  );

  Future<void> send(String text, {bool useClinicalContext = false}) async {
    final value = text.trim();
    if (value.isEmpty || state.isTyping) return;
    final canUseAssistant =
        ref.read(authControllerProvider).user?.can(PermissionCodes.aiUse) ??
        false;
    if (!canUseAssistant) {
      state = state.copyWith(
        errorMessage:
            'Tu cuenta no tiene habilitado el permiso para usar el asistente.',
      );
      return;
    }
    state = state.copyWith(
      messages: [
        ...state.messages,
        AiMessage(text: value, isUser: true, time: DateTime.now()),
      ],
      isTyping: true,
      clearError: true,
    );
    final generation = _generation;
    try {
      final reply = await ref
          .read(aiRepositoryProvider)
          .send(
            message: value,
            conversationId: state.conversationId,
            useClinicalContext: useClinicalContext,
          );
      if (generation != _generation) return;
      state = AiChatState(
        messages: [
          ...state.messages,
          AiMessage(text: reply.message, isUser: false, time: DateTime.now()),
        ],
        conversationId: reply.conversationId,
        isTyping: false,
        remainingCoins: reply.balance,
        riskLevel: reply.riskLevel,
        recommendedAction: reply.recommendedAction,
        assessmentId: reply.assessmentId,
        classificationStatus: reply.classificationStatus,
      );
      ref.invalidate(aiConversationsProvider);
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isTyping: false, errorMessage: error.toString());
    }
  }

  Future<void> load(String conversationId, {required bool isClosed}) async {
    final generation = ++_generation;
    state = state.copyWith(isTyping: true, clearError: true);
    try {
      final stored = await ref
          .read(aiRepositoryProvider)
          .messages(conversationId);
      if (generation != _generation) return;
      final safety =
          stored
              .where((item) => item.sender == 'assistant')
              .lastOrNull
              ?.safetyFlags ??
          const <String, dynamic>{};
      state = AiChatState(
        conversationId: conversationId,
        isClosed: isClosed,
        riskLevel: safety['riskLevel'] as String?,
        recommendedAction: safety['recommendedAction'] as String?,
        assessmentId: safety['assessmentId'] as String?,
        classificationStatus: safety['classificationStatus'] as String?,
        messages: stored
            .where((item) => item.sender != 'system')
            .map(
              (item) => AiMessage(
                text: item.text,
                isUser: item.sender == 'user',
                time: item.createdAt,
              ),
            )
            .toList(),
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isTyping: false, errorMessage: error.toString());
    }
  }

  void startNew() {
    _generation++;
    state = build();
  }

  Future<void> closeCurrent() async {
    final id = state.conversationId;
    if (id == null) {
      startNew();
      return;
    }
    await ref.read(aiRepositoryProvider).close(id);
    ref.invalidate(aiConversationsProvider);
    if (state.conversationId == id) startNew();
  }
}

final aiAssistantProvider =
    NotifierProvider<AiAssistantController, AiChatState>(
      AiAssistantController.new,
    );
