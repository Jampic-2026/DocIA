import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/clinical_document.dart';
import '../../domain/vital_sign_record.dart';

class VitalSignRecordCard extends StatelessWidget {
  const VitalSignRecordCard({super.key, required this.record, this.badgeLabel});

  final VitalSignRecord record;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final values = <(IconData, String)>[
      if (record.systolicPressure != null || record.diastolicPressure != null)
        (Icons.favorite_outline, '${record.systolicPressure ?? '—'}/${record.diastolicPressure ?? '—'} mmHg'),
      if (record.heartRate != null) (Icons.monitor_heart_outlined, '${record.heartRate} lpm'),
      if (record.temperatureC != null) (Icons.thermostat_outlined, '${record.temperatureC} °C'),
      if (record.oxygenSaturation != null) (Icons.air_rounded, '${record.oxygenSaturation} % SpO₂'),
      if (record.respiratoryRate != null) (Icons.air_outlined, '${record.respiratoryRate} rpm'),
      if (record.glucoseMgDl != null) (Icons.bloodtype_outlined, '${record.glucoseMgDl} mg/dL'),
      if (record.weightKg != null) (Icons.monitor_weight_outlined, '${record.weightKg} kg'),
      if (record.heightCm != null) (Icons.height_rounded, '${record.heightCm} cm'),
    ];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.health_and_safety_outlined, color: AppColors.teal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(DateFormat('dd/MM/yyyy HH:mm').format(record.recordedAt), style: const TextStyle(fontWeight: FontWeight.w700))),
          if (badgeLabel != null) StatusPill(label: badgeLabel!, color: AppColors.blue, dense: true),
        ]),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
          for (final value in values)
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(value.$1, size: 18), const SizedBox(width: 5), Text(value.$2)]),
        ]),
        if (record.notes?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(record.notes!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    );
  }
}

class ClinicalDocumentCard extends StatelessWidget {
  const ClinicalDocumentCard({
    super.key,
    required this.document,
    required this.onOpen,
    this.actions = const [],
  });

  final ClinicalDocument document;
  final VoidCallback onOpen;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(children: [
          InkWell(
            onTap: onOpen,
            child: Row(children: [
              const Icon(Icons.description_outlined, color: AppColors.blue, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(document.fileName?.isNotEmpty == true ? document.fileName! : clinicalDocumentTypeLabel(document.documentType), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${clinicalDocumentTypeLabel(document.documentType)} · ${DateFormat('dd/MM/yyyy').format(document.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                StatusPill(label: clinicalValidationLabel(document.validationStatus), color: document.validationStatus == 'validated' ? AppColors.success : document.validationStatus == 'rejected' ? AppColors.danger : AppColors.warning, dense: true),
              ])),
              Icon(document.isRestricted ? Icons.lock_outline_rounded : Icons.open_in_new_rounded),
            ]),
          ),
          if (actions.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ]),
      );
}

String clinicalDocumentTypeLabel(String type) => switch (type) {
      'laboratory' => 'Laboratorio',
      'imaging' => 'Imagen médica',
      'report' => 'Informe médico',
      'prescription' => 'Receta',
      _ => 'Otro documento',
    };

String clinicalValidationLabel(String status) => switch (status) {
      'validated' => 'Validado',
      'rejected' => 'Observado',
      'self_declared' => 'Declarado por paciente',
      _ => 'Pendiente de validación',
    };
