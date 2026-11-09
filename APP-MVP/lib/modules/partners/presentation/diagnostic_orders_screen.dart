import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/app_file_link.dart';
import '../application/partners_controller.dart';

final diagnosticOrdersProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(partnersRepositoryProvider).diagnosticOrders(),
);

class DiagnosticOrdersScreen extends ConsumerWidget {
  const DiagnosticOrdersScreen({
    super.key,
    required this.patientId,
    this.appointmentId,
    this.canOrder = false,
  });
  final String patientId;
  final String? appointmentId;
  final bool canOrder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Estudios diagnósticos')),
    floatingActionButton: !canOrder
        ? null
        : FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Solicitar estudio'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _OrderForm(
                patientId: patientId,
                appointmentId: appointmentId,
              ),
            ),
          ),
    body: ref
        .watch(diagnosticOrdersProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando estudios'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(diagnosticOrdersProvider),
          ),
          data: (items) {
            final selected = items
                .where((row) => row['patient_id'] == patientId)
                .toList();
            if (selected.isEmpty) {
              return const Center(
                child: Text(
                  'No existen órdenes diagnósticas para este paciente.',
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(diagnosticOrdersProvider);
                await ref.read(diagnosticOrdersProvider.future);
              },
              child: ListView(
                children: [
                  for (final row in selected)
                    ListTile(
                      leading: const Icon(Icons.science_outlined),
                      title: Text(row['description'] as String),
                      subtitle: Text(
                        '${_type(row['order_type'])} · ${_status(row['status'])}\n${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(row['created_at'] as String).toLocal())}',
                      ),
                      trailing: row['result_file_url'] is String
                          ? AppFileLink(
                              fileUrl: row['result_file_url'] as String,
                              label: 'Abrir resultado',
                            )
                          : null,
                      isThreeLine: true,
                    ),
                ],
              ),
            );
          },
        ),
  );
  String _type(Object? type) => switch (type) {
    'lab' => 'Laboratorio',
    'imaging' => 'Imagenología',
    _ => 'Otro estudio',
  };
  String _status(Object? status) => switch (status) {
    'requested' => 'Solicitado',
    'in_progress' => 'En proceso',
    'completed' => 'Resultado disponible',
    'cancelled' => 'Cancelado',
    _ => 'Estado no reconocido',
  };
}

class _OrderForm extends ConsumerStatefulWidget {
  const _OrderForm({required this.patientId, this.appointmentId});
  final String patientId;
  final String? appointmentId;
  @override
  ConsumerState<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<_OrderForm> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _type = 'lab';
  String? _partnerId;
  bool _saving = false;
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Solicitar estudio'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo de estudio'),
              items: const [
                DropdownMenuItem(value: 'lab', child: Text('Laboratorio')),
                DropdownMenuItem(value: 'imaging', child: Text('Imagenología')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? 'lab'),
            ),
            ref
                .watch(partnersProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('No se pudo consultar centros: $error'),
                  data: (partners) => DropdownButtonFormField<String>(
                    initialValue: _partnerId,
                    decoration: const InputDecoration(
                      labelText: 'Centro (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin centro asignado'),
                      ),
                      for (final partner in partners.where(
                        (item) =>
                            item.isActive &&
                            [
                              'laboratory',
                              'imaging',
                              'imaging_center',
                            ].contains(item.partnerType),
                      ))
                        DropdownMenuItem(
                          value: partner.id,
                          child: Text(partner.name),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _partnerId = value),
                  ),
                ),
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Estudio e indicaciones',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Describe el estudio solicitado.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Solicitar'),
      ),
    ],
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(partnersRepositoryProvider)
          .createDiagnosticOrder(
            patientId: widget.patientId,
            appointmentId: widget.appointmentId,
            partnerId: _partnerId,
            orderType: _type,
            description: _description.text.trim(),
          );
      ref.invalidate(diagnosticOrdersProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
