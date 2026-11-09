import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/core/network/authenticated_api_client.dart';
import 'package:jampic/core/widgets/widgets.dart';
import 'package:jampic/modules/clinical_records/infrastructure/api/api_clinical_records_repository.dart';
import 'package:jampic/modules/family/presentation/create_dependent_screen.dart';
import 'package:jampic/modules/guidance/infrastructure/api_guidance_repository.dart';

class _RequestCapture extends Fake implements AuthenticatedApiClient {
  final requests = <RequestOptions>[];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final request = RequestOptions(path: path, data: data);
    requests.add(request);
    return Response<T>(
      requestOptions: request,
      data:
          <String, dynamic>{'meetingUrl': 'https://meet.google.com/synthetic'}
              as T,
    );
  }
}

void main() {
  test(
    'Joining a support call supplies the JSON body required by Fastify',
    () async {
      final client = _RequestCapture();
      final url = await ApiGuidanceRepository(client).join('synthetic-call');
      expect(url, 'https://meet.google.com/synthetic');
      expect(
        client.requests.single.path,
        'guidance/support-calls/synthetic-call/join',
      );
      expect(client.requests.single.data, <String, dynamic>{});
    },
  );
  test(
    'Completion supplies a JSON object for own and authorized patient paths',
    () async {
      final client = _RequestCapture();
      final repository = ApiClinicalRecordsRepository(client);
      await repository.completion();
      await repository.completion(patientId: 'synthetic-patient');
      expect(client.requests.map((r) => r.path), [
        'clinical-records/completion',
        'clinical-records/patients/synthetic-patient/completion',
      ]);
      for (final request in client.requests) {
        expect(request.data, isA<Map<String, dynamic>>());
        expect(request.data, isEmpty);
      }
    },
  );

  for (final width in [390.0, 1200.0]) {
    testWidgets('Dependent registration adapts field columns at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CreateDependentScreen())),
      );
      final fields = find.byType(AppTextField);
      final first = tester.getRect(fields.at(0));
      final last = tester.getRect(fields.at(1));
      if (width >= 600) {
        expect(first.top, last.top);
        expect(first.right, lessThan(last.left));
      } else {
        expect(first.left, last.left);
        expect(first.bottom, lessThan(last.top));
      }
      expect(fields, findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });
  }
}
