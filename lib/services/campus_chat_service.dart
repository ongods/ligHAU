import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/facility_repository.dart';
import '../models/facility.dart';

class CampusChatException implements Exception {
  final String message;
  const CampusChatException(this.message);
  @override
  String toString() => message;
}

class ChatTurn {
  final String role;
  final String text;
  const ChatTurn(this.role, this.text);
  Map<String, String> toJson() => {'role': role, 'text': text};
}

class CampusChatReply {
  final String answer;
  final List<Facility> facilities;
  final Set<String> mapFacilityNames;
  const CampusChatReply(this.answer, this.facilities, this.mapFacilityNames);
}

class CampusChatService {
  final http.Client _client;
  final Uri endpoint;
  CampusChatService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      endpoint = endpoint ?? _defaultEndpoint();

  static Uri _defaultEndpoint() {
    const configured = String.fromEnvironment('CHAT_API_BASE_URL');
    if (configured.isNotEmpty) {
      return Uri.parse(configured).resolve('/api/chat');
    }
    if (kIsWeb && !['localhost', '127.0.0.1', '::1'].contains(Uri.base.host)) {
      return Uri.base.resolve('/api/chat');
    }
    return Uri.parse('http://127.0.0.1:8787/api/chat');
  }

  Future<CampusChatReply> send(String question, List<ChatTurn> history) async {
    if (question.trim().isEmpty || question.length > 2000) {
      throw const CampusChatException(
        'Please enter a question of up to 2000 characters.',
      );
    }
    // Retain complete user/assistant pairs so the provider receives valid history.
    final recent = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': [
                ...recent.map((turn) => turn.toJson()),
                ChatTurn('user', question.trim()).toJson(),
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        // Only render our backend's known public messages, never arbitrary response bodies.
        final message = switch (response.statusCode) {
          429 => _retryMessage(response.headers['retry-after']),
          503 =>
            'The campus assistant is currently unavailable. Please try again later.',
          504 => 'The assistant took too long to respond. Please try again.',
          502 when data['code'] == 'GEMINI_CONNECTION_FAILED' =>
            'The assistant could not connect to its AI service. Please try again.',
          _ =>
            'The assistant could not complete your answer. Please try again.',
        };
        throw CampusChatException(message);
      }
      final answer = data['answer'];
      final names = data['facilityNames'];
      final mapped = data['mapFacilityNames'];
      if (answer is! String ||
          answer.trim().isEmpty ||
          names is! List ||
          mapped is! List) {
        throw const FormatException();
      }
      await FacilityRepository.instance.refresh();
      final facilities = FacilityRepository.instance.value
          .where((facility) => names.contains(facility.name))
          .toList();
      return CampusChatReply(
        answer.trim(),
        facilities,
        facilities
            .where((facility) => mapped.contains(facility.name))
            .map((facility) => facility.name)
            .toSet(),
      );
    } on CampusChatException {
      rethrow;
    } on TimeoutException {
      throw const CampusChatException(
        'The assistant took too long to respond. Please try again.',
      );
    } catch (_) {
      throw const CampusChatException(
        'Cannot reach the campus assistant. Check your connection and that the chat backend is running.',
      );
    }
  }

  void close() => _client.close();
  static String _retryMessage(String? header) {
    final seconds = int.tryParse(header ?? '');
    if (seconds == null || seconds < 1 || seconds > 86400) {
      return 'The assistant is busy or its usage limit was reached. Please try again later.';
    }
    final wait = seconds < 60
        ? '$seconds seconds'
        : '${(seconds / 60).ceil()} minutes';
    return 'The assistant is busy or its usage limit was reached. Try again in $wait.';
  }
}
