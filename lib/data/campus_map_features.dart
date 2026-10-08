import '../models/facility.dart';
import 'package:latlong2/latlong.dart';
import 'campus_map_data.dart';

CampusMapLocation? campusFacilityLocation(
  Facility facility,
  Map<String, CampusMapLocation> locations,
) {
  final original = locations[facility.mapName];
  if (!facility.hasCoordinates) return original;
  return CampusMapLocation(
    name: facility.name,
    osmWayId: original?.osmWayId ?? -1,
    outline: original?.outline ?? const [],
    marker: LatLng(facility.latitude!, facility.longitude!),
  );
}

Object campusFacilityFeatureId(Facility facility, CampusMapLocation location) =>
    location.osmWayId != -1
    ? location.osmWayId
    : facility.id ?? 'pin-${facility.name}';

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
      if (campusFacilityLocation(facility, locations) case final location?)
        {
          'type': 'Feature',
          'id': campusFacilityFeatureId(facility, location),
          'geometry': {
            'type': 'Point',
            'coordinates': [
              location.center.longitude,
              location.center.latitude,
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
      if (locations.containsKey(facility.mapName))
        {
          'type': 'Feature',
          'id': locations[facility.mapName]!.osmWayId,
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                for (final point in locations[facility.mapName]!.outline)
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
