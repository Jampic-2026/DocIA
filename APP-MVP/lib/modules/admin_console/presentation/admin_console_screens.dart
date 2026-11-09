import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/admin_console_controller.dart';
import '../domain/admin_console.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(adminOverviewProvider)
      .when(
        loading: () => const AppLoadingState(message: 'Cargando usuarios'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminOverviewProvider),
        ),
        data: (data) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: data.users.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final user = data.users[index];
            return AppCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(name: user.fullName),
                    title: Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${user.email}\n${user.roles.join(' · ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: StatusPill(
                      label: user.status,
                      color: user.status == 'active'
                          ? AppColors.success
                          : AppColors.warning,
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _roles(context, ref, user, data.roles),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('Roles'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _status(context, ref, user),
                          child: Text(
                            user.status == 'active' ? 'Suspender' : 'Activar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
  Future<void> _status(
    BuildContext context,
    WidgetRef ref,
    ManagedUser user,
  ) async {
    final status = user.status == 'active' ? 'suspended' : 'active';
    await ref
        .read(adminConsoleRepositoryProvider)
        .updateStatus(
          user.id,
          status,
          reason: status == 'suspended' ? 'Suspensión administrativa' : null,
        );
    ref.invalidate(adminOverviewProvider);
  }

  Future<void> _roles(
    BuildContext context,
    WidgetRef ref,
    ManagedUser user,
    List<ManagedRole> roles,
  ) async {
    final selected = user.roles.toSet();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Roles de ${user.fullName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final role in roles)
                  CheckboxListTile(
                    value: selected.contains(role.code),
                    title: Text(role.name),
                    subtitle: Text('${role.permissions.length} permisos'),
                    onChanged: (value) => setState(
                      () => value == true
                          ? selected.add(role.code)
                          : selected.remove(role.code),
                    ),
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
                confirmEnabled: selected.isNotEmpty,
                confirmIcon: Icons.save_outlined,
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
              ),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      await ref
          .read(adminConsoleRepositoryProvider)
          .updateRoles(user.id, selected.toList());
      ref.invalidate(adminOverviewProvider);
    }
  }
}

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  static const Set<String> _hiddenSettingKeys = {
    'payments.qr_image_url',
    'payments.qr_account_name',
    'payments.qr_bank_name',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(systemSettingsProvider)
      .when(
        loading: () => const AppLoadingState(message: 'Cargando configuración'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(systemSettingsProvider),
        ),
        data: (items) {
          final visibleItems = items
              .where((item) => !_hiddenSettingKeys.contains(item.key))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              SectionHeader(
                title: 'Configuración del sistema',
                subtitle: 'Valores administrados por la API',
                actionLabel: 'Agregar',
                onAction: () => _edit(context, ref, null),
              ),
              const SizedBox(height: AppSpacing.md),
              if (visibleItems.isEmpty)
                const Text('No existen parámetros configurados.')
              else
                for (final item in visibleItems) ...[
                  AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.key),
                      subtitle: Text(item.description ?? jsonEncode(item.value)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, ref, item),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          );
        },
      );
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SystemSetting? setting,
  ) async {
    final key = TextEditingController(text: setting?.key),
        value = TextEditingController(
          text: setting == null ? '' : jsonEncode(setting.value),
        ),
        description = TextEditingController(text: setting?.description);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(setting == null ? 'Agregar parámetro' : 'Editar parámetro'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: key,
                  label: 'Clave',
                  enabled: setting == null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: value, label: 'Valor JSON', maxLines: 6),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: description,
                  label: 'Descripción',
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Guardar',
              confirmIcon: Icons.save_outlined,
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    final keyValue = key.text.trim(),
        raw = value.text.trim(),
        descriptionValue = description.text.trim();
    key.dispose();
    value.dispose();
    description.dispose();
    if (save != true || keyValue.isEmpty) return;
    if (_hiddenSettingKeys.contains(keyValue)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El QR general de cobro se administra desde Pagos.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      await ref
          .read(adminConsoleRepositoryProvider)
          .updateSetting(keyValue, decoded, description: descriptionValue);
      ref.invalidate(systemSettingsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Valor JSON inválido: $error')));
      }
    }
  }
}
