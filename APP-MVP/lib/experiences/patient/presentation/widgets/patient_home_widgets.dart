import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../modules/appointments/domain/appointment.dart';
import '../../../../modules/appointments/presentation/appointment_presentation.dart';
import '../../../../modules/clinical_records/domain/clinical_profile.dart';

enum PatientHomeMenuOption {
  clinicalProfile,
  family,
  prescriptions,
}

class PatientMoreOptionsButton extends StatefulWidget {
  const PatientMoreOptionsButton({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<PatientHomeMenuOption> onSelected;

  @override
  State<PatientMoreOptionsButton> createState() =>
      _PatientMoreOptionsButtonState();
}

class _PatientMoreOptionsButtonState extends State<PatientMoreOptionsButton>
    with SingleTickerProviderStateMixin {
  final _layerLink = LayerLink();
  OverlayEntry? _entry;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      reverseDuration: const Duration(milliseconds: 120),
    );
    final curve = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = curve;
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1).animate(curve);
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_entry == null) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
    _animationController.forward(from: 0);
  }

  Future<void> _close() async {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    await _animationController.reverse();
    entry.remove();
  }

  Future<void> _select(PatientHomeMenuOption option) async {
    await _close();
    if (mounted) widget.onSelected(option);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final media = MediaQuery.of(overlayContext);
    final width = (media.size.width - 32).clamp(240.0, 284.0).toDouble();
    final maxHeight = (media.size.height - media.padding.top - 112)
        .clamp(180.0, 340.0)
        .toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: ColoredBox(
              color: AppColors.black.withValues(alpha: 0.04),
            ),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 10),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.topRight,
              child: PatientMoreOptionsPopover(
                width: width,
                maxHeight: maxHeight,
                onSelected: _select,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: 'Más opciones',
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggle,
            child: const _CircularHeaderIcon(
              icon: Icons.more_horiz_rounded,
            ),
          ),
        ),
      ),
    );
  }
}

class PatientMoreOptionsPopover extends StatelessWidget {
  const PatientMoreOptionsPopover({
    super.key,
    required this.width,
    required this.maxHeight,
    required this.onSelected,
  });

  final double width;
  final double maxHeight;
  final ValueChanged<PatientHomeMenuOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.transparent,
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -6,
              right: 17,
              child: Transform.rotate(
                angle: 0.785398,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.black15,
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        'Más opciones',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PatientMoreOptionItem(
                      icon: Icons.folder_shared_rounded,
                      label: 'Perfil clínico',
                      onTap: () =>
                          onSelected(PatientHomeMenuOption.clinicalProfile),
                    ),
                    PatientMoreOptionItem(
                      icon: Icons.groups_rounded,
                      label: 'Familiares',
                      onTap: () =>
                          onSelected(PatientHomeMenuOption.family),
                    ),
                    PatientMoreOptionItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Recetas',
                      onTap: () =>
                          onSelected(PatientHomeMenuOption.prescriptions),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientMoreOptionItem extends StatelessWidget {
  const PatientMoreOptionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppColors.blue, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PatientHomeHeader extends StatelessWidget {
  const PatientHomeHeader({
    super.key,
    required this.greeting,
    required this.patientName,
    required this.unreadNotifications,
    required this.profile,
    required this.onNotificationsTap,
    required this.onMenuSelected,
    this.showMoreOptions = true,
  });

  final String greeting;
  final String patientName;
  final int unreadNotifications;
  final ClinicalProfile? profile;
  final VoidCallback onNotificationsTap;
  final ValueChanged<PatientHomeMenuOption> onMenuSelected;
  final bool showMoreOptions;

  @override
  Widget build(BuildContext context) {
    return GradientHeader(
      subtitle: greeting,
      title: patientName,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderActionButton(
            tooltip: 'Notificaciones',
            icon: Icons.notifications_none_rounded,
            badgeCount: unreadNotifications,
            onTap: onNotificationsTap,
          ),
          if (showMoreOptions) ...[
            const SizedBox(width: AppSpacing.sm),
            PatientMoreOptionsButton(
              onSelected: onMenuSelected,
            ),
          ],
        ],
      ),
      child: _hasMetrics ? PatientQuickMetrics(profile: profile) : null,
    );
  }

  bool get _hasMetrics {
    final bloodType = profile?.bloodType?.trim();
    return (bloodType != null && bloodType.isNotEmpty) ||
        profile?.weightKg != null ||
        (profile?.heightCm != null && profile?.weightKg != null);
  }
}

class PatientQuickMetrics extends StatelessWidget {
  const PatientQuickMetrics({super.key, required this.profile});

