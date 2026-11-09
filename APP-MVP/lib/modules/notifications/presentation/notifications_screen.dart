import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/application/auth_controller.dart';
import '../application/notification_destination.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/notifications_controller.dart';
import '../domain/app_notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, this.embedded = false});

  final bool embedded;

  static const _categories = <(String, String, IconData)>[
    ('appointments', 'Citas', Icons.calendar_month_outlined),
    ('prescriptions', 'Recetas', Icons.medication_outlined),
    ('telemedicine', 'Telemedicina', Icons.video_call_outlined),
    ('emergencies', 'Emergencias', Icons.emergency_outlined),
    ('incidents', 'Incidentes y reclamos', Icons.support_agent_outlined),
    ('promotions', 'Promociones', Icons.campaign_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: embedded
            ? const PreferredSize(
                preferredSize: Size.fromHeight(kTextTabBarHeight),
                child: TabBar(
                  tabs: [
                    Tab(text: 'Actividad'),
                    Tab(text: 'Preferencias'),
                  ],
                ),
              )
            : AppBar(
                title: const Text('Notificaciones'),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Actividad'),
                    Tab(text: 'Preferencias'),
                  ],
                ),
              ),
        body: TabBarView(
          children: [_activity(context, ref), _preferences(context, ref)],
        ),
      ),
    );
  }

  Widget _activity(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider);
    return notifications.when(
      loading: () =>
          const AppLoadingState(message: 'Cargando tus notificaciones'),
      error: (error, _) => AppErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(notificationsControllerProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Sin notificaciones',
            message: 'Tu actividad importante aparecerá aquí.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsControllerProvider.future),
          child: AdaptivePage(
            maxWidth: 920,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: items.any((item) => !item.isRead)
                      ? () => ref
                            .read(notificationsControllerProvider.notifier)
                            .markAllRead()
                      : null,
                  child: const Text('Marcar todas como leídas'),
                ),
              ),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _NotificationCard(
                    item: item,
                    onTap: () => _openNotification(context, ref, item),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    final user = ref.read(authControllerProvider).user;
    final destination = user == null
        ? null
        : notificationDestination(item, user);
    try {
      await ref.read(notificationsControllerProvider.notifier).markRead(item);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo marcar la notificación como leída.'),
          ),
        );
      }
    }
    if (!context.mounted) return;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay una pantalla disponible para este aviso con tus permisos actuales.',
          ),
        ),
      );
      return;
    }
    context.go(destination);
  }

  Widget _preferences(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);
    return preferences.when(
      loading: () =>
          const AppLoadingState(message: 'Cargando tus preferencias'),
      error: (error, _) => AppErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(notificationPreferencesProvider),
      ),
      data: (stored) => AdaptivePage(
        maxWidth: 920,
        children: [
          const SectionHeader(
            title: 'Preferencias de avisos',
            subtitle: 'Elige dónde deseas recibir cada tipo de información.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < _categories.length; index++) ...[
                  _PreferenceTile(
                    category: _categories[index],
                    inAppEnabled: _enabled(
                      stored,
                      _categories[index].$1,
                      'in_app',
                    ),
                    pushEnabled: _enabled(
                      stored,
                      _categories[index].$1,
                      'push',
                    ),
                    onInAppChanged: (enabled) => _setPreference(
                      context,
                      ref,
                      _categories[index].$1,
                      'in_app',
                      enabled,
                    ),
                    onPushChanged: (enabled) => _setPreference(
                      context,
                      ref,
                      _categories[index].$1,
                      'push',
                      enabled,
                    ),
                  ),
                  if (index < _categories.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _enabled(
    List<NotificationPreference> values,
    String eventCode,
    String channel,
  ) {
    for (final value in values) {
      if (value.eventCode == eventCode && value.channel == channel) {
        return value.enabled;
      }
    }
    return true;
  }

  Future<void> _setPreference(
    BuildContext context,
    WidgetRef ref,
    String eventCode,
    String channel,
    bool enabled,
  ) async {
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .updatePreference(
            eventCode: eventCode,
            channel: channel,
            enabled: enabled,
          );
      ref.invalidate(notificationPreferencesProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: item.isRead ? null : AppColors.teal.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isRead
                ? Icons.notifications_none_rounded
                : Icons.notifications_active_rounded,
            color: item.isRead ? null : AppColors.teal,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(item.body),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatDate(item.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.category,
    required this.inAppEnabled,
    required this.pushEnabled,
    required this.onInAppChanged,
    required this.onPushChanged,
  });

  final (String, String, IconData) category;
  final bool inAppEnabled;
  final bool pushEnabled;
  final ValueChanged<bool> onInAppChanged;
  final ValueChanged<bool> onPushChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          ListTile(
            leading: Icon(category.$3),
            title: Text(category.$2),
            dense: true,
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            title: const Text('Dentro de la app'),
            value: inAppEnabled,
            activeThumbColor: AppColors.teal,
            onChanged: onInAppChanged,
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            title: const Text('En el celular'),
            value: pushEnabled,
            activeThumbColor: AppColors.teal,
            onChanged: onPushChanged,
          ),
        ],
      ),
    );
  }
}
