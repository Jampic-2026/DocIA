import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/modules/human_resources/application/human_resources_controller.dart';
import 'package:jampic/modules/human_resources/domain/human_resources_repository.dart';
import 'package:jampic/modules/human_resources/presentation/document_type_picker.dart';
import 'package:jampic/modules/professionals/domain/professional.dart';

void main() {
  testWidgets(
    'Document upload uses the exact requirement configured for the selected role',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRequirementsProvider.overrideWith(
              (ref) async => [
                const DocumentRequirements('nurse', ['Credencial de prueba']),
                const DocumentRequirements('doctor_general', [
                  'Documento de otro rol',
                ]),
              ],
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await selectPersonnelDocumentType(
                      context,
                      ref,
                      roleCode: 'nurse',
                    );
                  },
                  child: const Text('Adjuntar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Adjuntar'));
      await tester.pumpAndSettle();
      expect(find.text('Documento de otro rol'), findsNothing);
      await tester.tap(find.text('Credencial de prueba'));
      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();
      expect(selected, 'Credencial de prueba');
    },
  );

  test(
    'Booking display preserves the Bolivia calendar date across a UTC day boundary',
    () {
      final slot = ProfessionalSlot(
        startAt: DateTime.parse('2026-10-12T03:30:00Z'),
        endAt: DateTime.parse('2026-10-12T04:00:00Z'),
        modality: 'telemedicine',
      );
      expect(slot.localStart.day, 11);
      expect(slot.timeLabel, '23:30');
      expect(slot.endAt.difference(slot.startAt), const Duration(minutes: 30));
      expect(slot.startAt, DateTime.parse('2026-10-11T23:30:00-04:00'));
    },
  );
}
