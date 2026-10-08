import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/data/campus_map_data.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/data/campus_map_features.dart';
import 'package:final_project/models/facility.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new coordinate pins have stable IDs, selectable centers and no invented footprint',
    () {
      const facility = Facility(
        id: 'new-building-id',
        name: 'Research Center',
        category: 'Buildings',
        location: 'Campus',
        description: 'Research',
        hours: '8:00 AM – 5:00 PM',
        floors: null,
        icon: Icons.apartment,
        latitude: 15.1325,
        longitude: 120.5901,
      );
      final features =
          campusFacilityFeatures([facility], {}, facility)['features'] as List;
      expect(features.single['id'], 'new-building-id');
      expect(features.single['geometry']['coordinates'], [120.5901, 15.1325]);
      expect(features.single['properties']['selected'], true);
      expect(campusFacilityLocation(facility, {})!.center.latitude, 15.1325);
      expect(
        campusFacilityOutlines([facility], {}, facility)['features'],
        isEmpty,
      );
    },
  );

  test(
    'facility footprints are closed longitude-first polygons with selection',
    () async {
      final locations = await loadCampusMapLocations();
      final selected = mockFacilities.firstWhere(
        (f) => locations.containsKey(f.name),
      );
      final collection = campusFacilityOutlines(
        mockFacilities,
        locations,
        selected,
      );
      final features = collection['features'] as List;
      expect(features.length, locations.length);
      for (final feature in features) {
        final location = locations[feature['properties']['name']]!;
        final ring = feature['geometry']['coordinates'][0] as List;
        expect(feature['geometry']['type'], 'Polygon');
        expect(ring.first, ring.last);
        expect(ring.first, [
          location.outline.first.longitude,
          location.outline.first.latitude,
        ]);
        expect(feature['id'], location.osmWayId);
        expect(
          feature['properties']['selected'],
          location.name == selected.name,
        );
      }
      final filtered = campusFacilityOutlines([selected], locations, selected);
      expect(filtered['features'], hasLength(1));
    },
  );

  test(
    'OSM outlines match directory names and stay within the HAU campus',
    () async {
      final locations = await loadCampusMapLocations();
      final names = mockFacilities.map((facility) => facility.name).toSet();
      expect(locations.length, 17);
      for (final location in locations.values) {
        expect(names, contains(location.name));
        expect(location.outline.length, greaterThanOrEqualTo(4));
        expect(location.outline.first, location.outline.last);
        for (final point in location.outline) {
          expect(point.latitude, inInclusiveRange(15.130, 15.135));
          expect(point.longitude, inInclusiveRange(120.588, 120.592));
        }
      }
      expect(names.difference(locations.keys.toSet()).length, 5);
    },
  );
}
