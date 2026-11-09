import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../human_resources/application/human_resources_controller.dart';
import '../../human_resources/domain/staff_member.dart';
import '../../maps/application/maps_controller.dart';
import '../../maps/domain/location_preview.dart';
import '../../maps/presentation/location_map_card.dart';
import '../application/emergencies_controller.dart';
import '../domain/emergency_event.dart';

class EmergencyOperationsScreen extends ConsumerWidget {
  const EmergencyOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(emergencyEventsProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando emergencias'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(emergencyEventsProvider),
          ),
          data: (events) {
            final active = events.where((event) => event.isActive).toList();
            if (active.isEmpty) {
              return const EmptyState(
                icon: Icons.health_and_safety_outlined,
                title: 'Sin emergencias activas',
                message: 'Las nuevas solicitudes aparecerán en esta bandeja.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(emergencyEventsProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: active.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final event = active[index];
                  return _EmergencyCard(
                    event: event,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _EmergencyOperationSheet(event: event),
                    ),
                  );
                },
              ),
            );
          },
        );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.event, required this.onTap});

  final EmergencyEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final risk = _riskPresentation(event.riskLevel);
    return AppCard(
      onTap: onTap,
      border: Border.all(color: risk.$2, width: 1.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: event.patientName ?? 'Paciente',
                gradient: AppColors.emergencyGradient,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.patientName ?? 'Paciente',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(event.openedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(label: risk.$1, color: risk.$2, dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            event.description?.trim().isNotEmpty == true
                ? event.description!
                : 'Sin descripción adicional.',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            event.manualAddress?.trim().isNotEmpty == true
                ? event.manualAddress!
                : 'Ubicación sin referencia escrita',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusPill(
                label: _statusLabel(event.status),
                color: AppColors.teal,
                dense: true,
              ),
              const Spacer(),
              Text(event.assignedTeamName ?? 'Sin equipo asignado'),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmergencyOperationSheet extends ConsumerStatefulWidget {
  const _EmergencyOperationSheet({required this.event});

  final EmergencyEvent event;

  @override
  ConsumerState<_EmergencyOperationSheet> createState() =>
      _EmergencyOperationSheetState();
}

class _EmergencyOperationSheetState
    extends ConsumerState<_EmergencyOperationSheet> {
  late EmergencyEvent _event;
  String? _professionalId;
  String? _operatorId;
  LocationPreview? _location;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _professionalId = _event.assignedProfessionalId;
    _operatorId = _event.assignedOperatorId;
    _loadLocation();
  }

  @override
  Widget build(BuildContext context) {
    final canAssign =
        ref.watch(authControllerProvider).user?.hasRole('admin') ?? false;
    final staff = canAssign
        ? ref.watch(staffProvider).valueOrNull ?? const <StaffMember>[]
        : const <StaffMember>[];
    final operators = staff
        .where((member) => member.professionalType == 'operator')
        .toList();
    final careTeam = staff
        .where(
          (member) =>
              member.professionalType != 'operator' &&
              member.verificationStatus == 'approved',
        )
        .toList();
    final transitions = _allowedTransitions(_event.status);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            _event.patientName ?? 'Emergencia',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StatusPill(
                label: _riskPresentation(_event.riskLevel).$1,
                color: _riskPresentation(_event.riskLevel).$2,
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: _statusLabel(_event.status),
                color: AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(_event.description ?? 'Sin descripción adicional.'),
          if (_event.patientPhone?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _callPatient,
              icon: const Icon(Icons.call_outlined),
              label: Text('Llamar a ${_event.patientPhone}'),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          LocationMapCard(
            preview: _location,
            loading: false,
            message: _event.manualAddress,
            onLocate: _loadLocation,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (canAssign) ...[
            const SectionHeader(title: 'Asignación'),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _contains(careTeam, _professionalId)
                  ? _professionalId
                  : null,
              decoration: const InputDecoration(labelText: 'Profesional'),
              items: careTeam
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.professionalId,
                      child: Text(member.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _professionalId = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _contains(operators, _operatorId)
                  ? _operatorId
                  : null,
              decoration: const InputDecoration(labelText: 'Operador'),
              items: operators
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.professionalId,
                      child: Text(member.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _operatorId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed:
                  _saving || (_professionalId == null && _operatorId == null)
                  ? null
                  : _assign,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Asignar equipo'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          const SectionHeader(title: 'Actualizar estado'),
          const SizedBox(height: AppSpacing.sm),
          if (transitions.isEmpty)
            const Text('No existen más transiciones disponibles.')
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final status in transitions)
                  ActionChip(
                    label: Text(_statusLabel(status)),
                    onPressed: _saving ? null : () => _changeStatus(status),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  bool _contains(List<StaffMember> values, String? id) =>
      id != null && values.any((member) => member.professionalId == id);

  Future<void> _loadLocation() async {
    if (_event.latitude == null || _event.longitude == null) return;
    try {
      final preview = await ref
          .read(mapsRepositoryProvider)
          .preview(latitude: _event.latitude!, longitude: _event.longitude!);
      if (mounted) setState(() => _location = preview);
    } catch (_) {}
  }

  Future<void> _callPatient() async {
    await launchUrl(Uri(scheme: 'tel', path: _event.patientPhone));
  }

  Future<void> _assign() async {
    setState(() => _saving = true);
    try {
      _event = await ref
          .read(emergenciesRepositoryProvider)
          .assign(
            _event.id,
            professionalId: _professionalId,
            operatorId: _operatorId,
          );
      ref.invalidate(emergencyEventsProvider);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_statusLabel(status)),
        content: AppTextField(
          controller: notes,
          label: 'Nota operativa (opcional)',
          maxLines: 3,
        ),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Confirmar',
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    final value = notes.text;
    notes.dispose();
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      _event = await ref
          .read(emergenciesRepositoryProvider)
          .updateStatus(_event.id, status: status, notes: value);
      ref.invalidate(emergencyEventsProvider);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

(String, Color) _riskPresentation(String risk) => switch (risk) {
  'red' => ('Alta', AppColors.danger),
  'yellow' => ('Moderada', AppColors.warning),
  _ => ('Baja', AppColors.success),
};

String _statusLabel(String status) => switch (status) {
  'received' => 'Recibida',
  'confirming' => 'Confirmando',
  'validating' => 'Validando',
  'assigned' => 'Asignada',
  'on_route' => 'En camino',
  'on_site' => 'En el lugar',
  'in_care' => 'En atención',
  'referred' => 'Derivada',
  'closed' => 'Finalizada',
  'cancelled' => 'Cancelada',
  'false_alarm' => 'Falso aviso',
  _ => status,
};

List<String> _allowedTransitions(String status) => switch (status) {
  'received' => ['confirming', 'validating', 'cancelled', 'false_alarm'],
  'confirming' => ['validating', 'assigned', 'cancelled', 'false_alarm'],
  'validating' => ['assigned', 'cancelled', 'false_alarm'],
  'assigned' => ['on_route', 'cancelled'],
  'on_route' => ['on_site', 'cancelled'],
  'on_site' => ['in_care', 'referred', 'closed'],
  'in_care' => ['referred', 'closed'],
  'referred' => ['closed'],
  _ => const [],
};
