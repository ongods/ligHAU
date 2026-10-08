import 'dart:convert';

import 'package:final_project/config/map_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain launch loads the local map key and style', () async {
    final config = await MapConfig.load(
      readAsset: (path) async {
        expect(path, 'assets/config/map.local.json');
        return jsonEncode({
          'MAPTILER_KEY': 'local-test-key',
          'MAPTILER_STYLE_ID': 'custom-style',
        });
      },
    );
    expect(config.apiKey, 'local-test-key');
    expect(config.styleId, 'custom-style');
  });

  test('missing local map configuration returns empty key safely', () async {
    final config = await MapConfig.load(
      readAsset: (_) async => throw StateError('missing'),
    );
    expect(config.apiKey, isEmpty);
    expect(config.styleId, 'streets-v4');
  });

  test('invalid local map configuration does not crash startup', () async {
    final config = await MapConfig.load(readAsset: (_) async => 'invalid JSON');
    expect(config.apiKey, isEmpty);
  });
}
