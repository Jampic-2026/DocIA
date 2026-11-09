import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/clinical_records_controller.dart';

class ProfileCompletionCard extends ConsumerWidget {
  const ProfileCompletionCard({
    super.key,
    this.patientId,
    this.professionalView = false,
  });
  final String? patientId;
  final bool professionalView;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ref
          .watch(profileCompletionProvider(patientId))
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Column(
              children: [
                Text(error.toString()),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(profileCompletionProvider(patientId)),
                  child: const Text('Reintentar completitud'),
                ),
              ],
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['configured'] == true
                      ? 'Perfil completo: ${data['percent']} %'
                      : 'Reglas de completitud pendientes de configuración',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (data['percent'] is num)
                  LinearProgressIndicator(
                    value: (data['percent'] as num) / 100,
                  ),
                for (final row
                    in (data['missing'] as List).cast<Map<String, dynamic>>())
                  if (!professionalView || row['actor'] == 'professional')
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        row['actor'] == 'professional'
                            ? Icons.medical_services_outlined
                            : Icons.person_outline,
                      ),
                      title: Text(row['label'] as String),
                      subtitle: Text(
                        row['actor'] == 'professional'
                            ? 'Debe registrar o validar un profesional durante la atención.'
                            : 'Completa esta sección de tu ficha clínica.',
                      ),
                    ),
                if (data['configured'] == true &&
                    (data['missing'] as List).isEmpty)
                  const Text(
                    'No tienes datos pendientes según las reglas vigentes.',
                  ),
                Text(
                  data['rewardEnabled'] == true
                      ? ((data['rewards'] as List).isNotEmpty
                            ? 'Beneficio asignado; revisa tus beneficios.'
                            : 'Recompensa sujeta a las condiciones de la campaña vigente.')
                      : 'Recompensa desactivada hasta definir la campaña.',
                ),
              ],
            ),
          ),
    ),
  );
}
