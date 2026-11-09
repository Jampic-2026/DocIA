import 'package:flutter/material.dart';
import '../../../modules/guidance/presentation/support_calls_screen.dart';
import '../../../modules/guidance/presentation/risk_policy_screen.dart';
import '../../../modules/clinical_records/presentation/completion_policy_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/authorization/permission_codes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_file_link.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/audit/application/audit_controller.dart';
import '../../../modules/audit/domain/audit_event.dart';
import '../../../modules/catalog/presentation/catalog_screen.dart';
import '../../../modules/coins/presentation/coins_screen.dart';
import '../../../modules/human_resources/application/human_resources_controller.dart';
import '../../../modules/human_resources/domain/human_resources_repository.dart';
import '../../../modules/human_resources/domain/staff_member.dart';
import '../../../modules/human_resources/presentation/document_requirements_screen.dart';
import '../../../modules/human_resources/presentation/verification_selection_dialog.dart';
import '../../../modules/human_resources/presentation/professional_documents_screen.dart';
import '../../../modules/work_shifts/presentation/work_shifts_screen.dart';
import '../../../modules/partners/application/partners_controller.dart';
import '../../../modules/partners/domain/partner_summary.dart';
import '../../../modules/payments/presentation/payments_screen.dart';
import '../../../modules/integrations/presentation/google_workspace_screen.dart';
import '../../../modules/emergencies/presentation/emergency_operations_screen.dart';
import '../../../modules/clinical_records/presentation/clinical_corrections_screen.dart';
import '../../../modules/admin_console/presentation/admin_console_screens.dart';

/// Gestión administrativa con pestañas: validación de profesionales,
/// empresas asociadas y auditoría.
class AdminManagementScreen extends ConsumerWidget {
  const AdminManagementScreen({
    this.initialTab = 0,
    this.initialTabCode,
    super.key,
  });

  final int initialTab;
  final String? initialTabCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final tabs = _availableTabs(
      can: (permission) => user?.can(permission) ?? false,
    );
    if (tabs.isEmpty) {
      return const Scaffold(
        body: AppErrorState(
          message: 'Tu cuenta no tiene módulos administrativos disponibles.',
        ),
      );
    }
    final selectedIndex = _selectedTabIndex(tabs, initialTabCode, initialTab);
    return LayoutBuilder(
      builder: (context, constraints) {
        final usesSidebar =
            AppShellLayout.maybeOf(context)?.usesSidebar ??
            constraints.maxWidth >= AppDimensions.compactBreakpoint;
        if (usesSidebar) {
          return Scaffold(
            appBar: AppBar(title: Text(tabs[selectedIndex].label)),
            body: KeyedSubtree(
              key: ValueKey(tabs[selectedIndex].code),
              child: tabs[selectedIndex].builder(context),
            ),
          );
        }
        return DefaultTabController(
          length: tabs.length,
          initialIndex: selectedIndex,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Gestión'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final tab in tabs) Tab(text: tab.label)],
              ),
            ),
            body: TabBarView(
              children: [for (final tab in tabs) tab.builder(context)],
            ),
          ),
        );
      },
    );
  }
}

class _AdminTabSpec {
  const _AdminTabSpec({
    required this.code,
    required this.label,
    required this.builder,
  });

  final String code;
  final String label;
  final WidgetBuilder builder;
}

int _selectedTabIndex(
  List<_AdminTabSpec> tabs,
  String? code,
  int fallbackIndex,
) {
  final index = tabs.indexWhere((tab) => tab.code == code);
  if (index >= 0) return index;
  return fallbackIndex.clamp(0, tabs.length - 1).toInt();
}

