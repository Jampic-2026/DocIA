import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/incidents_controller.dart';
import '../domain/incident.dart';

class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsControllerProvider);
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Incidentes y reclamos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nuevo reclamo'),
      ),
      body: incidents.when(
        loading: () =>
            const AppLoadingState(message: 'Cargando tus solicitudes'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(incidentsControllerProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.support_agent_rounded,
                title: 'Sin solicitudes',
                message: 'Puedes informar un problema o presentar un reclamo.',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(incidentsControllerProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    96,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _IncidentCard(
                      incident: items[index],
                      onClose: () => ref
                          .read(incidentsControllerProvider.notifier)
                          .close(items[index].id),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_IncidentDraft>(
      context: context,
      builder: (_) => const Dialog(child: _IncidentForm()),
    );
    if (result == null) return;
    try {
      await ref
          .read(incidentsControllerProvider.notifier)
          .create(
            module: result.module,
            incidentType: result.incidentType,
            severity: result.severity,
            description: result.description,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu solicitud fue registrada.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onClose});

  final Incident incident;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final color = switch (incident.status) {
      'resolved' => AppColors.success,
      'closed' => Theme.of(context).colorScheme.onSurfaceVariant,
      _ => AppColors.warning,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _typeLabel(incident.incidentType),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: _statusLabel(incident.status),
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(incident.description),
          if (incident.resolution case final resolution?
              when resolution.trim().isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            Text(
              'Respuesta: $resolution',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Área: ${_moduleLabel(incident.module)} · '
            '${_formatDate(incident.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (incident.canClose) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                child: const Text('Cerrar solicitud'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String value) => switch (value) {
    'open' => 'Abierto',
    'pending' => 'Pendiente',
    'in_review' => 'En revisión',
    'resolved' => 'Resuelto',
    'closed' => 'Cerrado',
    _ => value,
  };

  String _typeLabel(String value) => switch (value) {
    'technical' => 'Problema técnico',
    'service' => 'Problema de atención',
    'information' => 'Información incorrecta',
    'billing' => 'Facturación',
    'complaint' => 'Reclamo',
    _ => 'Otro',
  };

  String _moduleLabel(String value) => switch (value) {
    'appointments' => 'Citas',
    'telemedicine' => 'Telemedicina',
    'prescriptions' => 'Recetas',
    'emergencies' => 'Emergencias',
    'account' => 'Cuenta',
    'catalog' => 'Catálogo',
    _ => 'Otro',
  };

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }
}

class _IncidentDraft {
  const _IncidentDraft({
    required this.module,
    required this.incidentType,
    required this.severity,
    required this.description,
  });

  final String module;
  final String incidentType;
  final String severity;
  final String description;
}

class _IncidentForm extends StatefulWidget {
  const _IncidentForm();

  @override
  State<_IncidentForm> createState() => _IncidentFormState();
}

class _IncidentFormState extends State<_IncidentForm> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _module = 'appointments';
  String _type = 'service';
  String _severity = 'yellow';

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nueva solicitud',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: _module,
                  decoration: const InputDecoration(labelText: 'Área relacionada'),
                  items: const [
                    DropdownMenuItem(value: 'appointments', child: Text('Citas')),
                    DropdownMenuItem(
                      value: 'telemedicine',
                      child: Text('Telemedicina'),
                    ),
                    DropdownMenuItem(
                      value: 'prescriptions',
                      child: Text('Recetas'),
                    ),
                    DropdownMenuItem(
                      value: 'emergencies',
                      child: Text('Emergencias'),
                    ),
                    DropdownMenuItem(value: 'account', child: Text('Cuenta')),
                    DropdownMenuItem(value: 'catalog', child: Text('Catálogo')),
                    DropdownMenuItem(value: 'other', child: Text('Otro')),
                  ],
                  onChanged: (value) => _module = value ?? _module,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'technical',
                      child: Text('Problema técnico'),
                    ),
                    DropdownMenuItem(
                      value: 'service',
                      child: Text('Problema de atención'),
                    ),
                    DropdownMenuItem(
                      value: 'information',
                      child: Text('Información incorrecta'),
                    ),
                    DropdownMenuItem(value: 'billing', child: Text('Facturación')),
                    DropdownMenuItem(value: 'complaint', child: Text('Reclamo')),
                    DropdownMenuItem(value: 'other', child: Text('Otro')),
                  ],
                  onChanged: (value) => _type = value ?? _type,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _severity,
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                  items: const [
                    DropdownMenuItem(value: 'green', child: Text('Baja')),
                    DropdownMenuItem(value: 'yellow', child: Text('Media')),
                    DropdownMenuItem(value: 'red', child: Text('Alta')),
                  ],
                  onChanged: (value) => _severity = value ?? _severity,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Describe lo ocurrido',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? 'Escribe al menos 10 caracteres.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppDialogActions(
                  cancelLabel: 'Cancelar',
                  confirmLabel: 'Registrar solicitud',
                  confirmIcon: Icons.add_comment_outlined,
                  onCancel: () => Navigator.pop(context),
                  onConfirm: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _IncidentDraft(
        module: _module,
        incidentType: _type,
        severity: _severity,
        description: _description.text.trim(),
      ),
    );
  }
}
