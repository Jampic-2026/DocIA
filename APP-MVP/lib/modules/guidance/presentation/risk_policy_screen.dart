import '../../../core/widgets/app_action_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dialog_actions.dart';
import '../../auth/application/auth_controller.dart';
import '../application/guidance_controller.dart';

class RiskPolicyScreen extends ConsumerStatefulWidget {
  const RiskPolicyScreen({super.key});
  @override
  ConsumerState<RiskPolicyScreen> createState() => _RiskPolicyState();
}

class _RiskPolicyState extends ConsumerState<RiskPolicyScreen> {
  List<Map<String, dynamic>>? draft;
  bool busy = false;
  Future<void> run(Future<void> Function() operation) async {
    setState(() => busy = true);
    try {
      await operation();
      if (mounted) setState(() => draft = null);
      ref.invalidate(riskPolicyProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(List<Map<String, dynamic>> rules, int? index) async {
    final value = await showAppDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RuleEditor(initial: index == null ? null : rules[index]),
    );
    if (value == null || !mounted) return;
    setState(() {
      draft = List.of(rules);
      if (index == null) {
        draft!.add(value);
      } else {
        draft![index] = value;
      }
    });
  }

  Future<void> approve(int revision) async {
    final controller = TextEditingController();
    String? reference;
    try {
      reference = await showAppDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validación clínica de reglas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirma que revisaste los criterios, acciones y preguntas de esta revisión. Registrar la referencia activa su clasificación clínica.',
              ),
              TextField(
                controller: controller,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Referencia del protocolo o acta aprobada',
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Volver',
                confirmLabel: 'Validar y activar',
                onCancel: () => Navigator.pop(context),
                onConfirm: () {
                  if (controller.text.trim().length >= 8) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (reference != null && mounted) {
      await run(
        () => ref
            .read(guidanceRepositoryProvider)
            .approvePolicy(revision, reference!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configuration = ref.watch(riskPolicyProvider);
    final clinical =
        ref
            .watch(authControllerProvider)
            .user
            ?.hasRole('clinical_supervisor') ??
        false;
    return Scaffold(
      appBar: AppBar(title: const Text('Reglas de orientación clínica')),
      body: configuration.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString()),
              TextButton(
                onPressed: () => ref.invalidate(riskPolicyProvider),
                child: const Text(
                  'Reintentar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        data: (data) {
          final rules =
              draft ??
              ((data['policy'] as Map)['rules'] as List)
                  .map((rule) => Map<String, dynamic>.from(rule as Map))
                  .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data['enabled'] == true
                    ? 'Clasificación habilitada con validación clínica'
                    : 'Clasificación desactivada; no se presume bajo riesgo',
              ),
              const Text(
                'Toda modificación guardada retira la aprobación anterior. Las alertas preventivas existentes siguen disponibles.',
              ),
              if (busy) const LinearProgressIndicator(),
              if (rules.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No se han definido criterios clínicos.'),
                ),
              for (var index = 0; index < rules.length; index++)
                Card(
                  child: ListTile(
                    title: Text(rules[index]['code'] as String),
                    subtitle: Text(
                      '${rules[index]['riskLevel']} · ${rules[index]['action']}\n${(rules[index]['terms'] as List).join(', ')}',
                    ),
                    isThreeLine: true,
                    onTap: busy ? null : () => edit(rules, index),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              draft = List.of(rules)..removeAt(index);
                            }),
                    ),
                  ),
                ),
              AppActionRow(
                children: [
                  OutlinedButton(
                    onPressed: busy ? null : () => edit(rules, null),
                    child: const Text(
                      'Añadir criterio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || draft == null
                        ? null
                        : () => run(
                            () => ref
                                .read(guidanceRepositoryProvider)
                                .savePolicy(rules),
                          ),
                    child: const Text(
                      'Guardar y desactivar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (clinical)
                    FilledButton(
                      onPressed: busy || draft != null || rules.isEmpty
                          ? null
                          : () => approve(data['revision'] as int),
                      child: const Text(
                        'Validar clínicamente y activar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController code, terms, antecedents, questions;
  String? risk, action;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    code = TextEditingController(text: initial?['code'] as String?);
    terms = TextEditingController(
      text: (initial?['terms'] as List? ?? []).join('\n'),
    );
    antecedents = TextEditingController(
      text: (initial?['antecedentTerms'] as List? ?? []).join('\n'),
    );
    questions = TextEditingController(
      text: (initial?['questions'] as List? ?? []).join('\n'),
    );
    risk = initial?['riskLevel'] as String?;
    action = initial?['action'] as String?;
  }

  @override
  void dispose() {
    code.dispose();
    terms.dispose();
    antecedents.dispose();
    questions.dispose();
    super.dispose();
  }

  List<String> lines(TextEditingController controller) => controller.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Criterio clínico configurable'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: code,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Identificador del criterio',
                ),
                validator: (value) =>
                    RegExp(r'^[a-zA-Z0-9_-]{1,60}$').hasMatch(value ?? '')
                    ? null
                    : 'Usa letras, números o guion',
              ),
              TextFormField(
                controller: terms,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Términos del diálogo, uno por línea',
                ),
                validator: (value) =>
                    lines(terms).isEmpty ? 'Define al menos un término' : null,
              ),
              TextFormField(
                controller: antecedents,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Antecedentes necesarios, uno por línea; opcional',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: risk,
                decoration: const InputDecoration(labelText: 'Nivel de riesgo'),
                items: const [
                  DropdownMenuItem(value: 'green', child: Text('Verde')),
                  DropdownMenuItem(value: 'yellow', child: Text('Amarillo')),
                  DropdownMenuItem(value: 'red', child: Text('Rojo')),
                ],
                onChanged: (value) => setState(() {
                  risk = value;
                  if (value == 'red') action = 'emergency';
                }),
                validator: (value) =>
                    value == null ? 'Selecciona un nivel' : null,
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(action),
                initialValue: action,
                decoration: const InputDecoration(
                  labelText: 'Acción recomendada',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'emergency',
                    child: Text('Emergencia'),
                  ),
                  DropdownMenuItem(
                    value: 'appointment',
                    child: Text('Consulta médica'),
                  ),
                  DropdownMenuItem(
                    value: 'call_operator',
                    child: Text('Orientación humana'),
                  ),
                ],
                onChanged: (value) => setState(() => action = value),
                validator: (value) =>
                    value == null || risk == 'red' && value != 'emergency'
                    ? 'Selecciona una acción compatible'
                    : null,
              ),
              TextFormField(
                controller: questions,
                maxLines: 4,
                maxLength: 1500,
                decoration: const InputDecoration(
                  labelText:
                      'Preguntas complementarias, una por línea; opcional',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      SizedBox(
        width: 420,
        child: AppDialogActions(
          cancelLabel: 'Cancelar',
          confirmLabel: 'Guardar criterio',
          onCancel: () => Navigator.pop(context),
          onConfirm: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, {
                'code': code.text.trim(),
                'terms': lines(terms),
                'antecedentTerms': lines(antecedents),
                'riskLevel': risk,
                'action': action,
                'questions': lines(questions),
              });
            }
          },
        ),
      ),
    ],
  );
}
