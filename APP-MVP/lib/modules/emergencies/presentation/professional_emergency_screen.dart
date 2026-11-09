import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../professional_profile/application/professional_profile_controller.dart';
import '../../clinical_records/presentation/professional_vitals_screen.dart';
import '../../../experiences/professional/presentation/patient_record_screen.dart';
import '../application/emergencies_controller.dart';
import '../domain/emergency_event.dart';
import 'emergency_care_form.dart';

class ProfessionalEmergencyScreen extends ConsumerStatefulWidget {
  const ProfessionalEmergencyScreen({super.key});
  @override
  ConsumerState<ProfessionalEmergencyScreen> createState() =>
      _ProfessionalEmergencyScreenState();
}

class _ProfessionalEmergencyScreenState
    extends ConsumerState<ProfessionalEmergencyScreen> {
  Timer? poll;
  final busy = <String>{};
  @override
  void initState() {
    super.initState();
    poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && busy.isEmpty) {
        ref.invalidate(emergencyEventsProvider);
      }
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(professionalProfileProvider);
    final events = ref.watch(emergencyEventsProvider);
    final isNurse =
        ref.watch(authControllerProvider).user?.hasRole('nurse') ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Casos asignados'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(emergencyEventsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profile.when(
        loading: () =>
            const AppLoadingState(message: 'Consultando habilitación'),
        error: (error, _) => AppErrorState(message: error.toString()),
        data: (professional) => events.when(
          loading: () => const AppLoadingState(message: 'Cargando casos'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(emergencyEventsProvider),
          ),
          data: (items) {
            final assigned = items
                .where(
                  (event) =>
                      event.assignedProfessionalId == professional.id &&
                      event.isActive,
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (assigned.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'Sin casos activos',
                    message:
                        'Las asignaciones aparecerán aquí. Puedes actualizar la lista.',
                  ),
                for (final event in assigned)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.patientName ?? 'Paciente asignado',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Prioridad: ${_riskLabel(event.riskLevel)} · Estado: ${_statusLabel(event.status)}',
                        ),
                        Text(
                          'Recibido: ${DateFormat('dd/MM/yyyy HH:mm').format(event.openedAt)}',
                        ),
                        if (event.manualAddress != null)
                          Text(event.manualAddress!),
                        if (event.description != null) Text(event.description!),
                        if (event.patientId != null)
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PatientRecordScreen(
                                  patientId: event.patientId!,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Consultar expediente'),
                          ),
                        if (event.status == 'assigned' &&
                            event.acceptedAt == null)
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              TextButton(
                                onPressed: busy.contains(event.id)
                                    ? null
                                    : () => _decline(event),
                                child: const Text('Rechazar con motivo'),
                              ),
                              FilledButton(
                                onPressed: busy.contains(event.id)
                                    ? null
                                    : () => _perform(
                                        event,
                                        () => ref
                                            .read(emergenciesRepositoryProvider)
                                            .decideAssignment(
                                              event.id,
                                              decision: 'accepted',
                                            ),
                                      ),
                                child: const Text('Aceptar caso'),
                              ),
                            ],
                          ),
                        if (event.acceptedAt != null) ...[
                          TextButton.icon(
                            onPressed: busy.contains(event.id)
                                ? null
                                : () => _falseAlarm(event),
                            icon: const Icon(Icons.report_off_outlined),
                            label: const Text(
                              'Registrar falsa alarma con motivo',
                            ),
                          ),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              if (_next(event.status) != null)
                                FilledButton(
                                  onPressed: busy.contains(event.id)
                                      ? null
                                      : () => _perform(
                                          event,
                                          () => ref
                                              .read(
                                                emergenciesRepositoryProvider,
                                              )
                                              .updateStatus(
                                                event.id,
                                                status: _next(event.status)!,
                                              ),
                                        ),
                                  child: Text(_nextLabel(event.status)),
                                ),
                              if ([
                                'on_site',
                                'in_care',
                                'referred',
                              ].contains(event.status))
                                OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<bool>(
                                      builder: (_) => EmergencyCareForm(
                                        emergencyId: event.id,
                                        isNurse: isNurse,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Registrar atención'),
                                ),
                              if ([
                                    'on_site',
                                    'in_care',
                                  ].contains(event.status) &&
                                  event.patientId != null)
                                OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<bool>(
                                      builder: (_) => ProfessionalVitalsScreen(
                                        patientId: event.patientId!,
                                        emergencyId: event.id,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Signos vitales'),
                                ),
                              if (['on_site', 'in_care'].contains(event.status))
                                TextButton(
                                  onPressed: busy.contains(event.id)
                                      ? null
                                      : () => _perform(
                                          event,
                                          () => ref
                                              .read(
                                                emergenciesRepositoryProvider,
                                              )
                                              .updateStatus(
                                                event.id,
                                                status: 'referred',
                                              ),
                                        ),
                                  child: const Text(
                                    'Confirmar derivación registrada',
                                  ),
                                ),
                              if ([
                                'on_site',
                                'in_care',
                                'referred',
                              ].contains(event.status))
                                TextButton(
                                  onPressed: busy.contains(event.id)
                                      ? null
                                      : () => _perform(
                                          event,
                                          () => ref
                                              .read(
                                                emergenciesRepositoryProvider,
                                              )
                                              .updateStatus(
                                                event.id,
                                                status: 'closed',
                                              ),
                                        ),
                                  child: const Text(
                                    'Finalizar con cierre registrado',
                                  ),
                                ),
                            ],
                          ),
                          ref
                              .watch(emergencyCareProvider(event.id))
                              .when(
                                loading: () => const LinearProgressIndicator(),
                                error: (error, _) => Text(error.toString()),
                                data: (records) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Registros de atención'),
                                    for (final record in records)
                                      ListTile(
                                        title: Text(record.notes),
                                        subtitle: Text(
                                          '${record.content['assessment'] ?? ''}\n${DateFormat('dd/MM/yyyy HH:mm').format(record.createdAt)}',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _next(String status) => switch (status) {
    'assigned' => 'on_route',
    'on_route' => 'on_site',
    'on_site' => 'in_care',
    _ => null,
  };
  String _nextLabel(String status) => switch (status) {
    'assigned' => 'Iniciar traslado',
    'on_route' => 'Registrar llegada',
    _ => 'Iniciar atención',
  };
  Future<void> _perform(
    EmergencyEvent event,
    Future<Object?> Function() operation,
  ) async {
    setState(() => busy.add(event.id));
    try {
      await operation();
      ref.invalidate(emergencyEventsProvider);
      ref.invalidate(emergencyCareProvider(event.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy.remove(event.id));
    }
  }

  String _riskLabel(String value) => switch (value) {
    'red' => 'Roja',
    'yellow' => 'Amarilla',
    'green' => 'Verde',
    _ => 'Sin clasificar',
  };
  String _statusLabel(String value) => switch (value) {
    'assigned' => 'Asignado',
    'on_route' => 'En traslado',
    'on_site' => 'En el lugar',
    'in_care' => 'En atención',
    'referred' => 'Derivado',
    _ => 'Pendiente',
  };
  Future<void> _falseAlarm(EmergencyEvent event) async {
    final controller = TextEditingController();
    final reason = await showAppDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Registrar falsa alarma'),
        content: AppTextField(
          controller: controller,
          label: 'Motivo',
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 3) {
                Navigator.pop(dialog, controller.text.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) {
      return;
    }
    await _perform(
      event,
      () => ref
          .read(emergenciesRepositoryProvider)
          .updateStatus(event.id, status: 'false_alarm', notes: reason),
    );
  }

  Future<void> _decline(EmergencyEvent event) async {
    final controller = TextEditingController();
    final reason = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: AppTextField(
          controller: controller,
          label: 'Motivo',
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 3) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await _perform(
      event,
      () => ref
          .read(emergenciesRepositoryProvider)
          .decideAssignment(event.id, decision: 'rejected', reason: reason),
    );
  }
}
