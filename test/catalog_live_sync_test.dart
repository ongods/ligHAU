import 'support/fake_admin_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/models/facility.dart';
import 'package:final_project/screens/search_screen.dart';
import 'package:final_project/services/admin_access.dart';
import 'package:final_project/services/facility_repository.dart';

void main() {
  setUp(installFakeAdminAuth);
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> records;
  var offline = false;
  var invalid = false;
  var reads = 0;
  http.Client client() => MockClient((request) async {
    if (request.method == 'GET') {
      reads++;
      if (offline) return http.Response('Unavailable', 503);
      if (invalid) return http.Response('{"facilities": [{}]}', 200);
    } else {
      final fields = jsonDecode(request.body) as Map<String, dynamic>;
      records[0] = {
        ...fields,
        'id': 'shared-place',
        'sourceName': records[0]['sourceName'],
      };
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode({'facilities': records})),
      200,
    );
  });

  setUp(() async {
    offline = false;
    invalid = false;
    reads = 0;
    records = [
      {
        ...mockFacilities.first.toJson(),
        'id': 'shared-place',
        'sourceName': mockFacilities.first.name,
      },
    ];
    await signInTestAdmin();
  });
  tearDown(AdminAccess.signOut);

  testWidgets(
    'another tab picks up saved admin edits by polling without rebuilding unchanged data',
    (tester) async {
      final writer = FacilityRepository(client: client(), pollInterval: null);
      final viewer = FacilityRepository(
        client: client(),
        pollInterval: const Duration(seconds: 10),
      );
      FacilityRepository.instance = viewer;
      await writer.refresh();
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pumpAndSettle();
      final initialValue = viewer.value;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(identical(viewer.value, initialValue), true);
      final original = writer.value.first;
      await writer.save(
        Facility(
          name: 'Live renamed building',
          category: original.category,
          location: original.location,
          description: 'Live description',
          hours: original.hours,
          floors: original.floors,
          icon: original.icon,
          latitude: 15.1325,
          longitude: 120.5901,
        ),
        previous: original,
      );
      expect(find.text('Live renamed building'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Live renamed building'), findsOneWidget);
      expect(viewer.value.first.hasCoordinates, true);
      await tester.pumpWidget(const SizedBox.shrink());
      final stoppedAt = reads;
      await tester.pump(const Duration(seconds: 20));
      expect(reads, stoppedAt);
      writer.dispose();
      viewer.dispose();
    },
  );

  testWidgets(
    'offline sample notice, stale notice and retry recovery are visible',
    (tester) async {
      final repository = FacilityRepository(
        client: client(),
        pollInterval: null,
      );
      FacilityRepository.instance = repository;
      offline = true;
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Showing sample information'), findsOneWidget);
      expect(repository.loaded, false);
      offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.syncStatus, CatalogSyncStatus.current);
      expect(find.text('Retry'), findsNothing);
      final saved = repository.value;
      offline = true;
      await repository.refresh();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Showing previously loaded information'),
        findsOneWidget,
      );
      expect(identical(repository.value, saved), true);
      offline = false;
      invalid = true;
      await repository.refresh();
      await tester.pumpAndSettle();
      expect(repository.syncStatus, CatalogSyncStatus.stale);
      invalid = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.syncStatus, CatalogSyncStatus.current);
      expect(
        find.textContaining('Showing previously loaded information'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      repository.dispose();
    },
  );

  test(
    'a delayed refresh cannot overwrite a more recent successful save',
    () async {
      final delayed = Completer<http.Response>();
      var delayRead = false;
      final repository = FacilityRepository(
        pollInterval: null,
        client: MockClient((request) async {
          if (request.method == 'GET' && delayRead) {
            return delayed.future;
          }
          if (request.method != 'GET') {
            records[0] = {
              ...records[0],
              'description': 'New saved description',
            };
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode({'facilities': records})),
            200,
          );
        }),
      );
      await repository.refresh();
      final oldResponse = http.Response.bytes(
        utf8.encode(jsonEncode({'facilities': records})),
        200,
      );
      delayRead = true;
      final pending = repository.refresh();
      await repository.save(
        repository.value.first,
        previous: repository.value.first,
      );
      delayed.complete(oldResponse);
      await pending;
      expect(repository.value.first.description, 'New saved description');
      repository.dispose();
    },
  );
}
