import 'support/fake_admin_auth.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_project/screens/api_usage_screen.dart';
import 'package:final_project/screens/admin_login_screen.dart';
import 'package:final_project/services/admin_access.dart';
import 'package:final_project/services/api_usage_service.dart';
import 'package:final_project/theme/app_theme.dart';

Map<String, dynamic> snapshot() => {
  'updatedAt': '2026-10-06T08:00:00Z',
  'gemini': {
    'model': 'gemini-test',
    'configured': true,
    'since': '2026-10-01',
    'day': '2026-10-06',
    'persistent': true,
    'today': {
      'requests': 5,
      'successes': 3,
      'failures': 2,
      'rateLimited': 1,
      'inputTokens': 100,
      'outputTokens': 20,
      'totalTokens': 130,
      'missingTokenReports': 1,
    },
    'total': {'requests': 15, 'totalTokens': 400},
    'minute': {'requests': 1, 'inputTokens': 30},
    'limits': {'rpm': 10, 'tpm': null, 'rpd': 100},
    'appLimit': {'used': 5, 'limit': 30, 'active': 0, 'concurrency': 2},
  },
  'maptiler': {
    'status': 'not_configured',
    'limits': {'requests': null, 'sessions': null},
  },
};

void main() {
  setUp(installFakeAdminAuth);
  setUp(() => signInTestAdmin());
  tearDown(AdminAccess.signOut);

  test(
    'service refuses unsigned requests and sanitizes server errors',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('secret-provider-error', 500);
      });
      final service = ApiUsageService(client: client);
      addTearDown(service.close);
      AdminAccess.signOut();
      await expectLater(service.load(), throwsA(isA<ApiUsageException>()));
      expect(calls, 0);
      await signInTestAdmin();
      await expectLater(
        service.load(),
        throwsA(
          isA<ApiUsageException>().having(
            (e) => e.message,
            'safe error',
            isNot(contains('secret')),
          ),
        ),
      );
    },
  );

  testWidgets('usage screen requires an admin session', (tester) async {
    AdminAccess.signOut();
    await tester.pumpWidget(const MaterialApp(home: ApiUsageScreen()));
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.text('Gemini · Campus chatbot'), findsNothing);
  });

  testWidgets(
    'usage and quotas display on narrow screens and refresh fetches fresh counts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final service = ApiUsageService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/admin/usage');
          expect(request.headers['Authorization'], startsWith('Bearer '));
          calls++;
          return http.Response(jsonEncode(snapshot()), 200);
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ApiUsageScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Successful answers'), findsOneWidget);
      expect(find.text('1 / 10 used · 9 remaining (estimate)'), findsOneWidget);
      expect(find.text('30 observed · Quota unavailable'), findsOneWidget);
      await tester.ensureVisible(find.text('Token breakdown & history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Token breakdown & history'));
      await tester.pumpAndSettle();
      expect(find.text('Input tokens'), findsOneWidget);
      expect(find.text('Usage history'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('App safety limit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App safety limit'));
      await tester.pumpAndSettle();
      expect(find.text('Requests running'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('MapTiler · Campus map'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Refresh API usage'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Input tokens'), findsOneWidget);
      await tester.ensureVisible(find.text('Token breakdown & history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Token breakdown & history'));
      await tester.pumpAndSettle();
      expect(find.text('Input tokens'), findsNothing);
    },
  );

  testWidgets('unavailable backend offers retry and recovers', (tester) async {
    var calls = 0;
    final service = ApiUsageService(
      client: MockClient(
        (_) async => ++calls == 1
            ? http.Response('{}', 404)
            : http.Response(jsonEncode(snapshot()), 200),
      ),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ApiUsageScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Restart the chat backend to enable API usage monitoring.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Gemini · Campus chatbot'), findsOneWidget);
    expect(calls, 2);
  });
}
