import '../models/facility.dart';
import 'campus_map_data.dart';

String campusIconId(Facility facility, {bool selected = false}) =>
    'hau-${facility.icon.codePoint}${selected ? '-selected' : ''}';

String campusPlaceLabel(Facility facility) {
  final acronym = RegExp(
    r'\((SFJ|STL|SGH|SRH|SMH|GGN|PGN|APS|MGN|SJH|SH)\)',
  ).firstMatch(facility.name);
  if (acronym != null) return acronym.group(1)!;
  if (facility.name.contains('DJDN')) return 'Main Building';
  if (facility.name == 'Chapel of the Holy Guardian Angel') return 'Chapel';
  return facility.name
      .replaceAll(' Building', '')
      .replaceAll('Immaculate Heart ', '');
}

Map<String, dynamic> campusFacilityFeatures(
  List<Facility> facilities,
  Map<String, CampusMapLocation> locations,
  Facility? selected,
) => {
  'type': 'FeatureCollection',
  'features': [
    for (final facility in facilities)
      if (locations.containsKey(facility.name))
        {
          'type': 'Feature',
          'id': locations[facility.name]!.osmWayId,
          'geometry': {
            'type': 'Point',
            'coordinates': [
              locations[facility.name]!.center.longitude,
              locations[facility.name]!.center.latitude,
            ],
          },
          'properties': {
            'name': facility.name,
            'label': campusPlaceLabel(facility),
            'icon': campusIconId(facility, selected: facility == selected),
            'selected': facility == selected,
          },
        },
  ],
};

/// Verified facility footprints, separate from the point source used for labels.
Map<String, dynamic> campusFacilityOutlines(
  List<Facility> facilities,
  Map<String, CampusMapLocation> locations,
  Facility? selected,
) => {
  'type': 'FeatureCollection',
  'features': [
    for (final facility in facilities)
      if (locations.containsKey(facility.name))
        {
          'type': 'Feature',
          'id': locations[facility.name]!.osmWayId,
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                for (final point in locations[facility.name]!.outline)
                  [point.longitude, point.latitude],
              ],
            ],
          },
          'properties': {
            'name': facility.name,
            'selected': facility == selected,
          },
        },
  ],
};