List<_AdminTabSpec> _availableTabs({required bool Function(String) can}) {
  return [
    if (can(PermissionCodes.aiManage))
      _AdminTabSpec(
        code: 'risk_policy',
        label: 'Reglas clínicas',
        builder: (_) => const RiskPolicyScreen(),
      ),
    if (can(PermissionCodes.emergenciesManage))
      _AdminTabSpec(
        code: 'support_calls',
        label: 'Orientación',
        builder: (_) => const SupportCallsScreen(),
      ),
    if (can(PermissionCodes.administrationManage))
      _AdminTabSpec(
        code: 'profile_completion',
        label: 'Completitud',
        builder: (_) => const CompletionPolicyScreen(),
      ),
    if (can(PermissionCodes.humanResourcesRead))
      _AdminTabSpec(
        code: 'work_shifts',
        label: 'Turnos',
        builder: (_) => const WorkShiftsScreen(),
      ),
    if (can(PermissionCodes.humanResourcesManage))
      _AdminTabSpec(
        code: 'document_requirements',
        label: 'Requisitos',
        builder: (_) => const DocumentRequirementsScreen(),
      ),
    if (can(PermissionCodes.professionalsRead))
      const _AdminTabSpec(
        code: 'professionals',
        label: 'Profesionales',
        builder: _buildProfessionalsTab,
      ),
    if (can(PermissionCodes.humanResourcesRead))
      const _AdminTabSpec(
        code: 'applications',
        label: 'Postulaciones',
        builder: _buildPersonnelApplicationsTab,
      ),
    if (can(PermissionCodes.partnersRead))
      const _AdminTabSpec(
        code: 'companies',
        label: 'Empresas',
        builder: _buildCompaniesTab,
      ),
    if (can(PermissionCodes.auditRead))
      const _AdminTabSpec(
        code: 'audit',
        label: 'Auditoría',
        builder: _buildAuditTab,
      ),
    if (can(PermissionCodes.emergenciesRead))
      const _AdminTabSpec(
        code: 'emergencies',
        label: 'Emergencias',
        builder: _buildEmergencyOperationsScreen,
      ),
    if (can(PermissionCodes.clinicalRecordsManage))
      const _AdminTabSpec(
        code: 'corrections',
        label: 'Correcciones',
        builder: _buildClinicalCorrectionsScreen,
      ),
    if (can(PermissionCodes.administrationManage))
      const _AdminTabSpec(
        code: 'integrations',
        label: 'Integraciones',
        builder: _buildGoogleWorkspaceScreen,
      ),
    if (can(PermissionCodes.usersRead))
      const _AdminTabSpec(
        code: 'users',
        label: 'Usuarios',
        builder: _buildAdminUsersScreen,
      ),
    if (can(PermissionCodes.catalogManage))
      const _AdminTabSpec(
        code: 'catalog',
        label: 'Servicios y tarifas',
        builder: _buildCatalogScreen,
      ),
    if (can(PermissionCodes.coinsManage))
      const _AdminTabSpec(
        code: 'coins',
        label: 'Paquetes y QR',
        builder: _buildCoinsScreen,
      ),
    if (can(PermissionCodes.paymentsManage))
      const _AdminTabSpec(
        code: 'payments',
        label: 'Pagos',
        builder: _buildPaymentsScreen,
      ),
    if (can(PermissionCodes.administrationRead))
      const _AdminTabSpec(
        code: 'settings',
        label: 'Configuración',
        builder: _buildAdminSettingsScreen,
      ),
  ];
}

Widget _buildProfessionalsTab(BuildContext context) =>
    const _ProfessionalsTab();
Widget _buildPersonnelApplicationsTab(BuildContext context) =>
    const _PersonnelApplicationsTab();
Widget _buildCompaniesTab(BuildContext context) => const _CompaniesTab();
Widget _buildAuditTab(BuildContext context) => const _AuditTab();
Widget _buildEmergencyOperationsScreen(BuildContext context) =>
    const EmergencyOperationsScreen();
Widget _buildClinicalCorrectionsScreen(BuildContext context) =>
    const ClinicalCorrectionsScreen(embedded: true);
Widget _buildGoogleWorkspaceScreen(BuildContext context) =>
    const GoogleWorkspaceScreen();
Widget _buildAdminUsersScreen(BuildContext context) => const AdminUsersScreen();
Widget _buildCatalogScreen(BuildContext context) =>
    const CatalogScreen(embedded: true);
Widget _buildCoinsScreen(BuildContext context) =>
    const CoinsScreen(embedded: true);
Widget _buildPaymentsScreen(BuildContext context) =>
    const PaymentsScreen(embedded: true);
Widget _buildAdminSettingsScreen(BuildContext context) =>
    const AdminSettingsScreen();

