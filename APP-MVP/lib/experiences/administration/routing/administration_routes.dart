import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../modules/account/presentation/account_screen.dart';
import '../../../modules/benefits/presentation/benefits_screen.dart';
import '../../../modules/catalog/presentation/catalog_screen.dart';
import '../../../modules/coins/presentation/coins_screen.dart';
import '../../../modules/consents/presentation/consents_screen.dart';
import '../../../modules/help/presentation/help_screen.dart';
import '../../../modules/incidents/presentation/incidents_screen.dart';
import '../../../modules/payments/presentation/payments_screen.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../core/authorization/permission_codes.dart';
import '../presentation/admin_dashboard_screen.dart';
import '../presentation/admin_management_screen.dart';

RouteBase administrationRoutes() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(authControllerProvider).user;
        final isAdmin = user?.hasRole('admin') ?? false;
        final tab = state.uri.queryParameters['tab'] ?? 'professionals';
        final inManagement = state.uri.path == AppRoutes.adminManagement;
        return AppShell(
          navigationShell: shell,
          destinations: [
            if (isAdmin)
              const ShellDestination(
                icon: Icons.insights_outlined,
                selectedIcon: Icons.insights_rounded,
                label: 'Panel',
                location: AppRoutes.adminHome,
                branchIndex: 0,
              ),
            const ShellDestination(
              icon: Icons.tune_outlined,
              selectedIcon: Icons.tune_rounded,
              label: 'Gestión',
              location: AppRoutes.adminManagement,
              branchIndex: 1,
              showInSidebar: false,
            ),
            const ShellDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Cuenta',
              location: AppRoutes.adminProfile,
              branchIndex: 2,
            ),
          ],
          actions: _adminManagementActions(
            can: (permission) => user?.can(permission) ?? false,
            selectedTab: inManagement ? tab : null,
            open: (tab) => context.go('${AppRoutes.adminManagement}?tab=$tab'),
          ),
        );
      },
    ),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.adminHome,
            builder: (_, __) => Consumer(
              builder: (context, ref, _) {
                final user = ref.watch(authControllerProvider).user;
                if (user?.hasRole('admin') ?? false) {
                  return const AdminDashboardScreen();
                }
                return const AdminManagementScreen(
                  initialTabCode: 'professionals',
                );
              },
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.adminManagement,
            builder: (_, state) => AdminManagementScreen(
              key: ValueKey(
                state.uri.queryParameters['tab'] ?? 'professionals',
              ),
              initialTabCode:
                  state.uri.queryParameters['tab'] ?? 'professionals',
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.adminProfile,
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

List<ShellAction> _adminManagementActions({
  required bool Function(String) can,
  required String? selectedTab,
  required ValueChanged<String> open,
}) {
  return [
    if (can(PermissionCodes.humanResourcesManage))
      ShellAction(
        icon: Icons.checklist_outlined,
        label: 'Requisitos',
        selected: selectedTab == 'document_requirements',
        onTap: () => open('document_requirements'),
      ),
    if (can(PermissionCodes.humanResourcesRead))
      ShellAction(
        icon: Icons.schedule_outlined,
        label: 'Turnos',
        selected: selectedTab == 'work_shifts',
        onTap: () => open('work_shifts'),
      ),
    if (can(PermissionCodes.administrationManage))
      ShellAction(
        icon: Icons.fact_check_outlined,
        label: 'Completitud',
        selected: selectedTab == 'profile_completion',
        onTap: () => open('profile_completion'),
      ),
    if (can(PermissionCodes.emergenciesManage))
      ShellAction(
        icon: Icons.support_agent_outlined,
        label: 'Orientación',
        selected: selectedTab == 'support_calls',
        onTap: () => open('support_calls'),
      ),
    if (can(PermissionCodes.aiManage))
      ShellAction(
        icon: Icons.rule_outlined,
        label: 'Reglas clínicas',
        selected: selectedTab == 'risk_policy',
        onTap: () => open('risk_policy'),
      ),
    if (can(PermissionCodes.professionalsRead))
      ShellAction(
        icon: Icons.badge_outlined,
        label: 'Profesionales',
        selected: selectedTab == 'professionals',
        onTap: () => open('professionals'),
      ),
    if (can(PermissionCodes.humanResourcesRead))
      ShellAction(
        icon: Icons.assignment_ind_outlined,
        label: 'Postulaciones',
        selected: selectedTab == 'applications',
        onTap: () => open('applications'),
      ),
    if (can(PermissionCodes.partnersRead))
      ShellAction(
        icon: Icons.business_outlined,
        label: 'Empresas',
        selected: selectedTab == 'companies',
        onTap: () => open('companies'),
      ),
    if (can(PermissionCodes.auditRead))
      ShellAction(
        icon: Icons.fact_check_outlined,
        label: 'Auditoría',
        selected: selectedTab == 'audit',
        onTap: () => open('audit'),
      ),
    if (can(PermissionCodes.emergenciesRead))
      ShellAction(
        icon: Icons.emergency_outlined,
        label: 'Emergencias',
        selected: selectedTab == 'emergencies',
        onTap: () => open('emergencies'),
      ),
    if (can(PermissionCodes.clinicalRecordsManage))
      ShellAction(
        icon: Icons.rule_outlined,
        label: 'Correcciones',
        selected: selectedTab == 'corrections',
        onTap: () => open('corrections'),
      ),
    if (can(PermissionCodes.administrationManage))
      ShellAction(
        icon: Icons.sync_outlined,
        label: 'Integraciones',
        selected: selectedTab == 'integrations',
        onTap: () => open('integrations'),
      ),
    if (can(PermissionCodes.usersRead))
      ShellAction(
        icon: Icons.group_outlined,
        label: 'Usuarios',
        selected: selectedTab == 'users',
        onTap: () => open('users'),
      ),
    if (can(PermissionCodes.catalogManage))
      ShellAction(
        icon: Icons.medical_services_outlined,
        label: 'Servicios y tarifas',
        selected: selectedTab == 'catalog',
        onTap: () => open('catalog'),
      ),
    if (can(PermissionCodes.coinsManage))
      ShellAction(
        icon: Icons.toll_outlined,
        label: 'Paquetes y QR',
        selected: selectedTab == 'coins',
        onTap: () => open('coins'),
      ),
    if (can(PermissionCodes.paymentsManage))
      ShellAction(
        icon: Icons.payments_outlined,
        label: 'Pagos',
        selected: selectedTab == 'payments',
        onTap: () => open('payments'),
      ),
    if (can(PermissionCodes.administrationRead))
      ShellAction(
        icon: Icons.settings_outlined,
        label: 'Configuración',
        selected: selectedTab == 'settings',
        onTap: () => open('settings'),
      ),
  ];
}
