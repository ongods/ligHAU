import 'dart:convert';

import 'package:final_project/data/campus_map_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('campus style retains paths, trees, crossings and local labels', () {
    final original = {
      'version': 8,
      'sources': <String, dynamic>{},
      'layers': [
        for (final source in [
          'tree',
          'street_furniture',
          'poi_food',
          'road',
          'pathway',
        ])
          {
            'id': '$source-label',
            'type': 'symbol',
            'source-layer': source,
            'layout': {'visibility': 'visible'},
            'paint': {'text-color': '#000000'},
          },
        {
          'id': 'Steps',
          'type': 'line',
          'source-layer': 'pathway',
          'paint': {
            'line-color': '#BBAA99',
            'line-dasharray': [1, 2],
          },
        },
      ],
    };
    final style = customizeCampusStyle(original);
    final layers = style['layers'] as List;
    for (final layer in layers.where((layer) => layer['type'] == 'symbol')) {
      expect(layer['layout']['visibility'], 'visible');
    }
    expect(layers.last['paint'], (original['layers'] as List).last['paint']);
  });
  test('missing key fails before making a request', () async {
    final client = MockClient((_) async {
      fail('A missing key must not make a network request.');
    });
    await expectLater(
      loadCampusMapStyle(apiKey: '', client: client),
      throwsA(
        isA<MapStyleException>().having(
          (error) => error.message,
          'message',
          contains('not been configured'),
        ),
      ),
    );
  });

  for (final status in [401, 403, 404, 429]) {
    test(
      'HTTP $status explains the failure without exposing the key',
      () async {
        final client = MockClient((_) async => http.Response('', status));
        final expectedMessage = switch (status) {
          401 || 403 => 'access was denied',
          404 => 'not found',
          _ => 'request limit',
        };
        await expectLater(
          loadCampusMapStyle(apiKey: 'private-test-key', client: client),
          throwsA(
            isA<MapStyleException>()
                .having(
                  (error) => error.message,
                  'message',
                  contains(expectedMessage),
                )
                .having(
                  (error) => error.toString(),
                  'safe error',
                  isNot(contains('private-test-key')),
                ),
          ),
        );
      },
    );
  }

  test(
    'default style is tuned while provider resources are preserved',
    () async {
      final original = {
        'version': 8,
        'sources': {
          'basemap': {'type': 'vector', 'url': 'https://example.com/tiles'},
        },
        'glyphs': 'https://example.com/{fontstack}/{range}.pbf',
        'sprite': 'https://example.com/sprite',
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': '#FFF'},
          },
        ],
      };
      final client = MockClient((request) async {
        expect(request.url.path, '/maps/streets-v4/style.json');
        expect(request.url.queryParameters['key'], 'test-key');
        return http.Response(jsonEncode(original), 200);
      });
      final result = jsonDecode(
        await loadCampusMapStyle(apiKey: 'test-key', client: client),
      );
      expect(result['sources'], original['sources']);
      expect(result['glyphs'], original['glyphs']);
      expect(result['sprite'], original['sprite']);
      expect(result['layers'][0]['paint']['background-color'], '#F8F7F3');
    },
  );

  test('network failures redact provider URLs and keys', () async {
    final client = MockClient((request) async {
      throw http.ClientException('Could not load $request');
    });
    await expectLater(
      loadCampusMapStyle(apiKey: 'private-test-key', client: client),
      throwsA(
        isA<MapStyleException>().having(
          (error) => error.toString(),
          'safe error',
          isNot(contains('private-test-key')),
        ),
      ),
    );
  });
}