class _PersonnelApplicationsTab extends ConsumerWidget {
  const _PersonnelApplicationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(personnelApplicationsProvider);
    final documents = ref.watch(personnelDocumentsProvider);
    if (applications.isLoading || documents.isLoading) {
      return const AppLoadingState(message: 'Cargando postulaciones');
    }
    final error = applications.error ?? documents.error;
    if (error != null) {
      return AppErrorState(
        message: error.toString(),
        onRetry: () {
          ref.invalidate(personnelApplicationsProvider);
          ref.invalidate(personnelDocumentsProvider);
        },
      );
    }
    final apps = applications.value ?? const <PersonnelApplication>[];
    final docs = documents.value ?? const <PersonnelDocument>[];
    if (apps.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_ind_outlined,
        title: 'Sin postulaciones',
        message: 'Las solicitudes profesionales aparecerán aquí.',
      );
    }
    final active = apps
        .where((item) => item.status != 'approved' && item.status != 'rejected')
        .toList();
    final decided = apps
        .where((item) => item.status == 'approved' || item.status == 'rejected')
        .toList();
    return AdaptivePage(
      maxWidth: 1180,
      children: [
        if (active.isNotEmpty)
          const SectionHeader(
            title: 'Pendientes y en revisión',
            subtitle: 'Postulaciones que aún requieren revisión documental.',
          ),
        for (final application in active)
          Builder(
            builder: (context) {
              final applicationDocs = docs
                  .where((document) => document.applicationId == application.id)
                  .toList();
              return _PersonnelApplicationCard(
                application: application,
                documents: applicationDocs,
              );
            },
          ),
        if (decided.isNotEmpty)
          const SectionHeader(
            title: 'Historial de decisiones',
            subtitle: 'Postulaciones aprobadas y rechazadas.',
          ),
        for (final application in decided)
          Builder(
            builder: (context) {
              final applicationDocs = docs
                  .where((document) => document.applicationId == application.id)
                  .toList();
              return _PersonnelApplicationCard(
                application: application,
                documents: applicationDocs,
              );
            },
          ),
      ],
    );
  }
}

class _PersonnelApplicationCard extends ConsumerWidget {
  const _PersonnelApplicationCard({
    required this.application,
    required this.documents,
  });

