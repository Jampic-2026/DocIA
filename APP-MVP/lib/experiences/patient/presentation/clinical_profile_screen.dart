import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/clinical_records/application/clinical_records_controller.dart';
import '../../../modules/clinical_records/domain/clinical_profile.dart';
import '../../../modules/clinical_records/presentation/clinical_history_screen.dart';
import '../../../modules/clinical_records/presentation/profile_completion_card.dart';
import '../../../modules/partners/presentation/diagnostic_orders_screen.dart';

class ClinicalProfileScreen extends ConsumerWidget {
  const ClinicalProfileScreen({super.key, this.patientId, this.canEdit = true});
  final String? patientId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = patientId == null
        ? ref.watch(clinicalProfileProvider)
        : ref.watch(patientClinicalProfileProvider(patientId!));
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            MediaQuery.sizeOf(context).width < AppDimensions.compactBreakpoint,
        title: const Text('Perfil clínico'),
      ),
      body: profile.when(
        loading: () =>
            const AppLoadingState(message: 'Cargando tu perfil clínico'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(profileCompletionProvider);
            ref.invalidate(clinicalProfileProvider);
            ref.invalidate(patientClinicalProfileProvider);
          },
        ),
        data: (data) => _ProfileContent(
          profile: data,
          ownProfile: patientId == null,
          onEdit: !canEdit
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _ClinicalProfileForm(profile: data),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.onEdit,
    required this.ownProfile,
  });
  final bool ownProfile;
  final ClinicalProfile profile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTwoColumnPage(
      primaryFlex: 3,
      secondaryFlex: 2,
      maxWidth: 1180,
      primary: [
        ProfileCompletionCard(patientId: profile.patientId),
        const _ClinicalProfileNotice(),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Actualizar ficha clínica'),
        ),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: profile.bloodType ?? '—',
                label: 'Tipo de sangre',
                icon: Icons.water_drop_rounded,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                value: profile.heightCm == null
                    ? '—'
                    : '${profile.heightCm!.toStringAsFixed(0)} cm',
                label: 'Estatura',
                icon: Icons.height_rounded,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                value: profile.weightKg == null
                    ? '—'
                    : '${profile.weightKg!.toStringAsFixed(0)} kg',
                label: 'Peso',
                icon: Icons.monitor_weight_rounded,
                color: AppColors.teal,
              ),
            ),
          ],
        ),
        _ChipSection(
          title: 'Alergias',
          color: AppColors.warning,
          items: profile.allergies,
          emptyText: 'Sin alergias registradas',
        ),
        _ChipSection(
          title: 'Antecedentes médicos',
          color: AppColors.blue,
          items: profile.medicalHistory,
          emptyText: 'Sin antecedentes médicos registrados',
        ),
        _ChipSection(
          title: 'Antecedentes familiares',
          color: AppColors.navy,
          items: profile.familyHistory,
          emptyText: 'Sin antecedentes familiares registrados',
        ),
        _ChipSection(
          title: 'Antecedentes quirúrgicos',
          color: AppColors.info,
          items: profile.surgicalHistory,
          emptyText: 'Sin antecedentes quirúrgicos registrados',
        ),
        _ChipSection(
          title: 'Condiciones crónicas',
          color: AppColors.info,
          items: profile.chronicConditions,
          emptyText: 'Sin condiciones registradas',
        ),
        _ChipSection(
          title: 'Medicación actual',
          color: AppColors.teal,
          items: profile.currentMedications,
          emptyText: 'Sin medicación registrada',
        ),
      ],
      secondary: [
        AppCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  DiagnosticOrdersScreen(patientId: profile.patientId),
            ),
          ),
          child: const ListTile(
            leading: Icon(Icons.science_outlined),
            title: Text('Estudios solicitados'),
          ),
        ),
        AppCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  ClinicalHistoryScreen(patientId: profile.patientId),
            ),
          ),
          child: const ListTile(
            leading: Icon(Icons.history),
            title: Text('Historial y evolución'),
            subtitle: Text('Categorías, mediciones y copia digital'),
          ),
        ),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('Seguro de salud'),
            subtitle: Text(
              [
                    if (profile.insuranceProvider?.isNotEmpty ?? false)
                      profile.insuranceProvider!,
                    if (profile.insuranceNumber?.isNotEmpty ?? false)
                      'N.º ${profile.insuranceNumber}',
                  ].isEmpty
                  ? 'No registrado'
                  : [
                      if (profile.insuranceProvider?.isNotEmpty ?? false)
                        profile.insuranceProvider!,
                      if (profile.insuranceNumber?.isNotEmpty ?? false)
                        'N.º ${profile.insuranceNumber}',
                    ].join(' · '),
            ),
          ),
        ),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.contact_emergency_rounded,
              color: AppColors.danger,
            ),
            title: const Text('Contacto de emergencia'),
            subtitle: Text(_emergencyContact(profile)),
          ),
        ),
        if (profile.profileNotes?.isNotEmpty ?? false) ...[
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notes_rounded),
              title: const Text('Observaciones'),
              subtitle: Text(profile.profileNotes!),
            ),
          ),
        ],
        if (ownProfile)
          AppCard(
            onTap: () => context.pushNamed(AppRoutes.vitalSigns),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.monitor_heart_outlined,
                color: AppColors.teal,
              ),
              title: Text('Signos vitales'),
              subtitle: Text('Mediciones e historial de salud'),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
        if (ownProfile)
          AppCard(
            onTap: () => context.pushNamed(AppRoutes.clinicalDocuments),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_copy_outlined, color: AppColors.blue),
              title: Text('Documentos clínicos'),
              subtitle: Text('Estudios, imágenes e informes'),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
      ],
    );
  }
}

