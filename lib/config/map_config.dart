import 'dart:convert';

import 'package:flutter/services.dart';

class MapConfig {
  // Optional public map defines override the generated local map asset.
  static const apiKey = String.fromEnvironment('MAPTILER_KEY');
  static const styleId = String.fromEnvironment(
    'MAPTILER_STYLE_ID',
    defaultValue: 'streets-v4',
  );

  /// Allows plain `flutter run -d chrome` to use local browser-map configuration.
  /// Only public map settings belong in this asset, never the complete .env.
  static Future<({String apiKey, String styleId})> load({
    Future<String> Function(String)? readAsset,
  }) async {
    if (apiKey.isNotEmpty) return (apiKey: apiKey, styleId: styleId);
    try {
      final raw = await (readAsset ?? rootBundle.loadString)(
        'assets/config/map.local.json',
      );
      final config = jsonDecode(raw) as Map<String, dynamic>;
      return (
        apiKey: (config['MAPTILER_KEY'] as String? ?? '').trim(),
        styleId: const bool.hasEnvironment('MAPTILER_STYLE_ID')
            ? styleId
            : config['MAPTILER_STYLE_ID'] as String? ?? styleId,
      );
    } catch (_) {
      return (apiKey: apiKey, styleId: styleId);
    }
  }
}
