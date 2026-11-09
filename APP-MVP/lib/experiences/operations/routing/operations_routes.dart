import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/authorization/permission_codes.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../modules/account/presentation/account_screen.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/benefits/presentation/benefits_screen.dart';
import '../../../modules/catalog/presentation/catalog_screen.dart';
import '../../../modules/coins/presentation/coins_screen.dart';
import '../../../modules/consents/presentation/consents_screen.dart';
import '../../../modules/help/presentation/help_screen.dart';
import '../../../modules/incidents/presentation/incidents_screen.dart';
import '../../../modules/payments/presentation/payments_screen.dart';
import '../presentation/operations_screen.dart';

RouteBase operationsRoutes() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(authControllerProvider).user;
        final roles = user?.roles ?? const <String>{};
        final permissions = user?.permissions ?? const <String>{};
        final isDeliveryAssistant = roles.contains('delivery_assistant');
        final defaultTab = isDeliveryAssistant ? 'deliveries' : 'emergencies';
        final tab = state.uri.queryParameters['tab'] ?? defaultTab;
        final inOperations = state.uri.path == AppRoutes.operationsHome;

        return AppShell(
          navigationShell: shell,
          selectedDestinationIndex: inOperations ? -1 : null,
          destinations: const [
            ShellDestination(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
              label: 'Operaciones',
              location: AppRoutes.operationsHome,
              branchIndex: 0,
              showInSidebar: false,
            ),
            ShellDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Cuenta',
              location: AppRoutes.operationsProfile,
              branchIndex: 1,
            ),
          ],
          actions: _operationActions(
            roles: roles,
            permissions: permissions,
            selectedTab: inOperations ? tab : null,
            open: (selectedTab) =>
                context.go('${AppRoutes.operationsHome}?tab=$selectedTab'),
          ),
        );
      },
    ),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.operationsHome,
            builder: (_, state) => OperationsScreen(
              key: ValueKey(state.uri.queryParameters['tab'] ?? 'default'),
              initialTabCode: state.uri.queryParameters['tab'],
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.operationsProfile,
            builder: (_, __) => const AccountScreen(),
            routes: [
              GoRoute(path: 'help', builder: (_, __) => const HelpScreen()),
              GoRoute(
                path: 'consents',
                builder: (_, __) => const ConsentsScreen(),
              ),
              GoRoute(
                path: 'incidents',
                builder: (_, __) => const IncidentsScreen(),
              ),
              GoRoute(
                path: 'catalog',
                builder: (_, __) => const CatalogScreen(),
              ),
              GoRoute(path: 'coins', builder: (_, __) => const CoinsScreen()),
              GoRoute(
                path: 'benefits',
                builder: (_, __) => const BenefitsScreen(),
              ),
              GoRoute(
                path: 'payments',
                builder: (_, __) => const PaymentsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

List<ShellAction> _operationActions({
  required Set<String> roles,
  required Set<String> permissions,
  required String? selectedTab,
  required ValueChanged<String> open,
}) {
  final isDeliveryAssistant = roles.contains('delivery_assistant');
  final isSupervisor = roles.contains('clinical_supervisor');
  final canReadEmergencies = permissions.contains(
    PermissionCodes.emergenciesRead,
  );
  final canReadDeliveries = permissions.contains(
    PermissionCodes.deliveriesRead,
  );
  final canReadIncidents = permissions.contains(PermissionCodes.incidentsRead);
  final canReadNotifications = permissions.contains(
    PermissionCodes.notificationsRead,
  );
  final canResolveCorrections = permissions.contains(
    PermissionCodes.clinicalRecordsManage,
  );

  if (isDeliveryAssistant) {
    return [
      ShellAction(
        icon: Icons.local_shipping_outlined,
        label: 'Entregas',
        selected: selectedTab == 'deliveries',
        onTap: () => open('deliveries'),
      ),
      ShellAction(
        icon: Icons.support_agent_outlined,
        label: 'Incidentes',
        selected: selectedTab == 'incidents',
        onTap: () => open('incidents'),
      ),
    ];
  }

  return [
    if (canReadEmergencies)
      ShellAction(
        icon: Icons.support_agent_outlined,
        label: 'Orientación',
        selected: selectedTab == 'support_calls',
        onTap: () => open('support_calls'),
      ),
    if (permissions.contains(PermissionCodes.aiManage))
      ShellAction(
        icon: Icons.rule_outlined,
        label: 'Reglas clínicas',
        selected: selectedTab == 'risk_policy',
        onTap: () => open('risk_policy'),
      ),
    if (canReadEmergencies)
      ShellAction(
        icon: Icons.emergency_outlined,
        label: 'Emergencias',
        selected: selectedTab == 'emergencies',
        onTap: () => open('emergencies'),
      ),
    if (canReadIncidents)
      ShellAction(
        icon: Icons.support_agent_outlined,
        label: 'Incidentes',
        selected: selectedTab == 'incidents',
        onTap: () => open('incidents'),
      ),
    if (canReadNotifications)
      ShellAction(
        icon: Icons.notifications_active_outlined,
        label: 'Alertas',
        selected: selectedTab == 'alerts',
        onTap: () => open('alerts'),
      ),
    if (isSupervisor && canResolveCorrections)
      ShellAction(
        icon: Icons.fact_check_outlined,
        label: 'Correcciones',
        selected: selectedTab == 'corrections',
        onTap: () => open('corrections'),
      ),
    if (canReadDeliveries)
      ShellAction(
        icon: Icons.local_shipping_outlined,
        label: 'Entregas',
        selected: selectedTab == 'deliveries',
        onTap: () => open('deliveries'),
      ),
  ];
}
