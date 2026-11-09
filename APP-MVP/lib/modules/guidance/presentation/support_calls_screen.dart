import '../../../core/widgets/app_action_row.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dialog_actions.dart';
import '../../auth/application/auth_controller.dart';
import '../application/guidance_controller.dart';
import '../domain/guidance_repository.dart';

class SupportCallsScreen extends ConsumerStatefulWidget {
  const SupportCallsScreen({
    super.key,
    this.assessmentId,
    this.emergencyId,
    this.patientMode = false,
    this.callId,
  });
  final String? assessmentId;
  final String? emergencyId;
  final String? callId;
  final bool patientMode;
  @override
  ConsumerState<SupportCallsScreen> createState() => _SupportCallsState();
}

class _SupportCallsState extends ConsumerState<SupportCallsScreen> {
  Timer? timer;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(supportCallsProvider);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<String?> text(String title) async {
    final controller = TextEditingController();
    try {
      return await showAppDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Confirmar',
                onCancel: () => Navigator.pop(context),
                onConfirm: () {
                  if (controller.text.trim().length >= 3) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
      ref.invalidate(supportCallsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> assign(SupportCall call) async {
    final staff = await ref.read(guidanceRepositoryProvider).staff();
    if (!mounted) return;
    final available = staff.where((person) => person.available).toList();
    final unavailable = staff.where((person) => !person.available).toList();
    final id = await showAppDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar personal clínico'),
        content: SizedBox(
          width: 560,
          height: 400,
          child: DefaultTabController(
            length: 2,
            initialIndex: available.isEmpty && unavailable.isNotEmpty ? 1 : 0,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Disponibles (${available.length})'),
                    Tab(text: 'No disponibles (${unavailable.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _staffList(context, available, selectable: true),
                      _staffList(context, unavailable, selectable: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (id != null) {
      await ref
          .read(guidanceRepositoryProvider)
          .transition(call.id, 'assign', professionalId: id);
    }
  }

  Widget _staffList(
    BuildContext dialogContext,
    List<SupportStaff> staff, {
    required bool selectable,
  }) {
    if (staff.isEmpty) {
      return Center(
        child: Text(
          selectable
              ? 'No hay personal disponible para asignar en este momento.'
              : 'No hay profesionales no disponibles.',
        ),
      );
    }
    return ListView(
      children: [
        for (final person in staff)
          ListTile(
            title: Text(person.name),
            subtitle: Text(
              selectable
                  ? 'Disponible para asignación'
                  : person.reasons.isEmpty
                  ? 'Disponibilidad no confirmada; no se puede asignar.'
                  : person.reasons.join('\n'),
            ),
            enabled: selectable,
            trailing: Icon(
              selectable ? Icons.chevron_right : Icons.lock_outline,
            ),
            onTap: selectable
                ? () => Navigator.pop(dialogContext, person.id)
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final calls = ref.watch(supportCallsProvider),
        user = ref.watch(authControllerProvider).user;
    final coordinator =
        (user?.permissions.contains('emergencies.manage') ?? false) &&
        (user?.roles.any(
              (role) =>
                  ['admin', 'operator', 'clinical_supervisor'].contains(role),
            ) ??
            false);
    return Scaffold(
      appBar: AppBar(title: const Text('Orientación humana')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Atención humana por Google Meet. Ante una urgencia, solicita atención de emergencia sin esperar esta llamada.',
            ),
          ),
          if (widget.patientMode)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final reason = await text('Motivo de orientación');
                      if (reason != null) {
                        await ref
                            .read(guidanceRepositoryProvider)
                            .requestCall(
                              reason,
                              assessmentId: widget.assessmentId,
                              emergencyId: widget.emergencyId,
                            );
                      }
                    }),
              icon: const Icon(Icons.support_agent),
              label: const Text(
                'Solicitar orientación',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: calls.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error.toString()),
                    TextButton(
                      onPressed: () => ref.invalidate(supportCallsProvider),
                      child: const Text(
                        'Reintentar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              data: (items) {
                final visibleItems = items.where((call) {
                  if (user == null) return false;
                  if (widget.patientMode) return call.requestedBy == user.id;
                  if (coordinator) return true;
                  return call.assignedUserId == user.id;
                }).toList();
                if (widget.callId != null) {
                  final index = visibleItems.indexWhere(
                    (call) => call.id == widget.callId,
                  );
                  if (index > 0) {
                    visibleItems.insert(0, visibleItems.removeAt(index));
                  }
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final _ = await ref.refresh(supportCallsProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (visibleItems.isEmpty)
                        const Text(
                          'No hay solicitudes visibles para tu cuenta.',
                        ),
                      for (final call in visibleItems)
                        Card(
                          color: call.id == widget.callId
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_statusLabel(call.status)} · ${_priorityLabel(call.priority)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(call.reason),
                                if (call.status == 'pending')
                                  const Text(
                                    'El tiempo estimado de espera todavía no está disponible.',
                                  ),
                                if (call.resultNotes != null)
                                  Text('Resultado: ${call.resultNotes}'),
                                if (call.durationSeconds != null)
                                  Text(
                                    'Duración registrada: ${call.durationSeconds} s',
                                  ),
                                AppActionRow(
                                  children: [
                                    if (coordinator &&
                                        [
                                          'pending',
                                          'assigned',
                                        ].contains(call.status))
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => run(() => assign(call)),
                                        child: const Text(
                                          'Asignar',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (call.assignedUserId == user?.id &&
                                        call.status == 'assigned') ...[
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => run(
                                                () => ref
                                                    .read(
                                                      guidanceRepositoryProvider,
                                                    )
                                                    .transition(
                                                      call.id,
                                                      'start',
                                                    ),
                                              ),
                                        child: const Text(
                                          'Aceptar e iniciar',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => run(() async {
                                                final reason = await text(
                                                  'Motivo de rechazo',
                                                );
                                                if (reason != null) {
                                                  await ref
                                                      .read(
                                                        guidanceRepositoryProvider,
                                                      )
                                                      .transition(
                                                        call.id,
                                                        'reject',
                                                        notes: reason,
                                                      );
                                                }
                                              }),
                                        child: const Text(
                                          'Rechazar',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    if (call.status == 'in_progress' &&
                                        (call.assignedUserId == user?.id ||
                                            call.requestedBy == user?.id))
                                      FilledButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => run(() async {
                                                final url = await ref
                                                    .read(
                                                      guidanceRepositoryProvider,
                                                    )
                                                    .join(call.id);
                                                if (!await launchUrl(
                                                  Uri.parse(url),
                                                  mode: LaunchMode
                                                      .platformDefault,
                                                )) {
                                                  throw Exception(
                                                    'No se pudo abrir Meet.',
                                                  );
                                                }
                                              }),
                                        icon: const Icon(Icons.videocam_rounded),
                                        label: const Text(
                                          'Ingresar a Meet',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (call.status == 'in_progress' &&
                                        call.assignedUserId == user?.id)
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => run(() async {
                                                final notes = await text(
                                                  'Resultado de atención',
                                                );
                                                if (notes != null) {
                                                  await ref
                                                      .read(
                                                        guidanceRepositoryProvider,
                                                      )
                                                      .transition(
                                                        call.id,
                                                        'complete',
                                                        notes: notes,
                                                      );
                                                }
                                              }),
                                        child: const Text(
                                          'Finalizar y registrar resultado',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if ([
                                          'pending',
                                          'assigned',
                                        ].contains(call.status) &&
                                        (coordinator ||
                                            call.requestedBy == user?.id))
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => run(
                                                () => ref
                                                    .read(
                                                      guidanceRepositoryProvider,
                                                    )
                                                    .transition(
                                                      call.id,
                                                      'cancel',
                                                    ),
                                              ),
                                        child: const Text(
                                          'Cancelar solicitud',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'pending' => 'En espera',
  'assigned' => 'Profesional asignado',
  'in_progress' => 'En atención',
  'completed' => 'Finalizada',
  'cancelled' => 'Cancelada',
  _ => status,
};
String _priorityLabel(String priority) => switch (priority) {
  'red' => 'Cola urgente',
  'yellow' => 'Cola prioritaria',
  _ => 'Cola estándar',
};
