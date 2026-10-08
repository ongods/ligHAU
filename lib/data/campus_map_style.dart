import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/map_config.dart';

class MapStyleException implements Exception {
  const MapStyleException([
    this.message = 'Check your connection and try again.',
  ]);
  final String message;
  // Request URLs can contain the key. Never surface the original exception.
  @override
  String toString() => message;
}

Future<String> loadCampusMapStyle({
  String? apiKey,
  String? styleId,
  http.Client? client,
}) async {
  if (apiKey == null) {
    final config = await MapConfig.load();
    apiKey = config.apiKey;
    styleId ??= config.styleId;
  }
  styleId ??= MapConfig.styleId;
  if (apiKey.trim().isEmpty) {
    throw const MapStyleException(
      'The campus map has not been configured yet.',
    );
  }
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(styleId)) {
    throw const MapStyleException('The configured map style is invalid.');
  }
  final mapClient = client ?? http.Client();
  try {
    final response = await mapClient
        .get(
          Uri.https('api.maptiler.com', '/maps/$styleId/style.json', {
            'key': apiKey,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const MapStyleException(
        'Map access was denied. Check the MapTiler key and allowed origins.',
      );
    }
    if (response.statusCode == 404) {
      throw const MapStyleException('The configured map style was not found.');
    }
    if (response.statusCode == 429) {
      throw const MapStyleException(
        'The map request limit was reached. Please try again later.',
      );
    }
    if (response.statusCode != 200) throw const MapStyleException();
    final style = jsonDecode(response.body) as Map<String, dynamic>;
    if (style['version'] != 8 ||
        style['layers'] is! List ||
        style['sources'] is! Map) {
      throw const MapStyleException();
    }
    // Preserve an explicitly chosen custom style; tune the default Streets map.
    return jsonEncode(
      styleId == 'streets-v4' ? customizeCampusStyle(style) : style,
    );
  } on MapStyleException {
    rethrow;
  } catch (_) {
    throw const MapStyleException();
  } finally {
    if (client == null) mapClient.close();
  }
}

/// Customize rendering, preserving data sources, glyphs, sprites and attribution.
Map<String, dynamic> customizeCampusStyle(Map<String, dynamic> original) {
  final style = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
  const greenery = {
    'vegetation',
    'wood',
    'forest',
    'grass',
    'cemetery',
    'leisure',
  };
  const neutralLand = {
    'residential',
    'education',
    'hospital',
    'industrial',
    'commercial',
    'parking',
    'construction',
  };
  for (final value in style['layers'] as List) {
    final layer = value as Map<String, dynamic>;
    final type = layer['type'];
    final source = (layer['source-layer'] as String?) ?? '';
    final id = (layer['id'] as String).toLowerCase();
    final paint =
        layer.putIfAbsent('paint', () => <String, dynamic>{})
            as Map<String, dynamic>;
    final layout =
        layer.putIfAbsent('layout', () => <String, dynamic>{})
            as Map<String, dynamic>;
    if (type == 'background') paint['background-color'] = '#F8F7F3';
    if (type == 'fill-extrusion') layout['visibility'] = 'none';
    if (type == 'fill') {
      if (source == 'building') {
        paint['fill-color'] = '#DDD5C8';
        paint['fill-outline-color'] = '#B8AD9D';
      } else if (greenery.contains(source)) {
        paint['fill-color'] = '#E3EADB';
      } else if (neutralLand.contains(source)) {
        paint['fill-color'] = source == 'education' ? '#F1ECE2' : '#F3F0E9';
      } else if (source == 'water') {
        paint['fill-color'] = '#D8E8EB';
      } else if (source == 'pedestrian') {
        paint['fill-color'] = '#F8F7F3';
      }
    }
    // Retain the provider's distinct colors and dashes for roads, paths and steps.
    if (type == 'symbol') {
      // Keep local landmarks, trees, crossings and street labels visible.
      if (id.contains('shield')) {
        layout['visibility'] = 'none';
      } else if (paint.containsKey('text-color')) {
        paint['text-color'] = '#7D786E';
        paint['text-halo-color'] = '#F8F7F3';
      }
    }
  }
  return style;
}
