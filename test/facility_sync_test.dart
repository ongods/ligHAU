import 'support/fake_admin_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_project/services/facility_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/data/campus_map_data.dart';
import 'package:final_project/data/campus_map_features.dart';
import 'package:final_project/models/facility.dart';
import 'package:final_project/screens/building_info_screen.dart';
import 'package:final_project/screens/search_screen.dart';
import 'package:final_project/services/admin_access.dart';
import 'support/fake_facility_repository.dart';

void main() {
  setUp(installFakeAdminAuth);
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => signInTestAdmin());
  tearDown(AdminAccess.signOut);
  final original = mockFacilities.firstWhere((f) => f.name.contains('DJDN'));
  Facility updated() => Facility(
    name: 'Updated main building',
    category: original.category,
    location: original.location,
    description: 'Updated shared description',
    hours: '8:00 AM – 6:00 PM',
    floors: original.floors,
    icon: original.icon,
    facilities: const ['Updated campus service'],
  );

  test(
    'a conflicting save refreshes the latest version and asks for review',
    () async {
      var version = 1;
      final repository = FacilityRepository(
        pollInterval: null,
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            expect(jsonDecode(request.body)['version'], 1);
            version = 2;
            return http.Response('{}', 412);
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'facilities': [
                  {
                    ...original.toJson(),
                    'id': 'shared-id',
                    'sourceName': original.name,
                    'version': version,
                  },
                ],
              }),
            ),
            200,
          );
        }),
      );
      await repository.refresh();
      final captured = repository.value.first;
      await expectLater(
        repository.save(updated(), previous: captured),
        throwsA(
          isA<FacilitySaveException>().having(
            (e) => e.message,
            'review guidance',
            contains('review your changes'),
          ),
        ),
      );
      expect(repository.value.first.version, 2);
      repository.dispose();
    },
  );

  test(
    'saved catalog refresh keeps renamed building map geometry and icons',
    () async {
      final repository = installFakeCatalog();
      await repository.refresh();
      try {
        await repository.save(updated(), previous: original);
      } on Object catch (error) {
        fail('Catalog save failed: $error');
      }
      await repository.refresh();
      final saved = repository.current(original)!;
      expect(saved.name, 'Updated main building');
      expect(saved.icon, original.icon);
      final locations = await loadCampusMapLocations();
      final features =
          campusFacilityFeatures([saved], locations, saved)['features'] as List;
      expect(features, hasLength(1));
      expect(features.single['id'], locations[original.name]!.osmWayId);
      expect(features.single['properties']['name'], saved.name);
    },
  );

  testWidgets('directory and existing details show the saved admin update', (
    tester,
  ) async {
    final repository = installFakeCatalog();
    await repository.refresh();
    await repository.save(updated(), previous: original);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated campus service');
    await tester.pumpAndSettle();
    expect(find.text('Updated main building'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: BuildingInfoScreen(facility: original)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Updated shared description'), findsOneWidget);
    expect(find.text('Updated main building'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
