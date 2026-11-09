import 'package:flutter/material.dart';
import '../../../modules/guidance/presentation/support_calls_screen.dart';
import '../../../modules/guidance/presentation/risk_policy_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/authorization/permission_codes.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/clinical_records/presentation/clinical_corrections_screen.dart';
import '../../../modules/deliveries/presentation/delivery_operations_screen.dart';
import '../../../modules/emergencies/presentation/emergency_operations_screen.dart';
import '../../../modules/incidents/presentation/incidents_screen.dart';
import '../../../modules/notifications/presentation/notifications_screen.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({this.initialTab = 0, this.initialTabCode, super.key});

  final int initialTab;
  final String? initialTabCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final roles = user?.roles ?? const <String>{};
    final permissions = user?.permissions ?? const <String>{};
    final tabs = _operationTabs(roles, permissions);

    if (tabs.isEmpty) {
      return const Scaffold(
        body: AppErrorState(
          message: 'Tu cuenta no tiene módulos operativos disponibles.',
        ),
      );
    }

    final selectedIndex = _selectedTabIndex(
      tabs,
      initialTabCode ??
          (roles.contains('delivery_assistant') ? 'deliveries' : 'emergencies'),
      initialTab,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final usesSidebar =
            AppShellLayout.maybeOf(context)?.usesSidebar ??
            constraints.maxWidth >= AppDimensions.compactBreakpoint;

        if (usesSidebar) {
          return Scaffold(
            appBar: AppBar(title: Text(tabs[selectedIndex].title)),
            body: tabs[selectedIndex].child,
          );
        }

        if (tabs.length <= 1) {
          return Scaffold(
            appBar: AppBar(title: Text(tabs.first.title)),
            body: tabs.first.child,
          );
        }

        return DefaultTabController(
          length: tabs.length,
          initialIndex: selectedIndex,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Operaciones'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final tab in tabs)
                    Tab(icon: Icon(tab.icon), text: tab.title),
                ],
              ),
            ),
            body: TabBarView(children: [for (final tab in tabs) tab.child]),
          ),
        );
      },
    );
  }

  static List<_OperationTab> _operationTabs(
    Set<String> roles,
    Set<String> permissions,
  ) {
    final isDeliveryAssistant = roles.contains('delivery_assistant');
    final isSupervisor = roles.contains('clinical_supervisor');
    final canReadEmergencies = permissions.contains(
      PermissionCodes.emergenciesRead,
    );
    final canReadDeliveries = permissions.contains(
      PermissionCodes.deliveriesRead,
    );
    final canReadIncidents = permissions.contains(
      PermissionCodes.incidentsRead,
    );
    final canReadNotifications = permissions.contains(
      PermissionCodes.notificationsRead,
    );
    final canResolveCorrections = permissions.contains(
      PermissionCodes.clinicalRecordsManage,
    );

    if (isDeliveryAssistant) {
      return const [
        _OperationTab(
          code: 'deliveries',
          title: 'Entregas',
          icon: Icons.local_shipping_outlined,
          child: DeliveryOperationsScreen(),
        ),
        _OperationTab(
          code: 'incidents',
          title: 'Incidentes',
          icon: Icons.support_agent_outlined,
          child: IncidentsScreen(embedded: true),
        ),
      ];
    }

    return [
      if (canReadEmergencies)
        const _OperationTab(
          code: 'support_calls',
          title: 'Orientación',
          icon: Icons.support_agent,
          child: SupportCallsScreen(),
        ),
      if (permissions.contains(PermissionCodes.aiManage))
        const _OperationTab(
          code: 'risk_policy',
          title: 'Reglas clínicas',
          icon: Icons.rule,
          child: RiskPolicyScreen(),
        ),
      if (canReadEmergencies)
        const _OperationTab(
          code: 'emergencies',
          title: 'Emergencias',
          icon: Icons.emergency_outlined,
          child: EmergencyOperationsScreen(),
        ),
      if (canReadIncidents)
        const _OperationTab(
          code: 'incidents',
          title: 'Incidentes',
          icon: Icons.support_agent_outlined,
          child: IncidentsScreen(embedded: true),
        ),
      if (canReadNotifications)
        const _OperationTab(
          code: 'alerts',
          title: 'Alertas',
          icon: Icons.notifications_active_outlined,
          child: NotificationsScreen(embedded: true),
        ),
      if (isSupervisor && canResolveCorrections)
        const _OperationTab(
          code: 'corrections',
          title: 'Correcciones',
          icon: Icons.fact_check_outlined,
          child: ClinicalCorrectionsScreen(embedded: true),
        ),
      if (canReadDeliveries)
        const _OperationTab(
          code: 'deliveries',
          title: 'Entregas',
          icon: Icons.local_shipping_outlined,
          child: DeliveryOperationsScreen(),
        ),
    ];
  }
}

int _selectedTabIndex(
  List<_OperationTab> tabs,
  String? code,
  int fallbackIndex,
) {
  final index = tabs.indexWhere((tab) => tab.code == code);
  if (index >= 0) return index;
  return fallbackIndex.clamp(0, tabs.isEmpty ? 0 : tabs.length - 1).toInt();
}

class _OperationTab {
  const _OperationTab({
    required this.code,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String code;
  final String title;
  final IconData icon;
  final Widget child;
}
