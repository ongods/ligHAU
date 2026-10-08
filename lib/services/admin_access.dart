import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

class AdminSignInException implements Exception {
  final String message;
  const AdminSignInException(this.message);
}

/// The server verifies accounts and permissions; passwords are never stored here.
class AdminAccess {
  static http.Client client = http.Client();
  static String? _token;
  static DateTime? _expires;
  static bool get isAuthenticated =>
      _token != null && (_expires?.isAfter(DateTime.now()) ?? false);
  static String? get authorizationHeader =>
      isAuthenticated ? 'Bearer $_token' : null;

  static Future<bool> signIn(String username, String password) async {
    _token = null;
    _expires = null;
    try {
      final response = await client
          .post(
            backendEndpoint('/api/admin/login'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) return false;
      if (response.statusCode == 429) {
        throw const AdminSignInException(
          'Too many sign-in attempts. Please wait before trying again.',
        );
      }
      if (response.statusCode != 200) throw const FormatException();
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final expires = DateTime.parse(data['expiresAt'] as String);
      if (data['role'] != 'admin' ||
          data['token'] is! String ||
          (data['token'] as String).length != 43 ||
          !expires.isAfter(DateTime.now())) {
        throw const FormatException();
      }
      _token = data['token'] as String;
      _expires = expires;
      return true;
    } on AdminSignInException {
      rethrow;
    } catch (_) {
      throw const AdminSignInException(
        'Cannot sign in. Check your connection and that the backend is running.',
      );
    }
  }

  static void signOut() {
    final auth = authorizationHeader;
    _token = null;
    _expires = null;
    if (auth != null) {
      unawaited(
        client
            .post(
              backendEndpoint('/api/admin/logout'),
              headers: {'Authorization': auth},
            )
            .timeout(const Duration(seconds: 5))
            .then<void>((_) {}, onError: (_) {}),
      );
    }
  }
}
