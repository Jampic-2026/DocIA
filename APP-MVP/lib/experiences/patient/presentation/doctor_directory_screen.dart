import 'package:flutter/material.dart';
import '../../../modules/guidance/application/guidance_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import '../../../modules/appointments/domain/appointments_repository.dart';
import '../../../modules/catalog/application/catalog_controller.dart';
import '../../../modules/catalog/domain/catalog_item.dart';
import '../../../modules/payments/application/payments_controller.dart';
import '../../../modules/family/domain/family_member.dart';
import '../../../modules/professionals/application/professionals_controller.dart';
import '../../../modules/professionals/domain/professional.dart';
import '../../../modules/family/application/family_controller.dart';

class DoctorDirectoryScreen extends ConsumerStatefulWidget {
  const DoctorDirectoryScreen({
    super.key,
    this.initialPatientId,
    this.assessmentId,
  });
  final String? initialPatientId;
  final String? assessmentId;

  @override
  ConsumerState<DoctorDirectoryScreen> createState() =>
      _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends ConsumerState<DoctorDirectoryScreen> {
  String _query = '';
  String _specialty = 'Todas';
  String? _modality;
  double _minimumRating = 0;
  double? _maximumFiat;
  int? _maximumCoins;
  bool _withSchedule = false;
  String? _expandedProfessionalId;

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(professionalDirectoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Directorio médico')),
      body: directory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'No pudimos cargar el directorio',
          message: error.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(professionalDirectoryProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ),
        data: _buildDirectory,
      ),
    );
  }

  Widget _buildDirectory(List<Professional> professionals) {
    final specialties = [
      'Todas',
      ...{for (final item in professionals) item.specialty},
    ];
    final filtered = professionals.where((item) {
      final query = _query.toLowerCase();
      final services = [
        for (final slot in item.availability)
          if (_modality == null || slot.modality == _modality)
            _serviceForModality(
              ref.watch(catalogProvider).valueOrNull,
              _modalityFromApi(slot.modality),
              isSpecialist: item.isSpecialist,
            ),
      ].whereType<CatalogItem>().toList();
      return (item.fullName.toLowerCase().contains(query) ||
              item.specialty.toLowerCase().contains(query)) &&
          (_modality == null ||
              item.availability.any((slot) => slot.modality == _modality)) &&
          (!_withSchedule ||
              item.bookableSlots.any(
                (slot) => _modality == null || slot.modality == _modality,
              )) &&
          item.averageRating >= _minimumRating &&
          (_maximumFiat == null ||
              services.any(
                (service) =>
                    service.chargeMode == 'fiat' &&
                    service.currency == 'BOB' &&
                    service.price != null &&
                    service.price! <= _maximumFiat!,
              )) &&
          (_maximumCoins == null ||
              services.any(
                (service) =>
                    service.chargeMode == 'coins' &&
                    service.coinPrice != null &&
                    service.coinPrice! <= _maximumCoins!,
              )) &&
          (_specialty == 'Todas' || item.specialty == _specialty);
    }).toList();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Puedes considerar una evaluación inicial con medicina general. El acceso directo a especialistas está disponible salvo condiciones de derivación configuradas.',
          ),
        ),
        ExpansionTile(
          title: const Text(
            'Filtros de modalidad, horarios, calificación y tarifa',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _modality,
                      decoration: const InputDecoration(labelText: 'Modalidad'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas'),
                        ),
                        for (final mode in AppointmentModality.values)
                          DropdownMenuItem(
                            value: _modalityApi(mode),
                            child: Text(_modalityLabel(mode)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _modality = value),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<double>(
                      initialValue: _minimumRating,
                      decoration: const InputDecoration(
                        labelText: 'Calificación mínima',
                      ),
                      items: [
                        for (final rating in [0.0, 3.0, 4.0, 4.5])
                          DropdownMenuItem(
                            value: rating,
                            child: Text(
                              rating == 0 ? 'Sin mínimo' : '$rating de 5',
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _minimumRating = value ?? 0),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Tarifa máxima en Bs',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _maximumFiat = double.tryParse(value)),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Máximo de monedas',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _maximumCoins = int.tryParse(value)),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Con horarios libres (60 días)'),
                    selected: _withSchedule,
                    onSelected: (value) =>
                        setState(() => _withSchedule = value),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: AppTextField(
                hint: 'Buscar médico o especialidad',
                prefixIcon: Icons.search_rounded,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: specialties.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, index) => ChoiceChip(
                  label: Text(specialties[index]),
                  selected: _specialty == specialties[index],
                  onSelected: (_) =>
                      setState(() => _specialty = specialties[index]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Sin resultados',
                  message: 'Prueba con otra búsqueda o especialidad.',
                )
              : AdaptivePage(
                  maxWidth: 980,
                  children: [
                    for (final professional in filtered)
                      _ProfessionalCard(
                        professional: professional,
                        initialPatientId: widget.initialPatientId,
                        assessmentId: widget.assessmentId,
                        expanded: _expandedProfessionalId == professional.id,
                        onTap: () => setState(() {
                          _expandedProfessionalId =
                              _expandedProfessionalId == professional.id
                              ? null
                              : professional.id;
                        }),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProfessionalCard extends ConsumerWidget {
  const _ProfessionalCard({
    required this.professional,
    required this.expanded,
    required this.onTap,
    this.initialPatientId,
    this.assessmentId,
  });
  final Professional professional;
  final String? assessmentId;
  final String? initialPatientId;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: professional.fullName, radius: 26),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(professional.specialty),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _ProfessionalMetaChip(
                          icon: Icons.work_outline_rounded,
                          label: '${professional.yearsExperience} años',
                        ),
                        _ProfessionalMetaChip(
                          icon: Icons.star_rounded,
                          label:
                              '${professional.averageRating.toStringAsFixed(1)} '
                              '(${professional.ratingCount})',
                          iconColor: AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.teal,
              ),
            ],
          ),
          if (expanded) ...[
            _ProfessionalDetailRow(
              icon: Icons.school_outlined,
              label: 'Formación académica',
              value:
                  professional.publicDetails['academicBackground'] as String? ??
                  'Sin formación pública registrada',
            ),
            _ProfessionalDetailRow(
              icon: Icons.workspace_premium_outlined,
              label: 'Certificaciones públicas',
              value:
                  (professional.publicDetails['certifications'] as List? ?? [])
                      .isEmpty
                  ? 'Sin certificaciones públicas registradas'
                  : (professional.publicDetails['certifications'] as List).join(
                      '\n',
                    ),
            ),
            if (professional.publicDetails['bio'] != null)
              Text(professional.publicDetails['bio'] as String),
            _ProfessionalDetailRow(
              icon: Icons.rule_outlined,
              label: 'Condiciones de reserva',
              value: professional.requiresReferral
                  ? 'Requiere derivación activa a esta especialidad.'
                  : 'Permite reserva directa; sujeta a horario y tarifa vigentes.',
            ),
            for (final modality
                in professional.availability
                    .map((slot) => slot.modality)
                    .toSet())
              _ProfessionalDetailRow(
                icon: Icons.payments_outlined,
                label: _modalityLabel(_modalityFromApi(modality)),
                value: _priceLabel(
                  _serviceForModality(
                    ref.watch(catalogProvider).valueOrNull,
                    _modalityFromApi(modality),
                    isSpecialist: professional.isSpecialist,
                  ),
                ),
              ),
            const Text(
              'Comentarios publicados con autorización; se muestran de forma anónima.',
            ),
            if ((professional.publicDetails['reviews'] as List? ?? []).isEmpty)
              const Text('Sin comentarios públicos.'),
            for (final review
                in (professional.publicDetails['reviews'] as List? ?? []))
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(review['comment'] as String),
                subtitle: Text('${review['rating']} de 5'),
              ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            _ProfessionalDetailRow(
              icon: Icons.verified_rounded,
              label: 'Estado',
              value: 'Profesional verificado',
            ),
            _ProfessionalDetailRow(
              icon: Icons.local_hospital_outlined,
              label: 'Especialidad',
              value: professional.specialty,
            ),
            _ProfessionalDetailRow(
              icon: Icons.work_outline_rounded,
              label: 'Experiencia',
              value: '${professional.yearsExperience} años',
            ),
            _ProfessionalDetailRow(
              icon: Icons.star_border_rounded,
              label: 'Valoración',
              value:
                  '${professional.averageRating.toStringAsFixed(1)} de 5 '
                  '(${professional.ratingCount} calificaciones)',
            ),
            _ProfessionalDetailRow(
              icon: Icons.event_available_outlined,
              label: 'Disponibilidad',
              value: _availabilitySummary(professional.availability),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: professional.availability.isEmpty
                    ? null
                    : () async {
                        if (professional.isSpecialist) {
                          final proceed = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              title: const Text('Consulta con especialista'),
                              content: Text(
                                professional.requiresReferral
                                    ? 'Esta especialidad requiere una derivación activa. Puedes consultar primero con medicina general.'
                                    : 'Si aún no tienes una derivación, puedes considerar una evaluación inicial con medicina general. Puedes continuar directamente con el especialista.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: const Text('Volver al directorio'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: const Text('Continuar'),
                                ),
                              ],
                            ),
                          );
                          if (proceed != true || !context.mounted) {
                            return;
                          }
                        }
                        if (!context.mounted) {
                          return;
                        }
                        await showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: _BookingSheet(
                                professional: professional,
                                initialPatientId: initialPatientId,
                                assessmentId: assessmentId,
                              ),
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(
                  professional.availability.isEmpty
                      ? 'Sin horarios disponibles'
                      : 'Agendar cita',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfessionalMetaChip extends StatelessWidget {
  const _ProfessionalMetaChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor ?? scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProfessionalDetailRow extends StatelessWidget {
  const _ProfessionalDetailRow({
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

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({
    required this.professional,
    this.initialPatientId,
    this.assessmentId,
  });
  final Professional professional;
  final String? assessmentId;
  final String? initialPatientId;

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  late AppointmentModality _modality;
  late DateTime _day;
  String? _time;
  String? _patientId;
  bool _saving = false;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _patientId = widget.initialPatientId;
    _modality = _modalities.first;
    _day = _nextAvailableDay(_modality);
    _time = _times.firstOrNull;
  }

  List<AppointmentModality> get _modalities => widget.professional.availability
      .map((item) => _modalityFromApi(item.modality))
      .toSet()
      .toList();

  List<String> get _times =>
      _daySlots.map((slot) => slot.timeLabel).toSet().toList()..sort();
  List<ProfessionalSlot> get _daySlots => widget.professional.bookableSlots
      .where(
        (slot) =>
            slot.modality == _modalityApi(_modality) &&
            DateUtils.isSameDay(slot.localStart, _day),
      )
      .toList();
  DateTime _nextAvailableDay(AppointmentModality modality) {
    final slot = widget.professional.bookableSlots
        .where((slot) => slot.modality == _modalityApi(modality))
        .firstOrNull;
    final date = slot?.localStart ?? DateTime.now();
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final service = _serviceForModality(
      catalog.valueOrNull,
      _modality,
      isSpecialist: widget.professional.isSpecialist,
    );
    final members = ref.watch(familyProvider);
    final targetValid =
        _patientId == null ||
        (members.valueOrNull?.any(
              (member) =>
                  member.patientId == _patientId && member.canBookAppointments,
            ) ??
            false);
    final priceLabel = _priceLabel(service);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agendar con ${widget.professional.fullName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ref
                .watch(familyProvider)
                .when(
                  data: (members) {
                    final authorized = <String, FamilyMember>{
                      for (final member in members.where(
                        (member) =>
                            member.patientId != null &&
                            member.canBookAppointments,
                      ))
                        member.patientId!: member,
                    }.values.toList();
                    final valid =
                        _patientId == null ||
                        authorized.any(
                          (member) => member.patientId == _patientId,
                        );
                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: valid ? _patientId : null,
                          decoration: const InputDecoration(
                            labelText: 'Paciente',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Mi cuenta'),
                            ),
                            for (final member in authorized)
                              DropdownMenuItem(
                                value: member.patientId,
                                child: Text(member.fullName),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _patientId = value),
                        ),
                        if (!valid)
                          const Text(
                            'La autorización seleccionada ya no está disponible. Elige un paciente.',
                          ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text(
                    'No se pudieron consultar pacientes autorizados: $error',
                  ),
                ),
            DropdownButtonFormField<AppointmentModality>(
              key: const ValueKey('booking-modality'),
              initialValue: _modality,
              decoration: const InputDecoration(labelText: 'Modalidad'),
              items: _modalities
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(_modalityLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _modality = value!;
                _day = _nextAvailableDay(value);
                _time = _times.firstOrNull;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha'),
              subtitle: Text(DateFormat('EEEE d MMMM', 'es').format(_day)),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Horario'),
              subtitle: Text(_time ?? 'Selecciona un horario disponible'),
              trailing: const Icon(Icons.schedule_rounded),
              onTap: _pickTime,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reasonController,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Motivo de consulta (opcional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.teal),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto de la cita',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          catalog.isLoading ? 'Cargando tarifa...' : priceLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Se generará una orden pendiente. Para pagar con QR, envía el comprobante desde Pagos.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _BookingActions(
              saving: _saving,
              canSubmit:
                  _time != null &&
                  targetValid &&
                  service != null &&
                  service.chargeMode != null,
              onCancel: () => Navigator.pop(context),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _day = picked;
        _time = _times.firstOrNull;
      });
    }
  }

  Future<void> _pickTime() async {
    final current = _time?.split(':');
    final initialTime = current != null && current.length == 2
        ? TimeOfDay(
            hour: int.tryParse(current[0]) ?? 9,
            minute: int.tryParse(current[1]) ?? 0,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (!_times.contains(value)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ese horario no está disponible para esta modalidad.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _time = value);
  }

  Future<void> _submit() async {
    final service = _serviceForModality(
      ref.read(catalogProvider).valueOrNull,
      _modality,
      isSpecialist: widget.professional.isSpecialist,
    );
    if (service == null || service.chargeMode == null || _time == null) {
      return;
    }
    final slot = _daySlots.where((slot) => slot.timeLabel == _time).firstOrNull;
    if (slot == null) {
      return;
    }
    final start = slot.startAt;
    setState(() => _saving = true);
    try {
      final appointment = await ref
          .read(appointmentsControllerProvider.notifier)
          .create(
            CreateAppointmentCommand(
              professionalId: widget.professional.id,
              serviceId: service.id,
              patientId: _patientId,
              specialtyId: widget.professional.specialtyId,
              modality: _modality,
              startAt: start,
              endAt: slot.endAt,
              reason: _reasonController.text,
            ),
          );
      ref.invalidate(paymentOrdersProvider);
      if (widget.assessmentId != null) {
        try {
          await ref
              .read(guidanceRepositoryProvider)
              .decision(
                widget.assessmentId!,
                'appointment',
                relatedId: appointment.id,
              );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La reserva fue registrada; queda pendiente vincular la orientación.',
                ),
              ),
            );
          }
        }
      }
      ref.invalidate(professionalDirectoryProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.chargeMode == 'coins'
                ? 'Cita agendada. Revisa y paga la orden en tus pagos.'
                : 'Cita agendada. Revisa las instrucciones de pago de tu orden.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}

class _BookingActions extends StatelessWidget {
  const _BookingActions({
    required this.saving,
    required this.canSubmit,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool saving;
  final bool canSubmit;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppDialogActions(
      cancelLabel: 'Cancelar',
      confirmLabel: 'Confirmar cita',
      busy: saving,
      busyLabel: 'Guardando...',
      confirmEnabled: canSubmit,
      onCancel: onCancel,
      onConfirm: onSubmit,
    );
  }
}

AppointmentModality _modalityFromApi(String value) => switch (value) {
  'telemedicine' => AppointmentModality.telemedicine,
  'home_visit' => AppointmentModality.homeVisit,
  _ => AppointmentModality.inPerson,
};

String _modalityLabel(AppointmentModality value) => switch (value) {
  AppointmentModality.inPerson => 'Presencial',
  AppointmentModality.telemedicine => 'Telemedicina',
  AppointmentModality.homeVisit => 'Visita a domicilio',
};

String _modalityApi(AppointmentModality value) => switch (value) {
  AppointmentModality.inPerson => 'in_person',
  AppointmentModality.telemedicine => 'telemedicine',
  AppointmentModality.homeVisit => 'home_visit',
};

CatalogItem? _serviceForModality(
  List<CatalogItem>? items,
  AppointmentModality modality, {
  bool isSpecialist = false,
}) {
  if (items == null) return null;
  final code = switch (modality) {
    AppointmentModality.telemedicine =>
      isSpecialist
          ? 'consult_specialist_telemedicine'
          : 'consult_general_telemedicine',
    AppointmentModality.inPerson =>
      isSpecialist
          ? 'consult_specialist_in_person'
          : 'consult_general_in_person',
    AppointmentModality.homeVisit => 'home_visit',
  };
  for (final item in items) {
    if (item.code.toLowerCase() == code) return item;
  }
  return null;
}

String _priceLabel(CatalogItem? service) {
  if (service == null) return 'Tarifa no registrada';
  if (service.chargeMode == 'coins') {
    return service.coinPrice == null
        ? 'Tarifa no registrada'
        : '${service.coinPrice} monedas';
  }
  if (service.price == null) return 'Tarifa no registrada';
  return NumberFormat.currency(
    locale: 'es_BO',
    symbol: '${service.currency ?? 'Bs'} ',
    decimalDigits: 2,
  ).format(service.price);
}

String _availabilitySummary(List<ProfessionalAvailability> availability) {
  if (availability.isEmpty) return 'Sin horarios publicados';
  return availability
      .map(
        (slot) =>
            '${_weekdayLabel(slot.weekday)} · ${slot.startTime}-${slot.endTime} · '
            '${_modalityLabel(_modalityFromApi(slot.modality))}',
      )
      .join('\n');
}

String _weekdayLabel(int weekday) => switch (weekday) {
  0 => 'Domingo',
  1 => 'Lunes',
  2 => 'Martes',
  3 => 'Miercoles',
  4 => 'Jueves',
  5 => 'Viernes',
  6 => 'Sabado',
  _ => 'Dia no registrado',
};
