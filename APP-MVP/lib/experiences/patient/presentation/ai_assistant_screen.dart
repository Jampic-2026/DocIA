import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/authorization/permission_codes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../modules/ai/application/ai_assistant_controller.dart';
import '../../../modules/ai/domain/ai_message.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/consents/application/consents_controller.dart';
import '../../../modules/guidance/application/guidance_controller.dart';
import '../../../modules/guidance/presentation/support_calls_screen.dart';
import 'emergency_screen.dart';
import 'doctor_directory_screen.dart';

/// Pantalla del asistente conversacional de IA (orientación preliminar).
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _useClinicalContext = false;

  static const _suggestions = [
    'Tengo dolor de cabeza',
    'Fiebre desde ayer',
    'Me duele el estómago',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    if (message.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu mensaje no puede superar 1000 caracteres.'),
        ),
      );
      return;
    }
    _controller.clear();
    await ref
        .read(aiAssistantProvider.notifier)
        .send(message, useClinicalContext: _useClinicalContext);
    final remaining = ref.read(aiAssistantProvider).remainingCoins;
    if (mounted && remaining != null && remaining <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remaining == 0
                ? 'Te quedaste sin monedas para enviar más mensajes.'
                : 'Te quedan $remaining monedas. Estás cerca de agotar tu saldo.',
          ),
        ),
      );
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantProvider);
    final hasPermission = ref.watch(
      authControllerProvider.select(
        (auth) => auth.user?.can(PermissionCodes.aiUse) ?? false,
      ),
    );
    final consents = ref.watch(consentsControllerProvider);
    final hasAiConsent =
        consents.valueOrNull?.any(
          (consent) => consent.code == 'ai_orientation' && consent.isAccepted,
        ) ??
        false;
    final accessReady = hasPermission && hasAiConsent;
    final accessMessage = !hasPermission
        ? 'Tu cuenta no tiene habilitado el permiso para usar el asistente.'
        : consents.isLoading
        ? 'Estamos verificando tu consentimiento para usar el asistente.'
        : !hasAiConsent
        ? 'Debes aceptar el consentimiento de orientación con IA desde Mi cuenta antes de enviar mensajes.'
        : null;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Conversaciones',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showHistory(context),
          ),
        ],
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.tealGradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Asistente Doc IA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Orientación preliminar',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Aviso médico-legal.
          Container(
            width: double.infinity,
            color: AppColors.warning.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No reemplaza una valoración médica profesional.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.messages.length + (state.isTyping ? 1 : 0) + 2,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _contextChoice(state);
                }
                if (i == state.messages.length + (state.isTyping ? 1 : 0) + 1) {
                  return _orientationActions(state);
                }
                final messageIndex = i - 1;
                if (messageIndex == state.messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(message: state.messages[messageIndex]);
              },
            ),
          ),
          if (accessMessage != null)
            Container(
              width: double.infinity,
              color: AppColors.info.withValues(alpha: 0.10),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(accessMessage)),
                ],
              ),
            ),
          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              color: AppColors.danger.withValues(alpha: 0.10),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          // Sugerencias rápidas.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on_outlined,
                  size: 16,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '15 monedas gratis por semana. Chat: 1 moneda por mensaje.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: accessReady
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const SupportCallsScreen(patientMode: true),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text('Solicitar orientación humana'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (state.messages.length <= 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  for (final s in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ActionChip(
                        label: Text(s),
                        onPressed: accessReady ? () => _send(s) : null,
                      ),
                    ),
                ],
              ),
            ),
          if (state.isClosed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.read(aiAssistantProvider.notifier).startNew(),
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Iniciar nueva conversación'),
                  ),
                ),
              ),
            )
          else
            _Composer(
              controller: _controller,
              onSend: _send,
              enabled: accessReady && !state.isTyping,
            ),
        ],
      ),
    );
  }

  Widget _contextChoice(AiChatState state) => SwitchListTile(
    title: const Text('Usar mis antecedentes validados para esta orientación'),
    subtitle: const Text(
      'Opcional. Se evalúan en DocIA con reglas clínicas habilitadas; no se envían al proveedor del chat.',
    ),
    value: _useClinicalContext,
    onChanged: state.isTyping
        ? null
        : (value) => setState(() => _useClinicalContext = value),
  );

  Widget _orientationActions(AiChatState state) => state.assessmentId == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              if (state.recommendedAction == 'emergency')
                const Text(
                  'Posible urgencia: busca atención inmediata. No esperes al asistente.',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (state.classificationStatus == 'disabled')
                const Text(
                  'La clasificación clínica todavía no está habilitada. Puedes solicitar atención profesional.',
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _orientation('emergency'),
                    icon: const Icon(Icons.emergency),
                    label: const Text('Solicitar emergencia'),
                  ),
                  TextButton.icon(
                    onPressed: () => _orientation('appointment'),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Buscar consulta'),
                  ),
                  TextButton.icon(
                    onPressed: () => _orientation('call_operator'),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Orientación humana'),
                  ),
                  TextButton(
                    onPressed: () => _orientation('declined'),
                    child: const Text('Por ahora no'),
                  ),
                ],
              ),
            ],
          ),
        );

  Future<void> _orientation(String action) async {
    final id = ref.read(aiAssistantProvider).assessmentId;
    if (id == null) return;
    try {
      await ref.read(guidanceRepositoryProvider).decision(id, action);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la decisión: $error')),
        );
      }
    }
    if (!mounted) return;
    if (action == 'declined') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puedes solicitar atención cuando lo necesites.'),
        ),
      );
      return;
    }
    final Widget screen = action == 'emergency'
        ? EmergencyScreen(assessmentId: id)
        : action == 'appointment'
        ? DoctorDirectoryScreen(assessmentId: id)
        : SupportCallsScreen(patientMode: true, assessmentId: id);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) => ref
            .watch(aiConversationsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (items) => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'Conversaciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (items.isEmpty)
                    const Text('No tienes conversaciones guardadas.')
                  else
                    for (final item in items)
                      ListTile(
                        leading: Icon(
                          item.status == 'active'
                              ? Icons.chat_bubble_outline
                              : Icons.archive_outlined,
                        ),
                        title: Text(item.title),
                        subtitle: Text(
                          item.lastMessage ?? 'Sin mensajes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: item.status == 'active'
                            ? IconButton(
                                tooltip: 'Cerrar conversación',
                                icon: const Icon(Icons.archive_outlined),
                                onPressed: () async {
                                  await ref
                                      .read(aiRepositoryProvider)
                                      .close(item.id);
                                  ref.invalidate(aiConversationsProvider);
                                },
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(aiAssistantProvider.notifier)
                              .load(item.id, isClosed: item.status != 'active');
                        },
                      ),
                ],
              ),
            ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.navy : scheme.surface,
          border: isUser ? null : Border.all(color: scheme.outline),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isUser ? AppRadius.lg : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppRadius.lg),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? AppColors.white : scheme.onSurface,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_Dot(), _Dot(), _Dot()],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.teal,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? onSend : null,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Describe tus síntomas...'
                      : 'Asistente no habilitado',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: enabled ? () => onSend(controller.text) : null,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
