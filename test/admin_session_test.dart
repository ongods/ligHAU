import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_project/services/admin_access.dart';

void main() {
  tearDown(AdminAccess.signOut);
  test(
    'credentials are verified by the backend and logout sends only a session token',
    () async {
      var loggedOut = false;
      AdminAccess.client = MockClient((request) async {
        if (request.url.path.endsWith('/logout')) {
          expect(
            request.headers['Authorization'],
            'Bearer ${List.filled(43, 'x').join()}',
          );
          expect(request.body, isEmpty);
          loggedOut = true;
          return http.Response('{}', 200);
        }
        expect(jsonDecode(request.body)['username'], 'individual-admin');
        return http.Response(
          jsonEncode({
            'role': 'admin',
            'token': List.filled(43, 'x').join(),
            'expiresAt': DateTime.now()
                .add(const Duration(hours: 2))
                .toIso8601String(),
          }),
          200,
        );
      });
      expect(AdminAccess.isAuthenticated, false);
      expect(
        await AdminAccess.signIn(
          'individual-admin',
          'a-unique-private-password',
        ),
        true,
      );
      expect(AdminAccess.isAuthenticated, true);
      AdminAccess.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(loggedOut, true);
      expect(AdminAccess.authorizationHeader, isNull);
    },
  );
  test(
    'expired, non-admin and rejected logins cannot create local access',
    () async {
      for (final role in ['admin', 'viewer']) {
        AdminAccess.client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'role': role,
              'token': List.filled(43, 'x').join(),
              'expiresAt': DateTime.now()
                  .subtract(const Duration(seconds: 1))
                  .toIso8601String(),
            }),
            200,
          ),
        );
        await expectLater(
          AdminAccess.signIn('admin', 'admin'),
          throwsA(isA<AdminSignInException>()),
        );
        expect(AdminAccess.isAuthenticated, false);
      }
      AdminAccess.client = MockClient((_) async => http.Response('{}', 401));
      expect(await AdminAccess.signIn('admin', 'admin'), false);
    },
  );
}
