import '../../../modules/human_resources/presentation/document_type_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/files/application/files_controller.dart';
import '../../../modules/professional_profile/application/professional_profile_controller.dart';
import '../../../modules/professional_profile/domain/professional_profile.dart';
import '../../../modules/human_resources/application/human_resources_controller.dart';

class ProfessionalProfileScreen extends ConsumerWidget {
  const ProfessionalProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final profile = ref.watch(professionalProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil profesional')),
      body: profile.when(
        loading: () =>
            const AppLoadingState(message: 'Cargando perfil profesional'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(professionalProfileProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Estado de validación',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StatusPill(
                        label: _status(data.verificationStatus),
                        color: data.verificationStatus == 'approved'
                            ? AppColors.success
                            : AppColors.warning,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoLine(
                    icon: Icons.badge_outlined,
                    label: _roleLabel(user?.primaryRoleCode, data),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoLine(
                    icon: Icons.workspace_premium_outlined,
                    label: data.licenseNumber?.isNotEmpty == true
                        ? 'Matrícula: ${data.licenseNumber}'
                        : 'Matrícula no registrada',
                  ),
                  if (data.specialties.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _InfoLine(
                      icon: Icons.local_hospital_outlined,
                      label: data.specialties
                          .map((item) => item.name)
                          .join(' · '),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _edit(context, ref, data),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar perfil'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Documentación',
              subtitle: 'Credenciales enviadas para revisión',
              actionLabel: 'Agregar',
              onAction: () => _addDocument(context, ref),
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.documents.isEmpty)
              const Text('No registraste documentos profesionales.')
            else
              for (final document in data.documents) ...[
                _DocumentCard(document: document),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ProfessionalProfile profile,
  ) async {
    final license = TextEditingController(text: profile.licenseNumber);
    final bio = TextEditingController(text: profile.bio);
    final education = TextEditingController(text: profile.academicBackground);
    final certificates = TextEditingController(
      text: profile.publicCertifications.join('\n'),
    );
    final years = TextEditingController(
      text: profile.yearsExperience?.toString(),
    );
    var public = profile.publicProfileEnabled;
    var specialtyId =
        profile.pendingSpecialtyId ??
        profile.specialties.where((item) => item.isPrimary).firstOrNull?.id;
    final save = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar perfil profesional'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: license,
                    label: 'Número de matrícula',
                  ),
                  const Text(
                    'Cambiar matrícula o especialidad requiere una nueva revisión antes de ejercer en la plataforma.',
                  ),
                  if (profile.professionalType == 'doctor')
                    Consumer(
                      builder: (context, ref, _) => ref
                          .watch(verificationSpecialtiesProvider)
                          .when(
                            data: (items) => DropdownButtonFormField<String>(
                              initialValue:
                                  items.any((item) => item.id == specialtyId)
                                  ? specialtyId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Especialidad',
                              ),
                              items: items
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(item.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => specialtyId = value),
                            ),
                            loading: () => const CircularProgressIndicator(),
                            error: (error, _) => Text(error.toString()),
                          ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: years,
                    label: 'Años de experiencia',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: bio,
                    label: 'Biografía profesional',
                    maxLines: 4,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Los cambios en formación o certificaciones requieren revalidación',
                    ),
                    value: false,
                    onChanged: null,
                  ),
                  AppTextField(
                    controller: education,
                    label: 'Formación académica pública',
                    maxLines: 3,
                  ),
                  AppTextField(
                    controller: certificates,
                    label: 'Certificaciones públicas (una por línea)',
                    maxLines: 3,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar perfil públicamente'),
                    value: public,
                    onChanged: (value) => setState(() => public = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: 520,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Guardar',
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
              ),
            ),
          ],
        ),
      ),
    );

    final licenseValue = license.text.trim();
    final bioValue = bio.text.trim();
    final educationValue = education.text.trim();
    final certificateValues = certificates.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList();
    final yearsValue = int.tryParse(years.text.trim()) ?? 0;
    license.dispose();
    bio.dispose();
    education.dispose();
    certificates.dispose();
    years.dispose();
    if (save != true) return;

    try {
      await ref
          .read(professionalProfileRepositoryProvider)
          .update(
            licenseNumber: licenseValue,
            bio: bioValue,
            academicBackground: educationValue,
            publicCertifications: certificateValues,
            yearsExperience: yearsValue,
            publicProfileEnabled: public,
            specialtyId: specialtyId,
          );
      ref.invalidate(professionalProfileProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _addDocument(BuildContext context, WidgetRef ref) async {
    final typeValue = await selectPersonnelDocumentType(context, ref);
    if (typeValue == null || !context.mounted) {
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    final selected = picked?.files.single;
    if (selected == null || selected.bytes == null) {
      return;
    }
    try {
      final stored = await ref
          .read(filesRepositoryProvider)
          .upload(
            bytes: selected.bytes!,
            fileName: selected.name,
            category: 'professional-documents',
          );
      await ref
          .read(professionalProfileRepositoryProvider)
          .addDocument(documentType: typeValue, fileUrl: stored.fileUrl);
      ref.invalidate(professionalProfileProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.teal),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final ProfessionalDocument document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.description_outlined, color: AppColors.teal),
        title: Text(document.documentType),
        subtitle: Text(
          document.observation?.isNotEmpty == true
              ? document.observation!
              : _status(document.status),
        ),
        trailing: StatusPill(
          label: _status(document.status),
          color: document.status == 'approved'
              ? AppColors.success
              : document.status == 'rejected'
              ? AppColors.danger
              : AppColors.warning,
          dense: true,
        ),
      ),
    );
  }
}

String _status(String value) => switch (value) {
  'approved' => 'Aprobado',
  'rejected' => 'Rechazado',
  'under_review' => 'En revisión',
  'expired' => 'Vencido',
  _ => 'Pendiente',
};

String _roleLabel(String? primaryRoleCode, ProfessionalProfile profile) {
  return switch (primaryRoleCode) {
    'doctor_general' => 'Médico general',
    'doctor_specialist' => 'Médico especialista',
    'nurse' => 'Enfermería',
    _ => switch (profile.professionalType) {
      'doctor' => 'Profesional médico',
      'nurse' => 'Enfermería',
      _ => 'Profesional de salud',
    },
  };
}
