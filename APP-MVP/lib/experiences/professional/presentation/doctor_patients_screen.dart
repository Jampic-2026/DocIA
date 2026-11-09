import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/professional_patients/application/professional_patients_controller.dart';
import '../../../modules/professional_patients/domain/professional_patient.dart';

class DoctorPatientsScreen extends ConsumerStatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  ConsumerState<DoctorPatientsScreen> createState() =>
      _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends ConsumerState<DoctorPatientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(professionalPatientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pacientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: AppTextField(
                  hint: 'Buscar paciente',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
          ),
          Expanded(
            child: patients.when(
              loading: () =>
                  const AppLoadingState(message: 'Cargando pacientes'),
              error: (error, _) => AppErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(professionalPatientsProvider),
              ),
              data: (items) {
                final query = _query.trim().toLowerCase();
                final filtered = items
                    .where((patient) =>
                        patient.fullName.toLowerCase().contains(query))
                    .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_search_rounded,
                    title: query.isEmpty ? 'Sin pacientes' : 'Sin resultados',
                    message: query.isEmpty
                        ? 'Los pacientes atendidos aparecerán aquí.'
                        : 'No se encontraron coincidencias.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(professionalPatientsProvider.future),
                  child: AdaptivePage(
                    maxWidth: 980,
                    children: [
                      for (final patient in filtered)
                        _PatientCard(patient: patient),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final ProfessionalPatient patient;

  @override
  Widget build(BuildContext context) {
    final assessment = patient.latestAssessment?.trim();
    final visit = patient.lastVisitAt == null
        ? 'Sin consulta completada'
        : 'Última visita: ${DateFormat('dd/MM/yyyy').format(patient.lastVisitAt!.toLocal())}';
    return AppCard(
      onTap: () => context.pushNamed(
        AppRoutes.professionalPatientRecord,
        queryParameters: {
          'patientId': patient.id,
          if (patient.appointmentId != null)
            'appointmentId': patient.appointmentId!,
        },
      ),
      child: Row(
        children: [
          UserAvatar(name: patient.fullName),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (patient.age != null) '${patient.age} años',
                    assessment?.isNotEmpty == true
                        ? assessment!
                        : 'Sin evaluación registrada',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  visit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
