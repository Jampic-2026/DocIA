import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../modules/appointments/domain/appointment.dart';
import '../../../../modules/appointments/presentation/appointment_presentation.dart';

/// Tarjeta que representa una cita médica.
///
/// [showPatient] muestra el nombre del paciente (vista médico) en lugar del
/// profesional (vista paciente).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.showPatient = false,
    this.expanded = false,
    this.onTap,
    this.onOpenDetails,
    this.trailing,
  });

  final Appointment appointment;
  final bool showPatient;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onOpenDetails;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTele = appointment.modality == AppointmentModality.telemedicine;
    final title =
        showPatient ? appointment.patientName : appointment.professionalName;
    final subtitle =
        showPatient ? (appointment.reason ?? '') : appointment.specialty;

    return AppCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                name: title,
                gradient: isTele
                    ? AppColors.tealGradient
                    : AppColors.brandGradient,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: appointment.status.label,
                color: appointment.status.color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _MetaChip(
                icon: Icons.event_rounded,
                label: DateFormat('d MMM', 'es')
                    .format(appointment.startAt),
              ),
              const SizedBox(width: AppSpacing.sm),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: DateFormat('HH:mm').format(appointment.startAt),
              ),
              const SizedBox(width: AppSpacing.sm),
              _MetaChip(
                icon: appointment.modality.icon,
                label: appointment.modality.label,
                color: isTele ? AppColors.teal : null,
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: showPatient
                  ? Icons.person_outline_rounded
                  : Icons.medical_information_outlined,
              label: showPatient ? 'Paciente' : 'Profesional',
              value: title,
            ),
            _DetailRow(
              icon: Icons.local_hospital_outlined,
              label: 'Especialidad',
              value: appointment.specialty,
            ),
            _DetailRow(
              icon: Icons.event_rounded,
              label: 'Fecha',
              value: DateFormat('EEEE d MMMM y', 'es').format(
                appointment.startAt,
              ),
            ),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Horario',
              value:
                  '${DateFormat('HH:mm').format(appointment.startAt)} - '
                  '${DateFormat('HH:mm').format(appointment.endAt)}',
            ),
            _DetailRow(
              icon: appointment.modality.icon,
              label: 'Modalidad',
              value: appointment.modality.label,
            ),
            _DetailRow(
              icon: Icons.flag_outlined,
              label: 'Estado',
              value: appointment.status.label,
            ),
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Motivo',
              value: appointment.reason?.trim().isNotEmpty == true
                  ? appointment.reason!
                  : 'No registrado',
            ),
            if (onOpenDetails != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ver detalle de la cita'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
