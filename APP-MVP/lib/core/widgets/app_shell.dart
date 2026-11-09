import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../responsive/window_size_class.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';
import '../../modules/auth/application/auth_controller.dart';
import 'app_dialog_actions.dart';
import 'app_logo.dart';

/// Item de navegación inferior del shell.
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.location,
    this.branchIndex,
    this.showInSidebar = true,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String location;
  final int? branchIndex;
  final bool showInSidebar;
}

class ShellAction {
  const ShellAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.isHeader = false,
  });

  const ShellAction.header(this.label)
    : icon = Icons.circle,
      onTap = _noop,
      selected = false,
      isHeader = true;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool isHeader;
}

void _noop() {}

/// Web keeps the established sidebar at every window width.
final sidebarAlwaysVisibleProvider = Provider<bool>((ref) => kIsWeb);

class AppShellLayout extends InheritedWidget {
  const AppShellLayout({
    super.key,
    required this.usesSidebar,
    required super.child,
  });

  final bool usesSidebar;

  static AppShellLayout? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellLayout>();
  }

  @override
  bool updateShouldNotify(AppShellLayout oldWidget) {
    return usesSidebar != oldWidget.usesSidebar;
  }
}

/// Scaffold reutilizable con navegación adaptativa para los flujos con pestañas.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
    this.actions = const [],
    this.selectedDestinationIndex,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;
  final List<ShellAction> actions;
  final int? selectedDestinationIndex;

  void _onBottomTap(int index) {
    final branchIndex = _branchIndexForDestination(index);
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  void _onSidebarTap(int index) {
    final branchIndex = _branchIndexForDestination(index);
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alwaysShowSidebar = ref.watch(sidebarAlwaysVisibleProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);

        if (!alwaysShowSidebar && sizeClass == WindowSizeClass.compact) {
          return Scaffold(
            body: AppShellLayout(usesSidebar: false, child: navigationShell),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _bottomSelectedIndex,
              onDestinationSelected: _onBottomTap,
              destinations: _bottomDestinations,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: AppDimensions.navigationSidebarWidth,
                child: _ExpandedSidebar(
                  selectedIndex:
                      selectedDestinationIndex ?? _selectedDestinationIndex,
                  destinations: destinations,
                  actions: actions,
                  onDestinationSelected: _onSidebarTap,
                  onLogout: () => _confirmLogout(context, ref),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bodyConstraints) {
                    final body = AppShellLayout(
                      usesSidebar: true,
                      child: navigationShell,
                    );
                    if (!alwaysShowSidebar) return body;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: bodyConstraints.maxWidth.clamp(
                          AppDimensions.compactBreakpoint,
                          double.infinity,
                        ),
                        height: bodyConstraints.maxHeight,
                        child: body,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int get _bottomSelectedIndex {
    return _selectedDestinationIndex;
  }

  int get _selectedDestinationIndex {
    final index = destinations.indexWhere(
      (destination) =>
          (destination.branchIndex ?? destinations.indexOf(destination)) ==
          navigationShell.currentIndex,
    );
    return index < 0 ? 0 : index;
  }

  int _branchIndexForDestination(int index) {
    if (index < 0 || index >= destinations.length) return index;
    return destinations[index].branchIndex ?? index;
  }

  List<NavigationDestination> get _bottomDestinations => [
    for (final destination in destinations)
      NavigationDestination(
        icon: Icon(destination.icon),
        selectedIcon: Icon(destination.selectedIcon),
        label: destination.label,
      ),
  ];
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Quieres salir de tu cuenta?'),
      actions: [
        SizedBox(
          width: 420,
          child: AppDialogActions(
            cancelLabel: 'Cancelar',
            confirmLabel: 'Salir',
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
            confirmIcon: Icons.logout_rounded,
          ),
        ),
      ],
    ),
  );
  if (shouldLogout == true && context.mounted) {
    await ref.read(authControllerProvider.notifier).logout();
  }
}

class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.actions,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int? selectedIndex;
  final List<ShellDestination> destinations;
  final List<ShellAction> actions;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppLogo(
                height: 40,
                onDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      if (destinations[index].showInSidebar) ...[
                        _SidebarItem(
                          icon: selectedIndex == index
                              ? destinations[index].selectedIcon
                              : destinations[index].icon,
                          label: destinations[index].label,
                          selected: selectedIndex == index,
                          onTap: () => onDestinationSelected(index),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Divider(color: scheme.outlineVariant),
                      const SizedBox(height: AppSpacing.sm),
                      for (final action in actions) ...[
                        if (action.isHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.xs,
                            ),
                            child: Text(
                              action.label,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          )
                        else
                          _SidebarItem(
                            icon: action.icon,
                            label: action.label,
                            selected: action.selected,
                            onTap: action.onTap,
                          ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.navyDark,
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.10),
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: _SidebarItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                color: AppColors.white,
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground =
        color ?? (selected ? scheme.onPrimaryContainer : scheme.onSurface);
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: AppDimensions.iconMedium),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
