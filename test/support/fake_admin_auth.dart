import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_project/services/admin_access.dart';

void installFakeAdminAuth() {
  AdminAccess.client = MockClient((request) async {
    if (request.url.path.endsWith('/logout')) return http.Response('{}', 200);
    final data = jsonDecode(request.body);
    if (data['username'] != 'test-admin' ||
        data['password'] != 'test-admin-password') {
      return http.Response('{}', 401);
    }
    return http.Response(
      jsonEncode({
        'token': List.filled(43, 't').join(),
        'role': 'admin',
        'username': 'test-admin',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 2))
            .toIso8601String(),
      }),
      200,
    );
  });
}

Future<bool> signInTestAdmin() =>
    AdminAccess.signIn('test-admin', 'test-admin-password');
