import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/screens/chatbot_screen.dart';
import 'package:final_project/screens/building_info_screen.dart';
import 'package:final_project/services/campus_chat_service.dart';
import 'package:final_project/services/facility_repository.dart';
import 'package:final_project/theme/app_theme.dart';
import 'support/fake_facility_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeCatalog);
  final registrar = mockFacilities.firstWhere(
    (f) => f.facilities.any((s) => s.contains('Registrar')),
  );
  String response() => jsonEncode({
    'answer': 'The Registrar is in the Main Building.',
    'facilityNames': [registrar.name],
    'mapFacilityNames': [registrar.name],
  });

  test(
    'chat actions resolve newly added buildings from the live catalog',
    () async {
      final added = mockFacilities.first.toJson()
        ..['name'] = 'New research office'
        ..['id'] = 'new-research-office'
        ..['version'] = 1
        ..['sourceName'] = null
        ..['latitude'] = 15.1
        ..['longitude'] = 120.5;
      final repository = FacilityRepository(
        pollInterval: null,
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'facilities': [added],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      FacilityRepository.instance = repository;
      addTearDown(repository.dispose);
      final service = CampusChatService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'answer': 'Visit the new research office.',
              'facilityNames': ['New research office'],
              'mapFacilityNames': ['New research office'],
            }),
            200,
          ),
        ),
      );
      addTearDown(service.close);
      final reply = await service.send('Where is the new office?', []);
      expect(repository.loaded, isTrue);
      expect(reply.facilities.single.name, 'New research office');
      expect(reply.mapFacilityNames, {'New research office'});
      expect(reply.facilities.single.id, 'new-research-office');
    },
  );

  test(
    'requests carry recent complete history, and only known facilities become actions',
    () async {
      final service = CampusChatService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['messages'], hasLength(13));
          expect(body['messages'].first['text'], 'question 2');
          expect(body['messages'].last['text'], 'Where is the Registrar?');
          expect(request.body, isNot(contains('GEMINI_API_KEY')));
          return http.Response(
            jsonEncode({
              'answer': 'Main Building',
              'facilityNames': [registrar.name, 'Invented'],
              'mapFacilityNames': [registrar.name, 'Invented'],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final reply = await service.send('Where is the Registrar?', [
        for (var i = 0; i < 8; i++) ...[
          ChatTurn('user', 'question $i'),
          ChatTurn('model', 'answer $i'),
        ],
      ]);
      expect(reply.facilities.map((f) => f.name), [registrar.name]);
      expect(reply.mapFacilityNames, {registrar.name});
    },
  );

  test('backend errors do not surface arbitrary provider output', () async {
    final service = CampusChatService(
      client: MockClient(
        (_) async => http.Response('{"error":"private-key"}', 429),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.send('Where is the library?', []),
      throwsA(
        isA<CampusChatException>().having(
          (e) => e.message,
          'safe message',
          isNot(contains('private-key')),
        ),
      ),
    );
  });

  test('connection failures are not presented as response timeouts', () async {
    for (final entry in [
      (
        status: 502,
        code: 'GEMINI_CONNECTION_FAILED',
        message:
            'The assistant could not connect to its AI service. Please try again.',
      ),
      (
        status: 504,
        code: '',
        message: 'The assistant took too long to respond. Please try again.',
      ),
    ]) {
      final service = CampusChatService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'private-provider-detail',
              'code': entry.code,
            }),
            entry.status,
          ),
        ),
      );
      addTearDown(service.close);
      await expectLater(
        service.send('Library?', []),
        throwsA(
          isA<CampusChatException>().having(
            (e) => e.message,
            'message',
            entry.message,
          ),
        ),
      );
    }
    final service = CampusChatService(
      client: MockClient(
        (_) async => throw TimeoutException('private-network-detail'),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.send('Library?', []),
      throwsA(
        isA<CampusChatException>().having(
          (e) => e.message,
          'message',
          contains('took too long'),
        ),
      ),
    );
  });

  testWidgets(
    'real replies replace mock messages, prevent duplicate sends, and open the matched facility',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final service = CampusChatService(
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChatbotScreen(service: service, canReturnToMap: true),
        ),
      );
      expect(find.text('Where is the Registrar?'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Where is the Registrar?');
      await tester.tap(find.byTooltip('Send question'));
      await tester.pump();
      expect(find.text('Finding an answer…'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.complete(http.Response(response(), 200));
      await tester.pumpAndSettle();
      expect(find.text('Show on Map'), findsOneWidget);
      await tester.ensureVisible(find.text('Open Details'));
      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BuildingInfoScreen>(find.byType(BuildingInfoScreen))
            .facility
            .name,
        registrar.name,
      );
    },
  );

  testWidgets(
    'retry resends a failed question without duplicating its bubble',
    (tester) async {
      var calls = 0;
      final service = CampusChatService(
        client: MockClient(
          (_) async => ++calls == 1
              ? http.Response('{}', 503)
              : http.Response(response(), 200),
        ),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChatbotScreen(service: service),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Where is the Registrar?');
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Where is the Registrar?'), findsOneWidget);
      expect(
        find.text('The Registrar is in the Main Building.'),
        findsOneWidget,
      );
    },
  );
}
