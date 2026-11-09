import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/widgets.dart';
import '../application/clinical_records_controller.dart';
import '../domain/clinical_history.dart';
import '../infrastructure/export_file.dart';
import 'measurement_chart.dart';

const clinicalCategoryLabels = <String, String>{
  'antecedent': 'Antecedentes',
  'allergy': 'Alergias',
  'vital_sign': 'Signos vitales',
  'note': 'Consultas',
  'diagnosis': 'Diagnósticos',
  'treatment': 'Tratamientos',
  'prescription': 'Recetas',
  'emergency': 'Emergencias',
  'document': 'Documentos',
};
const clinicalMetricLabels = <String, String>{
  'systolicPressure': 'Presión sistólica (mmHg)',
  'diastolicPressure': 'Presión diastólica (mmHg)',
  'heartRate': 'Frecuencia cardíaca (lpm)',
  'temperatureC': 'Temperatura (°C)',
  'oxygenSaturation': 'Saturación de oxígeno (%)',
  'respiratoryRate': 'Frecuencia respiratoria (rpm)',
  'glucoseMgDl': 'Glucosa (mg/dL)',
  'weightKg': 'Peso (kg)',
  'heightCm': 'Estatura (cm)',
};

class ClinicalHistoryScreen extends ConsumerStatefulWidget {
  const ClinicalHistoryScreen({super.key, this.patientId});
  final String? patientId;
  @override
  ConsumerState<ClinicalHistoryScreen> createState() =>
      _ClinicalHistoryScreenState();
}

class _ClinicalHistoryScreenState extends ConsumerState<ClinicalHistoryScreen> {
  String? _category;
  int _days = 90;
  bool _exporting = false;
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(clinicalHistoryProvider(widget.patientId));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historial y evolución'),
          actions: [
            PopupMenuButton<String>(
              enabled: !_exporting,
              tooltip: 'Exportar copia clínica',
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'jampic',
                  child: Text('Descargar JSON clínico'),
                ),
                PopupMenuItem(
                  value: 'fhir',
                  child: Text('Descargar FHIR JSON'),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Historial'),
              Tab(text: 'Evolución'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      for (final entry in clinicalCategoryLabels.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => setState(() => _category = value),
                  ),
                ),
                Expanded(
                  child: history.when(
                    loading: () =>
                        const AppLoadingState(message: 'Cargando historial'),
                    error: (error, _) => AppErrorState(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(
                        clinicalHistoryProvider(widget.patientId),
                      ),
                    ),
                    data: (items) => _history(
                      items
                          .where(
                            (item) =>
                                _category == null || item.type == _category,
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
            _trends(),
          ],
        ),
      ),
    );
  }

  Widget _history(List<ClinicalHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No hay registros en esta categoría.'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(clinicalHistoryProvider(widget.patientId));
        await ref.read(clinicalHistoryProvider(widget.patientId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in entries)
            Card(
              child: ExpansionTile(
                title: Text(entry.title),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy HH:mm').format(entry.recordedAt)} · ${clinicalCategoryLabels[entry.type] ?? 'Otro registro'}',
                ),
                children: [
                  ListTile(
                    title: Text(entry.summary),
                    subtitle: Text(
                      [
                        entry.authorName ?? 'Autor no disponible',
                        if (entry.specialty != null) entry.specialty!,
                        entry.validationStatus == 'validated'
                            ? 'Validado'
                            : 'Declarado o pendiente de validación',
                      ].join(' · '),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _trends() {
    final query = (patientId: widget.patientId, days: _days);
    final trends = ref.watch(clinicalTrendsProvider(query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<int>(
            initialValue: _days,
            decoration: const InputDecoration(labelText: 'Período'),
            items: [
              for (final days in [30, 90, 180, 365])
                DropdownMenuItem(
                  value: days,
                  child: Text('Últimos $days días'),
                ),
            ],
            onChanged: (value) => setState(() => _days = value ?? 90),
          ),
        ),
        Expanded(
          child: trends.when(
            loading: () => const AppLoadingState(message: 'Cargando evolución'),
            error: (error, _) => AppErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(clinicalTrendsProvider(query)),
            ),
            data: (data) => data.points.isEmpty
                ? const Center(
                    child: Text('No hay mediciones en este período.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Los valores muestran mediciones registradas y no constituyen un diagnóstico.',
                      ),
                      for (final metric in clinicalMetricLabels.entries)
                        if (data.summary[metric.key] != null)
                          ExpansionTile(
                            title: Text(metric.value),
                            subtitle: Text(
                              'Mínimo: ${data.summary[metric.key]['minimum']} · Máximo: ${data.summary[metric.key]['maximum']} · Promedio: ${data.summary[metric.key]['average']}',
                            ),
                            children: [
                              MeasurementChart(
                                points: data.points,
                                metric: metric.key,
                              ),
                              for (final point in data.points)
                                if (point[metric.key] != null)
                                  ListTile(
                                    title: Text('${point[metric.key]}'),
                                    subtitle: Text(
                                      "${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(point['recordedAt'] as String).toLocal())} · ${point['source'] == 'professional' ? 'Registrado por profesional' : 'Declarado por paciente'}${point['appointmentId'] != null
                                          ? ' · Consulta'
                                          : point['emergencyId'] != null
                                          ? ' · Emergencia'
                                          : ''}",
                                    ),
                                  ),
                            ],
                          ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _export(String format) async {
    const labels = {
      'vitalSigns': 'Signos vitales',
      'encounters': 'Consultas cerradas',
      'conditions': 'Diagnósticos',
      'medicationRequests': 'Recetas emitidas',
      'clinicalRecords': 'Registros clínicos visibles',
    };
    final selected = labels.keys.toSet();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Descargar información clínica'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecciona las categorías. La copia contiene información de salud. Elige un destino privado.',
                ),
                for (final item in labels.entries)
                  CheckboxListTile(
                    title: Text(item.value),
                    value: selected.contains(item.key),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected.add(item.key);
                      } else {
                        selected.remove(item.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Descargar'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final data = await ref
          .read(clinicalRecordsRepositoryProvider)
          .exportRecord(
            patientId: widget.patientId,
            format: format,
            categories: selected.toList(),
          );
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia clínica',
        fileName: 'historial_$format.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      await writeExportFile(path, bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}