  final PersonnelApplication application;
  final List<PersonnelDocument> documents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingDocs = documents.where((item) => item.status != 'approved');
    final canApprove =
        application.status != 'approved' &&
        application.status != 'rejected' &&
        documents.isNotEmpty &&
        pendingDocs.isEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, color: AppColors.teal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.applicantName?.trim().isNotEmpty ?? false
                          ? application.applicantName!
                          : application.applicantEmail ?? 'Postulante',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      [
                        _roleLabel(application.requestedRoleCode),
                        if (application.requestedSpecialty?.isNotEmpty ?? false)
                          application.requestedSpecialty!,
                        if (application.licenseNumber?.isNotEmpty ?? false)
                          'Matrícula ${application.licenseNumber}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: _applicationStatusLabel(application.status),
                color: _applicationStatusColor(application.status),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (documents.isEmpty)
            Text(
              'Sin documentos adjuntos.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final document in documents) ...[
              _PersonnelDocumentRow(document: document),
              const SizedBox(height: AppSpacing.sm),
            ],
          if (application.status == 'rejected' &&
              (application.rejectionReason?.isNotEmpty ?? false)) ...[
            const Divider(height: AppSpacing.lg),
            Text(
              'Motivo del rechazo',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(application.rejectionReason!),
          ],
          if (application.status != 'approved' &&
              application.status != 'rejected') ...[
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _reviewApplication(context, ref, approved: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: canApprove
                        ? () => _reviewApplication(context, ref, approved: true)
                        : null,
                    child: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reviewApplication(
    BuildContext context,
    WidgetRef ref, {
    required bool approved,
  }) async {
    VerificationSelection? selection;
    if (approved) {
      selection = await selectVerification(
        context,
        fixedRole: application.requestedRoleCode,
      );
      if (selection == null) return;
    }
    if (!context.mounted) return;
    String? reason;
    if (!approved) {
      final controller = TextEditingController();
      reason = await showAppDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rechazar postulación'),
          content: AppTextField(
            controller: controller,
            label: 'Motivo',
            maxLines: 3,
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Rechazar',
                onCancel: () => Navigator.pop(dialogContext),
                onConfirm: () {
                  final value = controller.text.trim();
                  if (value.length >= 3) Navigator.pop(dialogContext, value);
                },
              ),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    try {
      await ref
          .read(humanResourcesRepositoryProvider)
          .reviewApplication(
            applicationId: application.id,
            status: approved ? 'approved' : 'rejected',
            reason: reason,
            licenseNumber: application.licenseNumber,
            specialtyId: selection?.specialtyId,
          );
      ref.invalidate(personnelApplicationsProvider);
      ref.invalidate(personnelDocumentsProvider);
      ref.invalidate(staffProvider);
      ref.invalidate(auditEventsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Postulación aprobada.' : 'Postulación rechazada.',
          ),
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

class _PersonnelDocumentRow extends ConsumerWidget {
  const _PersonnelDocumentRow({required this.document});

  final PersonnelDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewed =
        document.status == 'approved' || document.status == 'rejected';
    return Row(
      children: [
        Icon(
          Icons.description_outlined,
          color: _documentStatusColor(document.status),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.documentType,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _documentStatusLabel(document.status),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (!reviewed) ...[
          IconButton(
            tooltip: 'Rechazar documento',
            color: AppColors.danger,
            onPressed: () => _reviewDocument(context, ref, approved: false),
            icon: const Icon(Icons.close_rounded),
          ),
          IconButton(
            tooltip: 'Aprobar documento',
            color: AppColors.success,
            onPressed: () => _reviewDocument(context, ref, approved: true),
            icon: const Icon(Icons.check_rounded),
          ),
        ],
        AppFileLink(fileUrl: document.fileUrl, label: 'Ver'),
      ],
    );
  }

  Future<void> _reviewDocument(
    BuildContext context,
    WidgetRef ref, {
    required bool approved,
  }) async {
    String? observation;
    if (!approved) {
      final controller = TextEditingController();
      observation = await showAppDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rechazar documento'),
          content: AppTextField(
            controller: controller,
            label: 'Observación',
            maxLines: 3,
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Rechazar',
                onCancel: () => Navigator.pop(dialogContext),
                onConfirm: () {
                  final value = controller.text.trim();
                  if (value.length >= 3) Navigator.pop(dialogContext, value);
                },
              ),
            ),
          ],
        ),
      );
      controller.dispose();
      if (observation == null) return;
    }
    try {
      await ref
          .read(humanResourcesRepositoryProvider)
          .reviewDocument(
            documentId: document.id,
            status: approved ? 'approved' : 'rejected',
            observation: observation,
          );
      ref.invalidate(personnelDocumentsProvider);
      ref.invalidate(auditEventsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Documento aprobado.' : 'Documento rechazado.',
          ),
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

String _roleLabel(String value) => switch (value) {
  'doctor_general' => 'Médico general',
  'doctor_specialist' => 'Médico especialista',
  'nurse' => 'Enfermería',
  _ => value,
};

String _applicationStatusLabel(String value) => switch (value) {
  'pending' => 'Pendiente',
  'under_review' => 'En revisión',
  'approved' => 'Aprobada',
  'rejected' => 'Rechazada',
  _ => value,
};

Color _applicationStatusColor(String value) => switch (value) {
  'approved' => AppColors.success,
  'rejected' => AppColors.danger,
  'under_review' => AppColors.blue,
  _ => AppColors.warning,
};

String _documentStatusLabel(String value) => switch (value) {
  'approved' => 'Documento aprobado',
  'rejected' => 'Documento rechazado',
  _ => 'Pendiente de revisión',
};

Color _documentStatusColor(String value) => switch (value) {
  'approved' => AppColors.success,
  'rejected' => AppColors.danger,
  _ => AppColors.warning,
};

/// Validación / habilitación de profesionales.
class _ProfessionalsTab extends ConsumerWidget {
  const _ProfessionalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(staffProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando personal'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(staffProvider),
          ),
          data: (doctors) => _staffList(context, ref, doctors),
        );
  }

  Widget _staffList(
    BuildContext context,
    WidgetRef ref,
    List<StaffMember> doctors,
  ) {
    if (doctors.isEmpty) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Sin personal',
        message: 'El personal registrado aparecerá aquí.',
      );
    }
    return AdaptivePage(
      maxWidth: 1180,
      children: [
        for (final d in doctors)
          AppCard(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => _showStaffDetails(context, d),
              child: Column(
                children: [
                  Row(
                    children: [
                      UserAvatar(name: d.fullName),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              d.specialty ?? d.professionalType,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: StatusPill(
                      label: _verificationLabel(d.verificationStatus),
                      color: _verificationColor(d.verificationStatus),
                      icon: _verificationIcon(d.verificationStatus),
                      dense: true,
                    ),
                  ),
                  if (d.verificationStatus != 'approved') ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _review(context, ref, d, approved: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              minimumSize: const Size(0, 42),
                            ),
                            child: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                _review(context, ref, d, approved: true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 42),
                            ),
                            child: const Text('Validar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showStaffDetails(BuildContext context, StaffMember member) {
    final navigator = Navigator.of(context);
    return showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detalle del profesional'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  UserAvatar(name: member.fullName, radius: 30),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.fullName,
                          style: Theme.of(dialogContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(member.specialty ?? member.professionalType),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              _StaffDetailRow(
                label: 'Tipo profesional',
                value: member.professionalType,
              ),
              _StaffDetailRow(label: 'Especialidad', value: member.specialty),
              OutlinedButton.icon(
                onPressed: () {
                  if (!navigator.mounted) return;
                  Navigator.of(dialogContext).pop();
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfessionalDocumentsScreen(
                        professionalId: member.professionalId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Revisar documentos'),
              ),
              _StaffDetailRow(
                label: 'Verificación',
                value: _verificationLabel(member.verificationStatus),
              ),
              _StaffDetailRow(
                label: 'Código de empleado',
                value: member.employeeCode,
              ),
              _StaffDetailRow(label: 'Contrato', value: member.contractType),
              _StaffDetailRow(
                label: 'Estado laboral',
                value: member.employmentStatus,
              ),
              _StaffDetailRow(
                label: 'Fecha de alta',
                value: member.hiredAt == null
                    ? null
                    : DateFormat(
                        'dd/MM/yyyy',
                      ).format(member.hiredAt!.toLocal()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    StaffMember member, {
    required bool approved,
  }) async {
    VerificationSelection? selection;
    String? reason;
    if (!approved) {
      final controller = TextEditingController();
      reason = await showAppDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rechazar profesional'),
          content: AppTextField(
            controller: controller,
            label: 'Motivo',
            hint: 'Indica el motivo del rechazo',
            maxLines: 3,
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Confirmar rechazo',
                onCancel: () => Navigator.pop(dialogContext),
                onConfirm: () {
                  final value = controller.text.trim();
                  if (value.length >= 3) Navigator.pop(dialogContext, value);
                },
              ),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    } else {
      selection = await selectVerification(
        context,
        professionalType: member.professionalType,
      );
      if (selection == null) return;
    }

    try {
      await ref
          .read(humanResourcesRepositoryProvider)
          .reviewProfessional(
            professionalId: member.professionalId,
            status: approved ? 'approved' : 'rejected',
            reason: reason,
            roleCode: selection?.roleCode,
            specialtyId: selection?.specialtyId,
          );
      ref.invalidate(staffProvider);
      ref.invalidate(auditEventsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Profesional validado correctamente.'
                : 'Solicitud rechazada.',
          ),
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

class _StaffDetailRow extends StatelessWidget {
  const _StaffDetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final shownValue = value?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              shownValue == null || shownValue.isEmpty
                  ? 'No registrado'
                  : shownValue,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _verificationLabel(String status) => switch (status) {
  'approved' => 'Validado',
  'rejected' => 'Rechazado',
  'under_review' => 'En revisión',
  'expired' => 'Vencido',
  _ => 'Pendiente',
};

Color _verificationColor(String status) => switch (status) {
  'approved' => AppColors.success,
  'rejected' => AppColors.danger,
  'expired' => AppColors.warning,
  _ => AppColors.warning,
};

IconData _verificationIcon(String status) => switch (status) {
  'approved' => Icons.verified_rounded,
  'rejected' => Icons.cancel_rounded,
  'expired' => Icons.event_busy_rounded,
  _ => Icons.hourglass_bottom_rounded,
};

class _CompaniesTab extends ConsumerWidget {
  const _CompaniesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(partnersProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando empresas'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(partnersProvider),
          ),
          data: (companies) => _companiesList(context, companies),
        );
  }

  Widget _companiesList(BuildContext context, List<PartnerSummary> companies) {
    if (companies.isEmpty) {
      return const EmptyState(
        icon: Icons.business_outlined,
        title: 'Sin empresas asociadas',
        message: 'Las empresas registradas aparecerán aquí.',
      );
    }
    return AdaptivePage(
      maxWidth: 1180,
      children: [
        for (final company in companies)
          AppCard(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => _showCompanyDetail(context, company),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.business_rounded,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                company.planName ??
                                    '${company.partnerType} · ${company.siteCount} sede(s)',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ver detalle',
                          onPressed: () => _showCompanyDetail(context, company),
                          icon: const Icon(Icons.open_in_full_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: StatusPill(
                        label: company.isActive ? 'Activa' : 'En revisión',
                        color: company.isActive
                            ? AppColors.success
                            : AppColors.warning,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showCompanyDetail(
    BuildContext context,
    PartnerSummary company,
  ) {
    final detailRows = <_CompanyDetailRow>[
      _CompanyDetailRow('Nombre', company.name),
      _CompanyDetailRow('Tipo', company.partnerType),
      _CompanyDetailRow('NIT / Identificación tributaria', company.taxId),
      _CompanyDetailRow('Teléfono', company.phone),
      _CompanyDetailRow('Correo', company.email),
      _CompanyDetailRow('Dirección', company.address),
      _CompanyDetailRow('Sedes registradas', company.siteCount.toString()),
      _CompanyDetailRow('Plan', company.planName),
      _CompanyDetailRow('Estado de suscripción', company.subscriptionStatus),
      _CompanyDetailRow(
        'Estado operativo',
        company.isActive ? 'Activa' : 'En revisión',
      ),
    ];
    return showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.business_rounded),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(company.name)),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(
                      label: company.isActive ? 'Activa' : 'En revisión',
                      color: company.isActive
                          ? AppColors.success
                          : AppColors.warning,
                      dense: true,
                    ),
                    if (company.subscriptionStatus?.isNotEmpty ?? false)
                      StatusPill(
                        label: company.subscriptionStatus!,
                        color: AppColors.teal,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final row in detailRows)
                  if (row.value?.trim().isNotEmpty ?? false) ...[
                    _CompanyDetailItem(row: row),
                    const Divider(height: AppSpacing.lg),
                  ],
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: 180,
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyDetailRow {
  const _CompanyDetailRow(this.label, this.value);

  final String label;
  final String? value;
}

class _CompanyDetailItem extends StatelessWidget {
  const _CompanyDetailItem({required this.row});

  final _CompanyDetailRow row;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final label = Text(
          row.label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondaryLight),
        );
        final value = SelectableText(
          row.value ?? '',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: AppSpacing.xs),
              value,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 210, child: label),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: value),
          ],
        );
      },
    );
  }
}

class _AuditTab extends ConsumerStatefulWidget {
  const _AuditTab();

  @override
  ConsumerState<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<_AuditTab> {
  final _search = TextEditingController();
  String? _module;
  String? _action;
  DateTime? _from;
  DateTime? _to;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(auditEventsProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando auditoría'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(auditEventsProvider),
          ),
          data: (events) {
            final filtered = _filtered(events);
            final totalPages = _pageCount(filtered.length);
            final currentPage = totalPages == 0
                ? 0
                : _page.clamp(0, totalPages - 1).toInt();
            if (currentPage != _page) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _page = currentPage);
              });
            }
            if (events.isEmpty) {
              return const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'Sin eventos de auditoría',
                message: 'Los eventos registrados aparecerán aquí.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(auditEventsProvider.future),
              child: _AuditEventsList(
                events: filtered,
                allEvents: events,
                page: currentPage,
                pageSize: 25,
                search: _search,
                selectedModule: _module,
                selectedAction: _action,
                from: _from,
                to: _to,
                onSearchChanged: (_) => setState(() => _page = 0),
                onModuleChanged: (value) => setState(() {
                  _module = value;
                  _page = 0;
                }),
                onActionChanged: (value) => setState(() {
                  _action = value;
                  _page = 0;
                }),
                onPickFrom: () => _pickDate(context, from: true),
                onPickTo: () => _pickDate(context, from: false),
                onClear: _clearFilters,
                onPreviousPage: currentPage > 0
                    ? () => setState(() => _page = currentPage - 1)
                    : null,
                onNextPage: currentPage < totalPages - 1
                    ? () => setState(() => _page = currentPage + 1)
                    : null,
              ),
            );
          },
        );
  }

  List<AuditEvent> _filtered(List<AuditEvent> events) {
    final query = _search.text.trim().toLowerCase();
    return events.where((event) {
      if (_module != null && event.module != _module) return false;
      if (_action != null && event.action != _action) return false;
      final created = event.createdAt.toLocal();
      if (_from != null && created.isBefore(_dayStart(_from!))) return false;
      if (_to != null && created.isAfter(_dayEnd(_to!))) return false;
      if (query.isEmpty) return true;
      final haystack = [
        event.actorName,
        event.actorRole,
        event.entityType,
        event.reason,
        event.module,
        event.action,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _pickDate(BuildContext context, {required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
      _page = 0;
    });
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _module = null;
      _action = null;
      _from = null;
      _to = null;
      _page = 0;
    });
  }

  int _pageCount(int total) => total == 0 ? 0 : ((total - 1) ~/ 25) + 1;

  DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  DateTime _dayEnd(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}

class _AuditEventsList extends StatelessWidget {
  const _AuditEventsList({
    required this.events,
    required this.allEvents,
    required this.page,
    required this.pageSize,
    required this.search,
    required this.onSearchChanged,
    required this.onModuleChanged,
    required this.onActionChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClear,
    this.onPreviousPage,
    this.onNextPage,
    this.selectedModule,
    this.selectedAction,
    this.from,
    this.to,
  });

  final List<AuditEvent> events;
  final List<AuditEvent> allEvents;
  final int page;
  final int pageSize;
  final TextEditingController search;
  final String? selectedModule;
  final String? selectedAction;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onModuleChanged;
  final ValueChanged<String?> onActionChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClear;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    final modules = allEvents.map((event) => event.module).toSet().toList()
      ..sort();
    final actions = allEvents.map((event) => event.action).toSet().toList()
      ..sort();
    final pageStart = events.isEmpty ? 0 : page * pageSize;
    final pageEnd = (pageStart + pageSize) > events.length
        ? events.length
        : pageStart + pageSize;
    final visibleEvents = events.sublist(pageStart, pageEnd);
    final totalPages = events.isEmpty
        ? 0
        : ((events.length - 1) ~/ pageSize) + 1;
    return AdaptivePage(
      maxWidth: 1180,
      spacing: AppSpacing.sm,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  if (!wide) {
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: _filterControls(
                        modules: modules,
                        actions: actions,
                        searchWidth: constraints.maxWidth
                            .clamp(260.0, 420.0)
                            .toDouble(),
                        selectWidth: constraints.maxWidth
                            .clamp(220.0, 320.0)
                            .toDouble(),
                        dateWidth: constraints.maxWidth
                            .clamp(160.0, 220.0)
                            .toDouble(),
                      ),
                    );
                  }
                  final firstRowWidth =
                      (constraints.maxWidth - (AppSpacing.md * 2)) / 3;
                  final secondRowWidth =
                      (constraints.maxWidth - (AppSpacing.md * 2)) / 3;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _AuditSearchField(
                              controller: search,
                              onChanged: onSearchChanged,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: firstRowWidth.clamp(210.0, 260.0).toDouble(),
                            child: _AuditModuleFilter(
                              value: selectedModule,
                              modules: modules,
                              onChanged: onModuleChanged,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: firstRowWidth.clamp(220.0, 280.0).toDouble(),
                            child: _AuditActionFilter(
                              value: selectedAction,
                              actions: actions,
                              onChanged: onActionChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          SizedBox(
                            width: secondRowWidth
                                .clamp(180.0, 240.0)
                                .toDouble(),
                            child: _DateFilterButton(
                              label: 'Desde',
                              value: from,
                              onPressed: onPickFrom,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: secondRowWidth
                                .clamp(180.0, 240.0)
                                .toDouble(),
                            child: _DateFilterButton(
                              label: 'Hasta',
                              value: to,
                              onPressed: onPickTo,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: secondRowWidth
                                .clamp(160.0, 220.0)
                                .toDouble(),
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: onClear,
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('Limpiar'),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                events.isEmpty
                    ? '0 de ${allEvents.length} eventos'
                    : '${pageStart + 1}-$pageEnd de ${events.length} eventos filtrados',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (events.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Sin resultados',
            message: 'No hay eventos que coincidan con los filtros.',
          ),
        for (final event in visibleEvents)
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                  child: Icon(
                    _moduleIcon(event.module),
                    color: AppColors.navy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _actionLabel(event.action),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        event.actorName ??
                            event.actorRole ??
                            'Acción automática del sistema',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.entityType?.isNotEmpty ?? false)
                        Text(
                          event.entityType!,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 64,
                  child: Text(
                    DateFormat(
                      'dd/MM\nHH:mm',
                    ).format(event.createdAt.toLocal()),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (totalPages > 1)
          _AuditPagination(
            page: page,
            totalPages: totalPages,
            onPrevious: onPreviousPage,
            onNext: onNextPage,
          ),
      ],
    );
  }

  List<Widget> _filterControls({
    required List<String> modules,
    required List<String> actions,
    required double searchWidth,
    required double selectWidth,
    required double dateWidth,
  }) {
    return [
      SizedBox(
        width: searchWidth,
        child: _AuditSearchField(
          controller: search,
          onChanged: onSearchChanged,
        ),
      ),
      SizedBox(
        width: selectWidth,
        child: _AuditModuleFilter(
          value: selectedModule,
          modules: modules,
          onChanged: onModuleChanged,
        ),
      ),
      SizedBox(
        width: selectWidth,
        child: _AuditActionFilter(
          value: selectedAction,
          actions: actions,
          onChanged: onActionChanged,
        ),
      ),
      SizedBox(
        width: dateWidth,
        child: _DateFilterButton(
          label: 'Desde',
          value: from,
          onPressed: onPickFrom,
        ),
      ),
      SizedBox(
        width: dateWidth,
        child: _DateFilterButton(
          label: 'Hasta',
          value: to,
          onPressed: onPickTo,
        ),
      ),
      SizedBox(
        width: dateWidth,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Limpiar'),
        ),
      ),
    ];
  }

  static IconData _moduleIcon(String module) {
    switch (module) {
      case 'auth':
        return Icons.login_rounded;
      case 'professionals':
      case 'human_resources':
        return Icons.verified_user_rounded;
      case 'emergencies':
        return Icons.emergency_rounded;
      case 'prescriptions':
        return Icons.receipt_long_rounded;
      case 'patients':
      case 'users':
        return Icons.person_rounded;
      default:
        return Icons.fact_check_rounded;
    }
  }

  static String _actionLabel(String action) {
    return action
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _AuditSearchField extends StatelessWidget {
  const _AuditSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        decoration: const InputDecoration(
          labelText: 'Paciente, actor o motivo',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
    );
  }
}

class _AuditModuleFilter extends StatelessWidget {
  const _AuditModuleFilter({
    required this.value,
    required this.modules,
    required this.onChanged,
  });

  final String? value;
  final List<String> modules;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Módulo'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Todos')),
        for (final module in modules)
          DropdownMenuItem<String>(
            value: module,
            child: Text(module, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (selected) =>
          onChanged(selected?.isEmpty ?? true ? null : selected),
    );
  }
}

class _AuditActionFilter extends StatelessWidget {
  const _AuditActionFilter({
    required this.value,
    required this.actions,
    required this.onChanged,
  });

  final String? value;
  final List<String> actions;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Acción'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Todas')),
        for (final action in actions)
          DropdownMenuItem<String>(
            value: action,
            child: Text(
              _AuditEventsList._actionLabel(action),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (selected) =>
          onChanged(selected?.isEmpty ?? true ? null : selected),
    );
  }
}

class _AuditPagination extends StatelessWidget {
  const _AuditPagination({
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Página ${page + 1} de $totalPages',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? label
        : '$label ${DateFormat('dd/MM/yyyy').format(value!)}';
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(text),
      ),
    );
  }
}
