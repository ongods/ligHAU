import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import 'admin_access.dart';

class ApiUsageException implements Exception {
  final String message;
  const ApiUsageException(this.message);
}

class ApiUsageService {
  final http.Client _client;
  final Uri endpoint;
  ApiUsageService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      endpoint = endpoint ?? backendEndpoint('/api/admin/usage');

  Future<Map<String, dynamic>> load() async {
    final auth = AdminAccess.authorizationHeader;
    if (auth == null) {
      throw const ApiUsageException('Sign in as admin to view API usage.');
    }
    try {
      final response = await _client
          .get(endpoint, headers: {'Authorization': auth})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ApiUsageException(
          'Admin access was denied. Sign in again.',
        );
      }
      if (response.statusCode == 404) {
        throw const ApiUsageException(
          'Restart the chat backend to enable API usage monitoring.',
        );
      }
      if (response.statusCode != 200) throw const FormatException();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['gemini'] is! Map || data['maptiler'] is! Map) {
        throw const FormatException();
      }
      return data;
    } on ApiUsageException {
      rethrow;
    } catch (_) {
      throw const ApiUsageException(
        'Cannot load API usage. Check that the chat backend is running, then retry.',
      );
    }
  }

  void close() => _client.close();
}