  final ClinicalProfile? profile;

  @override
  Widget build(BuildContext context) {
    final bloodType = _normalized(profile?.bloodType);
    final weight = profile?.weightKg;
    final bmi = _bmi(profile);
    if (bloodType == null && weight == null && bmi == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white18,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _Metric(
            value: bloodType ?? 'Sin registrar',
            label: 'Tipo de sangre',
          ),
          const _MetricDivider(),
          _Metric(
            value: weight == null
                ? 'Sin registrar'
                : '${weight.toStringAsFixed(0)} kg',
            label: 'Peso',
          ),
          const _MetricDivider(),
          _Metric(value: bmi ?? 'Sin registrar', label: 'IMC'),
        ],
      ),
    );
  }

  String? _normalized(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _bmi(ClinicalProfile? profile) {
    final height = profile?.heightCm;
    final weight = profile?.weightKg;
    if (height == null || height <= 0 || weight == null || weight <= 0) {
      return null;
    }
    final meters = height / 100;
    return (weight / (meters * meters)).toStringAsFixed(1);
  }
}

class PrimaryPatientActionCard extends StatelessWidget {
  const PrimaryPatientActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.foregroundColor = AppColors.white,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $description',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: foregroundColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: foregroundColor, size: 27),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foregroundColor.withValues(alpha: 0.82),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: foregroundColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PatientNextAppointmentSection extends StatelessWidget {
  const PatientNextAppointmentSection({
    super.key,
    required this.appointment,
    required this.onViewAppointment,
    required this.onScheduleAppointment,
  });

  final Appointment? appointment;
  final VoidCallback? onViewAppointment;
  final VoidCallback onScheduleAppointment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Próxima cita',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        if (appointment != null)
          PatientNextAppointmentCard(
            appointment: appointment!,
            onTap: onViewAppointment!,
          )
        else
          PatientNoUpcomingAppointment(onSchedule: onScheduleAppointment),
      ],
    );
  }
}

class PatientNextAppointmentCard extends StatelessWidget {
  const PatientNextAppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateAndTime(appointment.startAt),
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      appointment.professionalName,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${appointment.specialty} · ${appointment.modality.label}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        StatusPill(
                          label: appointment.status.label,
                          color: appointment.status.color,
                          dense: true,
                        ),
                        const Spacer(),
                        Text(
                          'Ver cita',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateAndTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDay = DateTime(date.year, date.month, date.day);
    final dayLabel = appointmentDay == today
        ? 'Hoy'
        : DateFormat("EEE d 'de' MMM", 'es').format(date);
    return '$dayLabel · ${DateFormat('HH:mm').format(date)}';
  }
}

class PatientNoUpcomingAppointment extends StatelessWidget {
  const PatientNoUpcomingAppointment({super.key, required this.onSchedule});

  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'No tienes consultas próximas.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onSchedule,
            child: const Text('Agendar consulta'),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.badgeCount,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _CircularHeaderIcon(icon: icon),
              if (badgeCount > 0)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
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

class _CircularHeaderIcon extends StatelessWidget {
  const _CircularHeaderIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.white12,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.white, size: 24),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppColors.white25);
  }
}
