import 'document_type_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../files/application/files_controller.dart';
import '../application/human_resources_controller.dart';
import '../domain/human_resources_repository.dart';

class ProfessionalApplicationScreen extends ConsumerStatefulWidget {
  const ProfessionalApplicationScreen({super.key});

  @override
  ConsumerState<ProfessionalApplicationScreen> createState() =>
      _ProfessionalApplicationScreenState();
}

class _ProfessionalApplicationScreenState
    extends ConsumerState<ProfessionalApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _license = TextEditingController();
  final _specialty = TextEditingController();
  String _role = 'doctor_general';
  final List<_PendingDocument> _documents = [];
  bool _submitting = false;
  bool _uploading = false;

  @override
  void dispose() {
    _license.dispose();
    _specialty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta al menos un documento.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final application = await ref
          .read(humanResourcesRepositoryProvider)
          .submitApplication(
            requestedRoleCode: _role,
            licenseNumber: _license.text.trim(),
            requestedSpecialty: _specialty.text.trim(),
          );
      for (final document in _documents) {
        final stored = await ref
            .read(filesRepositoryProvider)
            .upload(
              bytes: document.bytes,
              fileName: document.fileName,
              category: 'personnel-documents',
            );
        await ref
            .read(humanResourcesRepositoryProvider)
            .addApplicationDocument(
              applicationId: application.id,
              documentType: document.documentType,
              fileUrl: stored.fileUrl,
            );
      }
      _documents.clear();
      ref.invalidate(personnelApplicationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postulación y documentos enviados.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _uploadDocument(PersonnelApplication application) async {
    final documentType = await selectPersonnelDocumentType(
      context,
      ref,
      roleCode: application.requestedRoleCode,
    );
    if (documentType == null || !mounted) {
      return;
    }
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.single;
    if (file?.bytes == null) return;

    setState(() => _uploading = true);
    try {
      final stored = await ref
          .read(filesRepositoryProvider)
          .upload(
            bytes: file!.bytes!,
            fileName: file.name,
            category: 'personnel-documents',
          );
      await ref
          .read(humanResourcesRepositoryProvider)
          .addApplicationDocument(
            applicationId: application.id,
            documentType: documentType,
            fileUrl: stored.fileUrl,
          );
      ref.invalidate(personnelApplicationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documento adjuntado.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addPendingDocument() async {
    final documentType = await selectPersonnelDocumentType(
      context,
      ref,
      roleCode: _role,
    );
    if (documentType == null || !mounted) {
      return;
    }
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.single;
    if (file?.bytes == null) return;
    setState(() {
      _documents.add(
        _PendingDocument(
          documentType: documentType,
          fileName: file!.name,
          bytes: file.bytes!,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(personnelApplicationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Postulación profesional')),
      body: applications.when(
        loading: () => const AppLoadingState(message: 'Cargando postulación'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(personnelApplicationsProvider),
        ),
        data: (items) {
          PersonnelApplication? active;
          for (final item in items) {
            if (item.status == 'pending' || item.status == 'under_review') {
              active = item;
              break;
            }
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SectionHeader(
                title: 'Profesional de salud',
                subtitle:
                    'Envía tu postulación y adjunta los documentos requeridos. Un administrador revisará la información antes de habilitar tu perfil.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active == null
                            ? 'Nueva postulación'
                            : 'Postulación en curso',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: active?.requestedRoleCode ?? _role,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de profesional',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'doctor_general',
                            child: Text('Médico general'),
                          ),
                          DropdownMenuItem(
                            value: 'doctor_specialist',
                            child: Text('Médico especialista'),
                          ),
                          DropdownMenuItem(
                            value: 'nurse',
                            child: Text('Enfermería'),
                          ),
                        ],
                        onChanged: active == null
                            ? (value) => setState(
                                () => _role = value ?? 'doctor_general',
                              )
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (active == null) ...[
                        ref
                            .watch(documentRequirementsProvider)
                            .when(
                              data: (rules) {
                                final required =
                                    rules
                                        .where((rule) => rule.roleCode == _role)
                                        .firstOrNull
                                        ?.documentTypes ??
                                    const <String>[];
                                return Text(
                                  required.isEmpty
                                      ? 'El equipo de revisión aún no definió los requisitos de este rol. Puedes enviar tu postulación, pero no podrá aprobarse hasta que se definan.'
                                      : 'Documentos obligatorios: ${required.join(', ')}',
                                );
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (error, _) => Text(
                                'No se pudieron consultar los requisitos: $error',
                              ),
                            ),
                        AppTextField(
                          controller: _license,
                          label: 'Matrícula profesional',
                          hint: 'Ej.: M-12345',
                          validator: (value) => (value?.trim().length ?? 0) < 3
                              ? 'Ingresa tu matrícula'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _specialty,
                          label: 'Especialidad o área',
                          hint: 'Ej.: Medicina general, Pediatría',
                          validator: (value) => (value?.trim().length ?? 0) < 3
                              ? 'Ingresa tu especialidad o área'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _addPendingDocument,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Adjuntar documento'),
                        ),
                        if (_documents.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          for (final document in _documents)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.description_outlined),
                              title: Text(document.documentType),
                              subtitle: Text(document.fileName),
                              trailing: IconButton(
                                tooltip: 'Quitar',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _submitting
                                    ? null
                                    : () => setState(
                                        () => _documents.remove(document),
                                      ),
                              ),
                            ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.send_outlined),
                            label: Text(
                              _submitting
                                  ? 'Enviando...'
                                  : 'Enviar postulación',
                            ),
                          ),
                        ),
                      ] else ...[
                        StatusPill(
                          label: _statusLabel(active.status),
                          color: _statusColor(active.status),
                          dense: true,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploading
                                ? null
                                : () => _uploadDocument(active!),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(
                              _uploading
                                  ? 'Adjuntando...'
                                  : 'Adjuntar documento',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Historial'),
                const SizedBox(height: AppSpacing.md),
                for (final item in items) ...[
                  _ApplicationTile(application: item),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PendingDocument {
  const _PendingDocument({
    required this.documentType,
    required this.fileName,
    required this.bytes,
  });

  final String documentType;
  final String fileName;
  final List<int> bytes;
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application});

  final PersonnelApplication application;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.assignment_ind_outlined,
          color: _statusColor(application.status),
        ),
        title: Text(_roleLabel(application.requestedRoleCode)),
        subtitle: Text(
          application.rejectionReason?.isNotEmpty ?? false
              ? application.rejectionReason!
              : [
                  if (application.requestedSpecialty?.isNotEmpty ?? false)
                    application.requestedSpecialty!,
                  if (application.licenseNumber?.isNotEmpty ?? false)
                    'Matrícula ${application.licenseNumber}',
                  'Estado: ${_statusLabel(application.status)}',
                ].join(' · '),
        ),
        trailing: StatusPill(
          label: _statusLabel(application.status),
          color: _statusColor(application.status),
          dense: true,
        ),
      ),
    );
  }
}

String _roleLabel(String value) => switch (value) {
  'doctor_general' => 'Médico general',
  'doctor_specialist' => 'Médico especialista',
  'nurse' => 'Enfermería',
  _ => value,
};

String _statusLabel(String value) => switch (value) {
  'pending' => 'Pendiente',
  'under_review' => 'En revisión',
  'approved' => 'Aprobada',
  'rejected' => 'Rechazada',
  _ => value,
};

Color _statusColor(String value) => switch (value) {
  'approved' => AppColors.success,
  'rejected' => AppColors.danger,
  'under_review' => AppColors.blue,
  _ => AppColors.warning,
};
