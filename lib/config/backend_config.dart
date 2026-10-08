import 'package:flutter/foundation.dart';

/// Resolves backend routes consistently for the chatbot and admin monitoring.
Uri backendEndpoint(String path) {
  const configured = String.fromEnvironment('CHAT_API_BASE_URL');
  if (configured.isNotEmpty) return Uri.parse(configured).resolve(path);
  if (kIsWeb && !['localhost', '127.0.0.1', '::1'].contains(Uri.base.host)) {
    return Uri.base.resolve(path);
  }
  return Uri.parse('http://127.0.0.1:8787').resolve(path);
}
