import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/authorization/access_control_provider.dart';
import '../../../core/authorization/permission_codes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/prescriptions_controller.dart';
import '../domain/prescription.dart';
import '../domain/prescriptions_repository.dart';
import '../../professional_patients/application/professional_patients_controller.dart';
import '../../professional_patients/domain/professional_patient.dart';

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(prescriptionsProvider);
    final canCreate = ref
        .watch(accessControlProvider)
        .can(PermissionCodes.prescriptionsManage);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            MediaQuery.sizeOf(context).width < AppDimensions.compactBreakpoint,
        title: const Text('Recetas digitales'),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _showCreationForm(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva receta'),
            )
          : null,
      body: prescriptions.when(
        loading: () => const AppLoadingState(message: 'Cargando recetas'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(prescriptionsProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Sin recetas',
                message: 'Las recetas digitales aparecerán aquí.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, index) =>
                    _PrescriptionCard(prescription: items[index]),
              ),
      ),
    );
  }

  void _showCreationForm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PrescriptionForm(),
    );
  }
}

class _PrescriptionForm extends ConsumerStatefulWidget {
  const _PrescriptionForm();

  @override
  ConsumerState<_PrescriptionForm> createState() => _PrescriptionFormState();
}

class _PrescriptionFormState extends ConsumerState<_PrescriptionForm> {
  final _formKey = GlobalKey<FormState>();
  final _medication = TextEditingController();
  final _dose = TextEditingController();
  final _frequency = TextEditingController();
  final _duration = TextEditingController();
  final _instructions = TextEditingController();
  ProfessionalPatient? _patient;
  bool _saving = false;

  @override
  void dispose() {
    _medication.dispose();
    _dose.dispose();
    _frequency.dispose();
    _duration.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _patient == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(prescriptionsRepositoryProvider)
          .createDraft(
            CreatePrescriptionCommand(
              patientId: _patient!.id,
              appointmentId: _patient!.appointmentId!,
              medicationName: _medication.text.trim(),
              dose: _dose.text.trim(),
              frequency: _frequency.text.trim(),
              duration: _duration.text.trim(),
              instructions: _instructions.text.trim(),
            ),
          );
      ref.invalidate(prescriptionsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Borrador guardado. Revísalo antes de emitir y firmar.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(professionalPatientsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Nueva receta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Se guardará como borrador para que puedas revisarla antes de emitirla.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            patients.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (items) {
                final eligible = items
                    .where((patient) => patient.appointmentId != null)
                    .toList();
                return DropdownButtonFormField<ProfessionalPatient>(
                  initialValue: _patient,
                  decoration: const InputDecoration(labelText: 'Paciente'),
                  items: eligible
                      .map(
                        (patient) => DropdownMenuItem(
                          value: patient,
                          child: Text(patient.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _patient = value),
                  validator: (value) =>
                      value == null ? 'Selecciona un paciente' : null,
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _medication,
              label: 'Medicamento',
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _dose, label: 'Dosis'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _frequency, label: 'Frecuencia'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _duration, label: 'Duración'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _instructions,
              label: 'Indicaciones',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Guardando...' : 'Guardar borrador'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo requerido' : null;
}

class _PrescriptionCard extends ConsumerWidget {
  const _PrescriptionCard({required this.prescription});
  final Prescription prescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = prescription.issuedAt ?? prescription.createdAt;
    final canIssue =
        prescription.status == 'draft' &&
        ref
            .watch(accessControlProvider)
            .can(PermissionCodes.prescriptionsManage);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.teal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prescription.patientName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${prescription.professionalName} · '
                      '${DateFormat('d MMMM y', 'es').format(date)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: _statusLabel(prescription.status),
                color: _statusColor(prescription.status),
                dense: true,
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          if (prescription.items.isEmpty)
            const Text('Sin medicamentos registrados.')
          else
            for (final item in prescription.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.medication_rounded,
                      size: 20,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.medicationName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [item.dose, item.frequency, item.duration]
                                .whereType<String>()
                                .where((value) => value.trim().isNotEmpty)
                                .join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (item.instructions?.trim().isNotEmpty ?? false)
                            Text(item.instructions!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (prescription.status == 'issued') ...[
            const Divider(height: AppSpacing.lg),
            const Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Firma de integridad verificada por Doc IA'),
              ],
            ),
          ],
          if (canIssue) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _issue(context, ref),
                icon: const Icon(Icons.draw_rounded),
                label: const Text('Emitir y firmar'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _issue(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final expiresAt = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Vencimiento de la receta',
    );
    if (expiresAt == null) return;
    try {
      final safety = await ref
          .read(prescriptionsRepositoryProvider)
          .safetyReview(prescription.id);
      final allergies = safety['allergies'] as List? ?? [];
      String? reason;
      if (allergies.isNotEmpty) {
        if (!context.mounted) return;
        final controller = TextEditingController();
        try {
          reason = await showAppDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Revisión de alergias'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Alergias registradas. Revisa la pertinencia de todos los medicamentos antes de emitir. Este aviso no verifica interacciones farmacológicas.',
                    ),
                    for (final allergy in allergies)
                      ListTile(
                        title: Text(allergy['substance'] as String),
                        subtitle: Text(
                          allergy['reaction'] as String? ??
                              'Reacción no registrada',
                        ),
                      ),
                    TextField(
                      controller: controller,
                      maxLength: 1000,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Justificación profesional de la revisión',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver sin emitir'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().length >= 8) {
                      Navigator.pop(context, controller.text.trim());
                    }
                  },
                  child: const Text('Revisado; continuar'),
                ),
              ],
            ),
          );
        } finally {
          controller.dispose();
        }
        if (reason == null) return;
      }
      await ref
          .read(prescriptionsRepositoryProvider)
          .issue(
            prescription.id,
            DateTime(
              expiresAt.year,
              expiresAt.month,
              expiresAt.day,
              23,
              59,
              59,
            ),
            allergyFingerprint: safety['fingerprint'] as String?,
            allergyReviewReason: reason,
          );
      ref.invalidate(prescriptionsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receta emitida y firmada correctamente.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

String _statusLabel(String status) => switch (status) {
  'issued' => 'Emitida',
  'cancelled' => 'Cancelada',
  'expired' => 'Vencida',
  _ => 'Borrador',
};

Color _statusColor(String status) => switch (status) {
  'issued' => AppColors.success,
  'cancelled' => AppColors.danger,
  'expired' => AppColors.warning,
  _ => AppColors.blue,
};
