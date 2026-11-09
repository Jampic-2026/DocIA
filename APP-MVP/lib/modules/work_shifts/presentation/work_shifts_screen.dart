import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/authorization/permission_codes.dart';
import '../../auth/application/auth_controller.dart';
import '../../human_resources/application/human_resources_controller.dart';
import '../application/work_shifts_controller.dart';
import '../domain/work_shifts_repository.dart';
import 'work_shift_form.dart';

class WorkShiftsScreen extends ConsumerStatefulWidget {
  const WorkShiftsScreen({super.key});
  @override
  ConsumerState<WorkShiftsScreen> createState() => _WorkShiftsScreenState();
}

class _WorkShiftsScreenState extends ConsumerState<WorkShiftsScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool currentOnly = false;
  String? role, location, specialtyId, serviceType;
  bool availableOnly = false;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final manager = user?.can(PermissionCodes.humanResourcesManage) ?? false;
    final staffReader = user?.can(PermissionCodes.humanResourcesRead) ?? false;
    return DefaultTabController(
      length: staffReader ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Turnos y disponibilidad'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Turnos'),
              if (staffReader) const Tab(text: 'Personal'),
            ],
          ),
          actions: [
            if (manager)
              IconButton(
                tooltip: 'Asignar turno',
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Mes anterior',
                      onPressed: () => setState(
                        () => month = DateTime(month.year, month.month - 1),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(DateFormat('MMMM yyyy', 'es').format(month)),
                    IconButton(
                      tooltip: 'Mes siguiente',
                      onPressed: () => setState(
                        () => month = DateTime(month.year, month.month + 1),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: () =>
                          ref.invalidate(workShiftsProvider(month)),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Mostrar solo turnos vigentes'),
                  value: currentOnly,
                  onChanged: (value) => setState(() {
                    currentOnly = value;
                    if (value) {
                      month = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                      );
                    }
                  }),
                ),
                Expanded(
                  child: ref
                      .watch(workShiftsProvider(month))
                      .when(
                        loading: () => const AppLoadingState(
                          message: 'Consultando turnos',
                        ),
                        error: (error, _) => AppErrorState(
                          message: error.toString(),
                          onRetry: () =>
                              ref.invalidate(workShiftsProvider(month)),
                        ),
                        data: (items) {
                          final filtered = items
                              .where((item) => !currentOnly || item.isCurrent)
                              .toList();
                          return ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              if (filtered.isEmpty)
                                const Text(
                                  'No hay turnos para este período y filtro.',
                                ),
                              for (final item in filtered)
                                AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.professionalName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        '${DateFormat('dd/MM HH:mm').format(item.startAt)} — ${DateFormat('dd/MM HH:mm').format(item.endAt)}',
                                      ),
                                      Text(
                                        '${item.location} · ${item.area ?? 'Área no registrada'}',
                                      ),
                                      Text('Estado: ${item.status}'),
                                      if (item.notes != null) Text(item.notes!),
                                      if (manager &&
                                          item.startAt.isAfter(DateTime.now()))
                                        TextButton.icon(
                                          onPressed: () => _edit(item),
                                          icon: const Icon(Icons.edit),
                                          label: const Text(
                                            'Modificar o cancelar',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              if (items.length == 200)
                                const Text(
                                  'Se muestran los primeros 200 turnos del período.',
                                ),
                            ],
                          );
                        },
                      ),
                ),
              ],
            ),
            if (staffReader) _staff(),
          ],
        ),
      ),
    );
  }

  Widget _staff() {
    final filter = (
      role: role,
      location: location,
      specialtyId: specialtyId,
      availableOnly: availableOnly,
      serviceType: serviceType,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DropdownButtonFormField<String>(
          initialValue: role,
          decoration: const InputDecoration(labelText: 'Rol'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Todos')),
            DropdownMenuItem(value: 'nurse', child: Text('Enfermería')),
            DropdownMenuItem(value: 'doctor', child: Text('Medicina')),
            DropdownMenuItem(value: 'operator', child: Text('Operación')),
          ],
          onChanged: (value) => setState(() => role = value),
        ),
        AppTextField(
          label: 'Sede',
          onChanged: (value) => setState(
            () => location = value.trim().isEmpty ? null : value.trim(),
          ),
        ),
        ref
            .watch(verificationSpecialtiesProvider)
            .when(
              data: (items) => DropdownButtonFormField<String>(
                initialValue: specialtyId,
                decoration: const InputDecoration(labelText: 'Especialidad'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final item in items)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => setState(() => specialtyId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
            ),
        DropdownButtonFormField<String>(
          initialValue: serviceType,
          decoration: const InputDecoration(labelText: 'Tipo de servicio'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Todos')),
            DropdownMenuItem(
              value: 'telemedicine',
              child: Text('Telemedicina'),
            ),
            DropdownMenuItem(value: 'in_person', child: Text('Presencial')),
            DropdownMenuItem(value: 'home_visit', child: Text('Domicilio')),
          ],
          onChanged: (value) => setState(() => serviceType = value),
        ),
        SwitchListTile(
          title: const Text('Solo disponibilidad actual'),
          value: availableOnly,
          onChanged: (value) => setState(() => availableOnly = value),
        ),
        ref
            .watch(availableStaffProvider(filter))
            .when(
              loading: () =>
                  const AppLoadingState(message: 'Consultando disponibilidad'),
              error: (error, _) => AppErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(availableStaffProvider(filter)),
              ),
              data: (items) => Column(
                children: [
                  if (items.isEmpty)
                    const Text('No hay personal para estos filtros.'),
                  for (final item in items)
                    ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.role} · ${item.specialty ?? 'Especialidad no registrada'}\n${item.location ?? 'Sede no registrada'} · ${item.availableNow ? 'Disponible ahora' : 'Sin disponibilidad actual'}',
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _edit([WorkShift? shift]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(builder: (_) => WorkShiftForm(shift: shift)),
    );
    if (mounted) {
      ref.invalidate(workShiftsProvider);
      ref.invalidate(availableStaffProvider);
    }
  }
}
