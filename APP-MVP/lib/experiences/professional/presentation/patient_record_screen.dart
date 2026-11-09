import 'package:flutter/material.dart';
import '../../../modules/clinical_records/presentation/profile_completion_card.dart';
import '../../../modules/clinical_records/presentation/clinical_history_screen.dart';
import '../../../modules/partners/presentation/diagnostic_orders_screen.dart';
import '../../../modules/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/clinical_records/application/clinical_records_controller.dart';
import '../../../modules/clinical_records/domain/clinical_document.dart';
import '../../../modules/clinical_records/domain/professional_patient_record.dart';
import '../../../modules/clinical_records/presentation/widgets/clinical_record_cards.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/professionals/application/professionals_controller.dart';
import '../../../modules/clinical_records/presentation/professional_vitals_screen.dart';

class PatientRecordScreen extends ConsumerWidget {
  const PatientRecordScreen({
    super.key,
    required this.patientId,
    this.appointmentId,
  });

  final String patientId;
  final String? appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(professionalPatientRecordProvider(patientId));
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expediente del paciente'),
          actions: [
            IconButton(
              tooltip: 'Estudios diagnósticos',
              icon: const Icon(Icons.science_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiagnosticOrdersScreen(
                    patientId: patientId,
                    appointmentId: appointmentId,
                    canOrder:
                        ref
                            .read(authControllerProvider)
                            .user
                            ?.roles
                            .any(
                              (role) => [
                                'doctor_general',
                                'doctor_specialist',
                              ].contains(role),
                            ) ??
                        false,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Evolución clínica',
              icon: const Icon(Icons.timeline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ClinicalHistoryScreen(patientId: patientId),
                ),
              ),
            ),
            if (appointmentId != null)
              IconButton(
                tooltip: 'Registrar signos vitales',
                icon: const Icon(Icons.monitor_heart_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => ProfessionalVitalsScreen(
                      patientId: patientId,
                      appointmentId: appointmentId,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Emitir derivación',
              icon: const Icon(Icons.send_outlined),
              onPressed: () => _createReferral(context, ref),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Información clínica'),
              Tab(text: 'Signos vitales'),
              Tab(text: 'Documentos'),
            ],
          ),
        ),
        floatingActionButton: appointmentId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () {
                  final value = record.valueOrNull;
                  context.pushNamed(
                    AppRoutes.clinicalNote,
                    queryParameters: {
                      'patientId': patientId,
                      'appointmentId': appointmentId!,
                      'patientName': value?.fullName ?? 'Paciente',
                    },
                  );
                },
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Nota clínica'),
              ),
        body: record.when(
          loading: () => const AppLoadingState(message: 'Cargando expediente'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(professionalPatientRecordProvider(patientId)),
          ),
          data: (data) => TabBarView(
            children: [
              _SummaryTab(record: data),
              _StatementsTab(record: data),
              _VitalsTab(record: data),
              _DocumentsTab(record: data),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createReferral(BuildContext context, WidgetRef ref) async {
    final professionals = await ref.read(professionalDirectoryProvider.future);
    final specialties = <String, String>{
      for (final item in professionals) item.specialtyId: item.specialty,
    };
    if (specialties.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No existen especialidades activas.')),
        );
      }
      return;
    }
    var specialtyId = specialties.keys.first,
        priority = 'yellow',
        type = 'ordinary';
    final reason = TextEditingController();
    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Emitir derivación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: specialtyId,
                  decoration: const InputDecoration(labelText: 'Especialidad'),
                  items: specialties.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => specialtyId = value ?? specialtyId),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                  items: const [
                    DropdownMenuItem(value: 'green', child: Text('Baja')),
                    DropdownMenuItem(value: 'yellow', child: Text('Normal')),
                    DropdownMenuItem(value: 'orange', child: Text('Alta')),
                    DropdownMenuItem(value: 'red', child: Text('Urgente')),
                  ],
                  onChanged: (value) =>
                      setState(() => priority = value ?? priority),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'ordinary',
                      child: Text('Ordinaria'),
                    ),
                    DropdownMenuItem(
                      value: 'preferred',
                      child: Text('Preferente'),
                    ),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                    DropdownMenuItem(
                      value: 'chronic_followup',
                      child: Text('Control crónico'),
                    ),
                  ],
                  onChanged: (value) => setState(() => type = value ?? type),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: reason,
                  label: 'Motivo clínico',
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Emitir',
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
              ),
            ),
          ],
        ),
      ),
    );
    final reasonValue = reason.text.trim();
    reason.dispose();
    if (accepted != true || reasonValue.isEmpty) return;
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .createReferral(
            patientId: patientId,
            specialtyId: specialtyId,
            reason: reasonValue,
            priority: priority,
            referralType: type,
          );
      ref.invalidate(appointmentCareActionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Derivación emitida correctamente.')),
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

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.record});
  final ProfessionalPatientRecord record;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      ProfileCompletionCard(
        patientId: record.patientId,
        professionalView: true,
      ),
      AppCard(
        child: Row(
          children: [
            UserAvatar(name: record.fullName, radius: 30),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    record.birthDate == null
                        ? 'Fecha de nacimiento no registrada'
                        : 'Nacimiento: ${record.birthDate!.day.toString().padLeft(2, '0')}/${record.birthDate!.month.toString().padLeft(2, '0')}/${record.birthDate!.year}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: StatCard(
              value: record.bloodType ?? '—',
              label: 'Tipo de sangre',
              icon: Icons.water_drop_outlined,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: StatCard(
              value: record.weightKg == null ? '—' : '${record.weightKg} kg',
              label: 'Peso',
              icon: Icons.monitor_weight_outlined,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: StatCard(
              value: record.heightCm == null ? '—' : '${record.heightCm} cm',
              label: 'Estatura',
              icon: Icons.height_rounded,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _InfoCard(
        icon: Icons.health_and_safety_outlined,
        title: 'Cobertura',
        value: [
          record.insuranceProvider,
          record.insuranceNumber,
        ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
      ),
      const SizedBox(height: AppSpacing.md),
      _InfoCard(
        icon: Icons.contact_emergency_outlined,
        title: 'Contacto de emergencia',
        value: record.emergencyContact ?? '',
      ),
      if (record.profileNotes?.isNotEmpty ?? false) ...[
        const SizedBox(height: AppSpacing.md),
        _InfoCard(
          icon: Icons.notes_outlined,
          title: 'Observaciones',
          value: record.profileNotes!,
        ),
      ],
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => AppCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value.isEmpty ? 'No registrado' : value),
    ),
  );
}

class _StatementsTab extends ConsumerWidget {
  const _StatementsTab({required this.record});
  final ProfessionalPatientRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (record.statements.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Sin información clínica',
        message: 'No existen declaraciones activas.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: record.statements.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) {
        final item = record.statements[index];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.description,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusPill(
                    label: clinicalValidationLabel(item.validationStatus),
                    color: item.validationStatus == 'validated'
                        ? AppColors.success
                        : item.validationStatus == 'rejected'
                        ? AppColors.danger
                        : AppColors.warning,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _categoryLabel(item.category),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.detail?.isNotEmpty ?? false) Text(item.detail!),
              const Divider(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        _validateStatement(context, ref, item, 'rejected'),
                    child: const Text('Observar'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () =>
                        _validateStatement(context, ref, item, 'validated'),
                    child: const Text('Validar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _validateStatement(
    BuildContext context,
    WidgetRef ref,
    ClinicalStatement item,
    String status,
  ) async {
    final notes = await _validationNotes(context, status);
    if (notes == null) return;
    try {
      await ref
          .read(clinicalRecordsRepositoryProvider)
          .validateStatement(
            patientId: record.patientId,
            type: item.type,
            statementId: item.id,
            status: status,
            notes: notes,
          );
      ref.invalidate(professionalPatientRecordProvider(record.patientId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _VitalsTab extends StatelessWidget {
  const _VitalsTab({required this.record});
  final ProfessionalPatientRecord record;
  @override
  Widget build(BuildContext context) => record.vitalSigns.isEmpty
      ? const EmptyState(
          icon: Icons.monitor_heart_outlined,
          title: 'Sin mediciones',
          message: 'No existen signos vitales registrados.',
        )
      : ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: record.vitalSigns.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, index) => VitalSignRecordCard(
            record: record.vitalSigns[index],
            badgeLabel: record.vitalSigns[index].source == 'patient'
                ? 'Paciente'
                : 'Profesional',
          ),
        );
}

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab({required this.record});
  final ProfessionalPatientRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) => record.documents.isEmpty
      ? const EmptyState(
          icon: Icons.folder_copy_outlined,
          title: 'Sin documentos visibles',
          message: 'No existen documentos clínicos autorizados.',
        )
      : ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: record.documents.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, index) {
            final document = record.documents[index];
            return ClinicalDocumentCard(
              document: document,
              onOpen: () => _openDocument(context, document),
              actions: [
                TextButton(
                  onPressed: () =>
                      _validateDocument(context, ref, document, 'rejected'),
                  child: const Text('Observar'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () =>
                      _validateDocument(context, ref, document, 'validated'),
                  child: const Text('Validar'),
                ),
              ],
            );
          },
        );

  Future<void> _validateDocument(
    BuildContext context,
    WidgetRef ref,
    ClinicalDocument document,
    String status,
  ) async {
    final notes = await _validationNotes(context, status);
    if (notes == null) return;
    try {
      await ref
          .read(clinicalRecordsRepositoryProvider)
          .validateDocument(
            patientId: record.patientId,
            documentId: document.id,
            status: status,
            notes: notes,
          );
      ref.invalidate(professionalPatientRecordProvider(record.patientId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

Future<String?> _validationNotes(BuildContext context, String status) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        status == 'validated' ? 'Validar información' : 'Observar información',
      ),
      content: AppTextField(
        controller: controller,
        label: status == 'rejected'
            ? 'Motivo de la observación'
            : 'Nota (opcional)',
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
  final value = controller.text.trim();
  controller.dispose();
  if (confirmed != true || (status == 'rejected' && value.isEmpty)) return null;
  return value;
}

Future<void> _openDocument(
  BuildContext context,
  ClinicalDocument document,
) async {
  final uri = Uri.tryParse(document.fileUrl);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento.')),
      );
    }
  }
}

String _categoryLabel(String category) => switch (category) {
  'allergy' => 'Alergia',
  'chronic_condition' => 'Condición crónica',
  'medication' => 'Medicación actual',
  'pathological' => 'Antecedente médico',
  'family' => 'Antecedente familiar',
  'surgical' => 'Antecedente quirúrgico',
  _ => 'Información clínica',
};
