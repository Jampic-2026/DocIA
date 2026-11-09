import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/role_presentation.dart';
import '../application/account_controller.dart';
import '../domain/account_profile.dart';

/// Pantalla de cuenta/ajustes común a todos los roles.
/// Muestra los datos del usuario, preferencias de tema y cierre de sesión.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final profile = ref.watch(accountProfileProvider);
    final showInlineLogout =
        MediaQuery.sizeOf(context).width < AppDimensions.compactBreakpoint;
    final keepShellVisible = !showInlineLogout;
    final isAdmin = user?.hasRole('admin') ?? false;
    final isHumanResources = user?.hasRole('human_resources') ?? false;
    final isProfessional = user?.experience == UserExperience.professional;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: AdaptivePage(
        maxWidth: 920,
        children: [
          AppCard(
            child: profile.when(
              loading: () =>
                  const AppLoadingState(message: 'Cargando tu perfil'),
              error: (error, _) => AppErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(accountProfileProvider),
              ),
              data: (account) => Column(
                children: [
                  Row(
                    children: [
                      UserAvatar(name: account.fullName, radius: 32),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.fullName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(account.email),
                            const SizedBox(height: 6),
                            if (user != null)
                              StatusPill(
                                label: user.experience.displayName,
                                color: user.experience.color,
                                icon: user.experience.icon,
                                dense: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  _ProfileValue(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: account.phone,
                  ),
                  _ProfileValue(
                    icon: Icons.badge_outlined,
                    label: 'Documento',
                    value: [
                      account.documentType,
                      account.documentNumber,
                    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
                  ),
                  _ProfileValue(
                    icon: Icons.cake_outlined,
                    label: 'Fecha de nacimiento',
                    value: account.birthDate == null
                        ? null
                        : '${account.birthDate!.day.toString().padLeft(2, '0')}/'
                            '${account.birthDate!.month.toString().padLeft(2, '0')}/'
                            '${account.birthDate!.year}',
                  ),
                  _ProfileValue(
                    icon: Icons.public_outlined,
                    label: 'Nacionalidad',
                    value: account.nationality,
                  ),
                  _ProfileValue(
                    icon: Icons.location_on_outlined,
                    label: 'Dirección',
                    value: account.address?.addressLine,
                  ),
                  _ProfileValue(
                    icon: Icons.map_outlined,
                    label: 'Municipio y zona',
                    value: [
                      account.address?.municipality,
                      account.address?.zone,
                    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => _editProfile(context, ref, account),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar mis datos'),
                  ),
                ],
              ),
            ),
          ),
          if (!isProfessional) ...[
            const SectionHeader(title: 'General'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (!isHumanResources &&
                      user?.experience == UserExperience.patient) ...[
                    _SettingsTile(
                      icon: Icons.medical_services_outlined,
                      label: 'Postularme como profesional de salud',
                      onTap: () =>
                          context.pushNamed(AppRoutes.professionalApplication),
                    ),
                    const Divider(height: 1, indent: 56),
                  ],
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Ayuda, preguntas y demo',
                    onTap: () => _openAccountOption(
                      context,
                      user,
                      keepShellVisible,
                      scopedPath: 'help',
                      globalName: AppRoutes.help,
                    ),
                  ),
                  if (!isAdmin &&
                      !isHumanResources &&
                      (user?.can('consents.read') ?? false)) ...[
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      label: 'Privacidad y consentimientos',
                      onTap: () => _openAccountOption(
                        context,
                        user,
                        keepShellVisible,
                        scopedPath: 'consents',
                        globalName: AppRoutes.consents,
                      ),
                    ),
                  ],
                  if (!isHumanResources &&
                      (user?.can('incidents.read') ?? false)) ...[
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.support_agent_rounded,
                      label: 'Incidentes y reclamos',
                      onTap: () => _openAccountOption(
                        context,
                        user,
                        keepShellVisible,
                        scopedPath: 'incidents',
                        globalName: AppRoutes.incidents,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (user?.experience == UserExperience.patient || isProfessional) ...[
            const SectionHeader(title: 'Servicios'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.medical_services_outlined,
                    label: 'Servicios y tarifas',
                    onTap: () => _openAccountOption(
                      context,
                      user,
                      keepShellVisible,
                      scopedPath: 'catalog',
                      globalName: AppRoutes.catalog,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.toll_outlined,
                    label: 'Monedas Doc IA',
                    onTap: () => _openAccountOption(
                      context,
                      user,
                      keepShellVisible,
                      scopedPath: 'coins',
                      globalName: AppRoutes.coins,
                    ),
                  ),
                  if (user?.can('benefits.read') ?? false) ...[
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.redeem_outlined,
                      label: 'Beneficios',
                      onTap: () => _openAccountOption(
                        context,
                        user,
                        keepShellVisible,
                        scopedPath: 'benefits',
                        globalName: AppRoutes.benefits,
                      ),
                    ),
                  ],
                  if (user?.can('payments.read') ?? false) ...[
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.payments_outlined,
                      label: 'Pagos y órdenes de pago',
                      onTap: () => _openAccountOption(
                        context,
                        user,
                        keepShellVisible,
                        scopedPath: 'payments',
                        globalName: AppRoutes.payments,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SectionHeader(title: 'Apariencia'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                _ThemeOption(
                  label: 'Sistema',
                  icon: Icons.brightness_auto_rounded,
                  selected: themeMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .set(ThemeMode.system),
                ),
                _ThemeOption(
                  label: 'Claro',
                  icon: Icons.light_mode_rounded,
                  selected: themeMode == ThemeMode.light,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).set(ThemeMode.light),
                ),
                _ThemeOption(
                  label: 'Oscuro',
                  icon: Icons.dark_mode_rounded,
                  selected: themeMode == ThemeMode.dark,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
                ),
              ],
            ),
          ),
          if (showInlineLogout)
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          Center(
            child: Text(
              'Doc IA · v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    AccountProfile profile,
  ) async {
    final firstName = TextEditingController(text: profile.firstName);
    final lastName = TextEditingController(text: profile.lastName);
    final secondLastName = TextEditingController(text: profile.secondLastName);
    final phone = TextEditingController(text: profile.phone);
    final municipality = TextEditingController(
      text: profile.address?.municipality,
    );
    final zone = TextEditingController(text: profile.address?.zone);
    final addressLine = TextEditingController(
      text: profile.address?.addressLine,
    );
    final reference = TextEditingController(text: profile.address?.reference);
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Editar mis datos'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      controller: firstName,
                      label: 'Nombres',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: lastName,
                      label: 'Primer apellido',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: secondLastName,
                      label: 'Segundo apellido',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: phone,
                      label: 'Teléfono',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: municipality,
                      label: 'Municipio',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(controller: zone, label: 'Zona'),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: addressLine,
                      label: 'Dirección',
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: reference,
                      label: 'Referencia',
                      maxLines: 2,
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
                  busy: saving,
                  onCancel: () => Navigator.pop(dialogContext),
                  onConfirm: () async {
                        if (firstName.text.trim().isEmpty ||
                            lastName.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Los nombres y el primer apellido son obligatorios.',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await ref
                              .read(accountRepositoryProvider)
                              .updateProfile(
                                firstName: firstName.text.trim(),
                                lastName: lastName.text.trim(),
                                secondLastName: secondLastName.text.trim(),
                                phone: phone.text.trim(),
                                municipality: municipality.text.trim(),
                                zone: zone.text.trim(),
                                addressLine: addressLine.text.trim(),
                                reference: reference.text.trim(),
                              );
                          ref.invalidate(accountProfileProvider);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Tus datos fueron actualizados.',
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                          setDialogState(() => saving = false);
                        }
                      },
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      firstName.dispose();
      lastName.dispose();
      secondLastName.dispose();
      phone.dispose();
      municipality.dispose();
      zone.dispose();
      addressLine.dispose();
      reference.dispose();
    }
  }

  void _openAccountOption(
    BuildContext context,
    AppUser? user,
    bool keepShellVisible, {
    required String scopedPath,
    required String globalName,
  }) {
    final basePath = switch (user?.experience) {
      UserExperience.patient => AppRoutes.patientProfile,
      UserExperience.professional => AppRoutes.doctorProfile,
      UserExperience.administration => AppRoutes.adminProfile,
      UserExperience.operations => AppRoutes.operationsProfile,
      _ => null,
    };
    if (basePath != null) {
      context.push('$basePath/$scopedPath');
      return;
    }
    try {
      context.pushNamed(globalName);
      return;
    } catch (_) {
      context.push(globalName.startsWith('/') ? globalName : '/$globalName');
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas salir de tu cuenta?'),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Salir',
              confirmIcon: Icons.logout_rounded,
              onCancel: () => Navigator.pop(ctx, false),
              onConfirm: () => Navigator.pop(ctx, true),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }
}

class _ProfileValue extends StatelessWidget {
  const _ProfileValue({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(text == null || text.isEmpty ? 'No registrado' : text),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.teal : null),
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.teal)
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
