import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/core/network/authenticated_api_client.dart';
import 'package:jampic/experiences/professional/presentation/professional_schedule_screen.dart';
import 'package:jampic/modules/professional_schedule/application/professional_schedule_controller.dart';
import 'package:jampic/modules/professional_schedule/domain/professional_schedule.dart';
import 'package:jampic/modules/professional_schedule/domain/professional_schedule_repository.dart';
import 'package:jampic/modules/professional_schedule/infrastructure/api/api_professional_schedule_repository.dart';

class _Client extends Fake implements AuthenticatedApiClient {
  final requests = <RequestOptions>[];
  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final request = RequestOptions(path: path, data: data);
    requests.add(request);
    return Response<T>(requestOptions: request);
  }
}

class _Schedule extends Fake implements ProfessionalScheduleRepository {
  bool fail = false, removedSlot = false, removedBlock = false;
  @override
  Future<ProfessionalSchedule> getSchedule() async => ProfessionalSchedule(
    availability: removedSlot
        ? []
        : [
            const AvailabilitySlot(
              id: 'slot',
              weekday: 1,
              startTime: '08:00',
              endTime: '12:00',
              modality: 'in_person',
            ),
          ],
    timeBlocks: removedBlock
        ? []
        : [
            ProfessionalTimeBlock(
              id: 'block',
              startAt: DateTime(2026, 10, 12, 8),
              endAt: DateTime(2026, 10, 12, 9),
              reason: 'Bloqueo de prueba',
            ),
          ],
  );
  @override
  Future<void> removeAvailability(String id) async {
    if (fail) throw Exception('No se pudo eliminar el horario de prueba');
    expect(id, 'slot');
    removedSlot = true;
  }

  @override
  Future<void> removeTimeBlock(String id) async {
    if (fail) throw Exception('No se pudo eliminar el bloqueo de prueba');
    expect(id, 'block');
    removedBlock = true;
  }
}

void main() {
  test('Schedule deletion requests supply a JSON object for Fastify', () async {
    final client = _Client();
    final repository = ApiProfessionalScheduleRepository(client);
    await repository.removeAvailability('slot');
    await repository.removeTimeBlock('block');
    expect(client.requests.map((request) => request.path), [
      'professionals/professional-availability/slot',
      'professionals/professional-time-blocks/block',
    ]);
    for (final request in client.requests) {
      expect(request.data, <String, dynamic>{});
    }
  });
  for (final block in [false, true]) {
    for (final fail in [false, true]) {
      testWidgets(
        'Deleting ${block ? "block" : "availability"} ${fail ? "reports failure" : "refreshes schedule"}',
        (tester) async {
          final repository = _Schedule()..fail = fail;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                professionalScheduleRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const MaterialApp(home: ProfessionalScheduleScreen()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byTooltip(block ? 'Quitar bloqueo' : 'Eliminar horario'),
          );
          await tester.pumpAndSettle();
          if (fail) {
            expect(find.byType(SnackBar), findsOneWidget);
            expect(
              find.textContaining(
                block
                    ? 'No se pudo eliminar el bloqueo'
                    : 'No se pudo eliminar el horario',
              ),
              findsOneWidget,
            );
            expect(
              block ? repository.removedBlock : repository.removedSlot,
              isFalse,
            );
            expect(
              find.byTooltip(block ? 'Quitar bloqueo' : 'Eliminar horario'),
              findsOneWidget,
            );
          } else {
            expect(
              block ? repository.removedBlock : repository.removedSlot,
              isTrue,
            );
            expect(
              find.byTooltip(block ? 'Quitar bloqueo' : 'Eliminar horario'),
              findsNothing,
            );
            expect(
              find.text(
                block
                    ? 'No existen bloqueos próximos.'
                    : 'Todavía no configuraste horarios.',
              ),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
