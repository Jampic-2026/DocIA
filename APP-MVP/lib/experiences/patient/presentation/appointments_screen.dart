import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import 'widgets/appointment_card.dart';

/// Pantalla de citas del paciente con pestañas Próximas / Historial.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis citas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Próximas'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.pushNamed(AppRoutes.doctorDirectory),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agendar'),
        ),
        body: appointments.when(
          loading: () => const AppLoadingState(message: 'Cargando tus citas'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () =>
                ref.read(appointmentsControllerProvider.notifier).refresh(),
          ),
          data: (items) {
            final now = DateTime.now();
            final upcoming = items
                .where(
                  (appointment) =>
                      appointment.endAt.isAfter(now) &&
                      !const {
                        AppointmentStatus.cancelled,
                        AppointmentStatus.completed,
                        AppointmentStatus.noShow,
                      }.contains(appointment.status),
                )
                .toList()
                  ..sort((a, b) => a.startAt.compareTo(b.startAt));
            final upcomingIds = upcoming.map((item) => item.id).toSet();
            final past = items
                .where((appointment) => !upcomingIds.contains(appointment.id))
                .toList()
                  ..sort((a, b) => b.startAt.compareTo(a.startAt));

            return TabBarView(
              children: [
                _AppointmentList(
                  items: upcoming,
                  emptyLabel: 'No tienes citas próximas',
                ),
                _AppointmentList(
                  items: past,
                  emptyLabel: 'Sin citas anteriores',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}

class _AppointmentList extends StatefulWidget {
  const _AppointmentList({required this.items, required this.emptyLabel});
  final List<Appointment> items;
  final String emptyLabel;

  @override
  State<_AppointmentList> createState() => _AppointmentListState();
}

class _AppointmentListState extends State<_AppointmentList> {
  String? _expandedAppointmentId;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_today_rounded,
        title: widget.emptyLabel,
        message: 'Agenda una consulta con nuestros profesionales.',
      );
    }
    return AdaptivePage(
      maxWidth: 980,
      children: [
        for (final appointment in widget.items)
          AppointmentCard(
          appointment: appointment,
          expanded: _expandedAppointmentId == appointment.id,
          onTap: () => setState(() {
            _expandedAppointmentId = _expandedAppointmentId == appointment.id
                ? null
                : appointment.id;
          }),
          onOpenDetails: () => context.pushNamed(
            AppRoutes.appointmentDetail,
            queryParameters: {'id': appointment.id},
          ),
        ),
      ],
    );
  }
}