String _emergencyContact(ClinicalProfile profile) {
  final values = [
    profile.emergencyContactName,
    profile.emergencyContactRelationship,
    profile.emergencyContactPhone,
    profile.emergencyContactEmail,
  ].whereType<String>().where((value) => value.isNotEmpty).toList();
  return values.isEmpty ? 'No registrado' : values.join(' · ');
}

class _ClinicalProfileForm extends ConsumerStatefulWidget {
  const _ClinicalProfileForm({required this.profile});

  final ClinicalProfile profile;

  @override
  ConsumerState<_ClinicalProfileForm> createState() =>
      _ClinicalProfileFormState();
}

class _ClinicalProfileFormState extends ConsumerState<_ClinicalProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late String _bloodType;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _insuranceProvider;
  late final TextEditingController _insuranceNumber;
  late final TextEditingController _notes;
  late final List<String> _allergies;
  late final List<String> _conditions;
  late final List<String> _medications;
  late final List<String> _medicalHistory;
  late final List<String> _familyHistory;
  late final List<String> _surgicalHistory;
  final _allergiesKey = GlobalKey<_ChipInputFieldState>();
  final _conditionsKey = GlobalKey<_ChipInputFieldState>();
  final _medicationsKey = GlobalKey<_ChipInputFieldState>();
  final _medicalHistoryKey = GlobalKey<_ChipInputFieldState>();
  final _familyHistoryKey = GlobalKey<_ChipInputFieldState>();
  final _surgicalHistoryKey = GlobalKey<_ChipInputFieldState>();
  late final TextEditingController _contactName;
  late final TextEditingController _contactRelationship;
  late final TextEditingController _contactPhone;
  late final TextEditingController _contactEmail;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _bloodType = profile.bloodType ?? '';
    _height = _controller(profile.heightCm?.toStringAsFixed(0));
    _weight = _controller(profile.weightKg?.toStringAsFixed(1));
    _insuranceProvider = _controller(profile.insuranceProvider);
    _insuranceNumber = _controller(profile.insuranceNumber);
    _notes = _controller(profile.profileNotes);
    _allergies = [...profile.allergies];
    _conditions = [...profile.chronicConditions];
    _medications = [...profile.currentMedications];
    _medicalHistory = [...profile.medicalHistory];
    _familyHistory = [...profile.familyHistory];
    _surgicalHistory = [...profile.surgicalHistory];
    _contactName = _controller(profile.emergencyContactName);
    _contactRelationship = _controller(profile.emergencyContactRelationship);
    _contactPhone = _controller(profile.emergencyContactPhone);
    _contactEmail = _controller(profile.emergencyContactEmail);
  }

  TextEditingController _controller(String? value) =>
      TextEditingController(text: value ?? '');

  @override
  void dispose() {
    for (final controller in [
      _height,
      _weight,
      _insuranceProvider,
      _insuranceNumber,
      _notes,
      _contactName,
      _contactRelationship,
      _contactPhone,
      _contactEmail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    for (final key in [
      _allergiesKey,
      _conditionsKey,
      _medicationsKey,
      _medicalHistoryKey,
      _familyHistoryKey,
      _surgicalHistoryKey,
    ]) {
      key.currentState?.addPendingInput();
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(clinicalRecordsRepositoryProvider)
          .updateProfile(
            UpdateClinicalProfileCommand(
              patientId: widget.profile.patientId,
              bloodType: _bloodType,
              heightCm: _number(_height.text),
              weightKg: _number(_weight.text),
              insuranceProvider: _insuranceProvider.text.trim(),
              insuranceNumber: _insuranceNumber.text.trim(),
              profileNotes: _notes.text.trim(),
              allergies: _allergies,
              chronicConditions: _conditions,
              currentMedications: _medications,
              medicalHistory: _medicalHistory,
              familyHistory: _familyHistory,
              surgicalHistory: _surgicalHistory,
              emergencyContactName: _contactName.text.trim(),
              emergencyContactRelationship: _contactRelationship.text.trim(),
              emergencyContactPhone: _contactPhone.text.trim(),
              emergencyContactEmail: _contactEmail.text.trim(),
            ),
          );
      ref.invalidate(clinicalProfileProvider);
      ref.invalidate(patientClinicalProfileProvider(widget.profile.patientId));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ficha clínica actualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text(
              'Actualizar ficha clínica',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            const _ClinicalProfileNotice(),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _bloodType.isEmpty ? null : _bloodType,
              decoration: const InputDecoration(labelText: 'Tipo de sangre'),
              items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => _bloodType = value ?? '',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _numberField(_height, 'Estatura (cm)', 30, 250),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _numberField(_weight, 'Peso (kg)', 1, 500)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Cobertura de salud'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _insuranceProvider,
              label: 'Seguro o entidad',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _insuranceNumber,
              label: 'Número de afiliación',
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'Información clínica',
              subtitle: 'Agrega cada dato como etiqueta',
            ),
            const SizedBox(height: AppSpacing.sm),
            _chipField(_allergiesKey, _allergies, 'Alergias'),
            _chipField(_conditionsKey, _conditions, 'Condiciones crónicas'),
            _chipField(_medicationsKey, _medications, 'Medicación actual'),
            _chipField(
              _medicalHistoryKey,
              _medicalHistory,
              'Antecedentes médicos',
            ),
            _chipField(
              _familyHistoryKey,
              _familyHistory,
              'Antecedentes familiares',
            ),
            _chipField(
              _surgicalHistoryKey,
              _surgicalHistory,
              'Antecedentes quirúrgicos',
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Contacto de emergencia'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(controller: _contactName, label: 'Nombre completo'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _contactRelationship, label: 'Parentesco'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _contactPhone,
              label: 'Teléfono',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (_contactName.text.trim().isNotEmpty &&
                    (value?.trim().isEmpty ?? true)) {
                  return 'Ingresa el teléfono del contacto';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _contactEmail,
              label: 'Correo (opcional)',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                return email.isNotEmpty && !email.contains('@')
                    ? 'Ingresa un correo válido'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _notes,
              label: 'Observaciones',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            _FormActions(
              saving: _saving,
              saveLabel: 'Guardar ficha',
              onCancel: () => Navigator.pop(context),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    double min,
    double max,
  ) {
    return AppTextField(
      controller: controller,
      label: label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final number = _number(value);
        return number == null || number < min || number > max
            ? 'Valor entre ${min.toInt()} y ${max.toInt()}'
            : null;
      },
    );
  }

  Widget _chipField(
    GlobalKey<_ChipInputFieldState> key,
    List<String> values,
    String label,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: _ChipInputField(
      key: key,
      label: label,
      values: values,
      onChanged: () => setState(() {}),
    ),
  );
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.saving,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppDialogActions(
      cancelLabel: 'Cancelar',
      confirmLabel: saveLabel,
      busy: saving,
      busyLabel: 'Guardando...',
      confirmIcon: Icons.save_outlined,
      onCancel: onCancel,
      onConfirm: onSave,
    );
  }
}

class _ClinicalProfileNotice extends StatelessWidget {
  const _ClinicalProfileNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.teal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Esta información será utilizada por los doctores durante tu atención. Complétala con datos lo más fieles y actualizados posible.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double? _number(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.color,
    required this.items,
    required this.emptyText,
  });
  final String title;
  final Color color;
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            Text(emptyText)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in items)
                  Chip(
                    label: Text(item),
                    backgroundColor: color.withValues(alpha: 0.10),
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChipInputField extends StatefulWidget {
  const _ChipInputField({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final List<String> values;
  final VoidCallback onChanged;

  @override
  State<_ChipInputField> createState() => _ChipInputFieldState();
}

class _ChipInputFieldState extends State<_ChipInputField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void addPendingInput() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final values = raw
        .split(RegExp(r'[,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    var changed = false;
    for (final value in values) {
      final exists = widget.values.any(
        (item) => item.toLowerCase() == value.toLowerCase(),
      );
      if (!exists) {
        widget.values.add(value);
        changed = true;
      }
    }
    if (!changed) return;
    _controller.clear();
    widget.onChanged();
  }

  void _remove(String value) {
    widget.values.remove(value);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Escribe y presiona Enter',
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onSubmitted: (_) => addPendingInput(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              tooltip: 'Agregar',
              onPressed: addPendingInput,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final value in widget.values)
                InputChip(label: Text(value), onDeleted: () => _remove(value)),
            ],
          ),
        ],
      ],
    );
  }
}
