import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/family/application/family_controller.dart';
import '../../../modules/family/domain/family_member.dart';
import '../../../modules/family/domain/family_repository.dart';
import '../../../modules/family/presentation/create_dependent_screen.dart';
import 'clinical_profile_screen.dart';
import 'doctor_directory_screen.dart';
import 'emergency_screen.dart';

/// Gestión de familiares autorizados y dependientes, con sus permisos.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            MediaQuery.sizeOf(context).width < AppDimensions.compactBreakpoint,
        title: const Text('Familiares y dependientes'),
        actions: [
          IconButton(
            tooltip: 'Registrar menor a cargo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => const CreateDependentScreen(),
              ),
            ),
            icon: const Icon(Icons.child_care),
          ),
          IconButton(
            tooltip: 'Vincular dependiente',
            onPressed: () => _showRedeemForm(context, ref),
            icon: const Icon(Icons.link_rounded),
          ),
          IconButton(
            tooltip: 'Generar código para tutor',
            onPressed: () => _createLinkCode(context, ref),
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAuthorizationForm(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Agregar'),
      ),
      body: family.when(
        loading: () => const AppLoadingState(message: 'Cargando familiares'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyProvider),
        ),
        data: (members) => _FamilyList(members: members),
      ),
    );
  }

  void _showAuthorizationForm(BuildContext context) {
    showAppDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: const _FamilyAuthorizationForm(),
        ),
      ),
    );
  }

  void _showRedeemForm(BuildContext context, WidgetRef ref) {
    showAppDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: const _GuardianLinkForm(),
        ),
      ),
    );
  }

  Future<void> _createLinkCode(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(familyRepositoryProvider)
          .createGuardianLinkCode();
      if (!context.mounted) return;
      await showAppDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Código para vincular tutor',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Comparte este código únicamente con la persona que será responsable de tu cuenta.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox.square(
                    dimension: 184,
                    child: QrImageView(
                      data: result.code,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(
                    result.code,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'El tutor ingresa este código en Vincular dependiente. Vence en 15 minutos y solo puede utilizarse una vez.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: result.code),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copiar'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Listo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

class _GuardianLinkForm extends ConsumerStatefulWidget {
  const _GuardianLinkForm();

  @override
  ConsumerState<_GuardianLinkForm> createState() => _GuardianLinkFormState();
}

class _GuardianLinkFormState extends ConsumerState<_GuardianLinkForm> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _relationship = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(familyRepositoryProvider)
          .redeemGuardianLinkCode(
            code: _code.text.trim().toUpperCase(),
            relationship: _relationship.text.trim(),
          );
      ref.invalidate(familyProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dependiente vinculado correctamente.')),
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
              'Vincular dependiente',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Ingresa el código temporal generado desde la cuenta de la persona dependiente.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _code,
              label: 'Código de vinculación',
              hint: 'JMP-XXXX-XXXX',
              validator: (value) =>
                  RegExp(
                    r'^JMP-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Ingresa un código válido',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _relationship,
              label: 'Parentesco',
              hint: 'Ej.: Madre, padre, tutor legal',
              validator: (value) =>
                  (value?.trim().length ?? 0) < 2 ? 'Campo requerido' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _FamilyFormActions(
              saving: _saving,
              saveLabel: 'Vincular',
              savingLabel: 'Vinculando...',
              saveIcon: Icons.link_rounded,
              onCancel: () => Navigator.pop(context),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyAuthorizationForm extends ConsumerStatefulWidget {
  const _FamilyAuthorizationForm();

  @override
  ConsumerState<_FamilyAuthorizationForm> createState() =>
      _FamilyAuthorizationFormState();
}

class _FamilyAuthorizationFormState
    extends ConsumerState<_FamilyAuthorizationForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _relationship = TextEditingController();
  bool _history = false;
  bool _appointments = false;
  bool _emergencies = false;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(familyRepositoryProvider)
          .authorize(
            CreateFamilyAuthorizationCommand(
              email: _email.text.trim(),
              relationship: _relationship.text.trim(),
              canViewHistory: _history,
              canBookAppointments: _appointments,
              canHandleEmergencies: _emergencies,
            ),
          );
      ref.invalidate(familyProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Familiar autorizado correctamente.')),
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
              'Autorizar familiar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'La persona debe tener una cuenta activa en Doc IA.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _email,
              label: 'Correo de la cuenta',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!email.contains('@') || !email.contains('.')) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _relationship,
              label: 'Parentesco',
              hint: 'Ej.: Madre, hermano, pareja',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo requerido'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Permisos',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ver historial clínico'),
              value: _history,
              onChanged: (value) => setState(() => _history = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Agendar citas'),
              value: _appointments,
              onChanged: (value) => setState(() => _appointments = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gestionar emergencias'),
              value: _emergencies,
              onChanged: (value) => setState(() => _emergencies = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _FamilyFormActions(
              saving: _saving,
              saveLabel: 'Autorizar',
              savingLabel: 'Autorizando...',
              saveIcon: Icons.person_add_alt_1_rounded,
              onCancel: () => Navigator.pop(context),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyFormActions extends StatelessWidget {
  const _FamilyFormActions({
    required this.saving,
    required this.saveLabel,
    required this.savingLabel,
    required this.saveIcon,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final String saveLabel;
  final String savingLabel;
  final IconData saveIcon;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppDialogActions(
      cancelLabel: 'Cancelar',
      confirmLabel: saveLabel,
      busy: saving,
      busyLabel: savingLabel,
      confirmIcon: saveIcon,
      onCancel: onCancel,
      onConfirm: onSave,
    );
  }
}

class _FamilyList extends StatelessWidget {
  const _FamilyList({required this.members});
  final List<FamilyMember> members;

  @override
  Widget build(BuildContext context) {
    final dependents = members.where((m) => m.isDependent).toList();
    final authorized = members.where((m) => !m.isDependent).toList();

    if (members.isEmpty) {
      return const EmptyState(
        icon: Icons.family_restroom_rounded,
        title: 'Sin familiares vinculados',
        message: 'Los familiares y dependientes autorizados aparecerán aquí.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (dependents.isNotEmpty) ...[
          const SectionHeader(
            title: 'Dependientes',
            subtitle: 'Personas a tu cargo',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final m in dependents) ...[
            _FamilyCard(member: m),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
        if (authorized.isNotEmpty) ...[
          const SectionHeader(
            title: 'Familiares autorizados',
            subtitle: 'Adultos con acceso a tu cuenta',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final m in authorized) ...[
            _FamilyCard(member: m),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        const SizedBox(height: 72),
      ],
    );
  }
}

class _FamilyCard extends ConsumerWidget {
  const _FamilyCard({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                name: member.fullName,
                gradient: member.isDependent
                    ? AppColors.tealGradient
                    : AppColors.brandGradient,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      member.age == null
                          ? member.relationship
                          : '${member.relationship} · ${member.age} años',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: member.isDependent ? 'Dependiente' : 'Autorizado',
                color: member.isDependent ? AppColors.teal : AppColors.blue,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          _PermissionRow(
            label: 'Ver historial clínico',
            granted: member.canViewHistory,
          ),
          _PermissionRow(
            label: 'Agendar citas',
            granted: member.canBookAppointments,
          ),
          _PermissionRow(
            label: 'Gestionar emergencias',
            granted: member.canHandleEmergencies,
          ),
          if (member.patientId != null)
            Wrap(
              children: [
                if (member.canViewHistory)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ClinicalProfileScreen(
                          patientId: member.patientId,
                          canEdit:
                              member.isDependent && member.canBookAppointments,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.medical_information_outlined),
                    label: const Text('Perfil clínico'),
                  ),
                if (member.canBookAppointments)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DoctorDirectoryScreen(
                          initialPatientId: member.patientId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.event_available),
                    label: const Text('Agendar atención'),
                  ),
                if (member.canHandleEmergencies)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            EmergencyScreen(patientId: member.patientId),
                      ),
                    ),
                    icon: const Icon(Icons.emergency_outlined),
                    label: const Text('Solicitar emergencia'),
                  ),
              ],
            ),
          if (member.linkKind == 'outgoing') ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _edit(context, ref),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar permisos'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Revocar autorización',
                  color: AppColors.danger,
                  onPressed: () => _revoke(context, ref),
                  icon: const Icon(Icons.person_remove_outlined),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    var history = member.canViewHistory;
    var appointments = member.canBookAppointments;
    var emergencies = member.canHandleEmergencies;
    final relationship = TextEditingController(text: member.relationship);
    final saved = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar autorización'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: relationship, label: 'Parentesco'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ver historial clínico'),
                  value: history,
                  onChanged: (value) => setDialogState(() => history = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Agendar citas'),
                  value: appointments,
                  onChanged: (value) =>
                      setDialogState(() => appointments = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gestionar emergencias'),
                  value: emergencies,
                  onChanged: (value) =>
                      setDialogState(() => emergencies = value),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: 420,
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
    final relation = relationship.text.trim();
    relationship.dispose();
    if (saved != true || relation.isEmpty) return;
    await ref
        .read(familyRepositoryProvider)
        .updateAuthorization(
          member.id,
          CreateFamilyAuthorizationCommand(
            email: '',
            relationship: relation,
            canViewHistory: history,
            canBookAppointments: appointments,
            canHandleEmergencies: emergencies,
          ),
        );
    ref.invalidate(familyProvider);
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revocar autorización'),
        content: Text('${member.fullName} perderá los permisos otorgados.'),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Revocar',
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(familyRepositoryProvider).revokeAuthorization(member.id);
    ref.invalidate(familyProvider);
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});
  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: granted
                ? AppColors.success
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: granted
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
