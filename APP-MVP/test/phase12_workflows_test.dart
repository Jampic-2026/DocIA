import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/modules/human_resources/application/human_resources_controller.dart';
import 'package:jampic/modules/human_resources/domain/human_resources_repository.dart';
import 'package:jampic/modules/human_resources/presentation/verification_selection_dialog.dart';
import 'package:jampic/modules/clinical_records/application/clinical_records_controller.dart';
import 'package:jampic/modules/clinical_records/domain/clinical_records_repository.dart';
import 'package:jampic/modules/clinical_records/domain/vital_sign_record.dart';
import 'package:jampic/modules/clinical_records/presentation/professional_vitals_screen.dart';

class _VitalsRepository extends Fake implements ClinicalRecordsRepository {
  int calls = 0;
  String? emergency;
  @override
  Future<VitalSignRecord> createProfessionalVitalSign(
    String patientId,
    CreateVitalSignCommand command, {
    String? appointmentId,
    String? emergencyId,
  }) async {
    calls++;
    emergency = emergencyId;
    return VitalSignRecord(
      id: 'synthetic',
      source: 'professional',
      recordedAt: DateTime.utc(2026, 10, 10),
    );
  }
}

void main() {
  testWidgets(
    'New approvals remain blocked before document requirements are configured',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRequirementsProvider.overrideWith((ref) async => []),
            verificationSpecialtiesProvider.overrideWith(
              (ref) async => [
                const VerificationSpecialty(
                  'synthetic-specialty',
                  'Especialidad de prueba',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      selectVerification(context, fixedRole: 'nurse'),
                  child: const Text('Revisar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Requisitos sin definir: configura el rol antes de aprobar.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Aprobar'))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'Configured nursing requirements allow submitting an approval decision',
    (tester) async {
      VerificationSelection? selection;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRequirementsProvider.overrideWith(
              (ref) async => [
                const DocumentRequirements('nurse', ['Documento de prueba']),
              ],
            ),
            verificationSpecialtiesProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selection = await selectVerification(
                      context,
                      fixedRole: 'nurse',
                    );
                  },
                  child: const Text('Revisar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Aprobar'));
      await tester.pumpAndSettle();
      expect(selection?.roleCode, 'nurse');
      expect(selection?.specialtyId, isNull);
    },
  );
  testWidgets(
    'Professional vital signs require complete values and retain the care context',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _VitalsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clinicalRecordsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: ProfessionalVitalsScreen(
              patientId: 'synthetic-patient',
              emergencyId: 'synthetic-emergency',
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      final fields = find.byType(TextFormField);
      for (final entry in [
        '120',
        '80',
        '70',
        '36.5',
        '98',
        '',
      ].asMap().entries) {
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Registrar'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(repository.emergency, 'synthetic-emergency');
    },
  );
}
