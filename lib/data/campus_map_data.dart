import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class CampusMapLocation {
  final String name;
  final int osmWayId;
  final List<LatLng> outline;

  const CampusMapLocation({
    required this.name,
    required this.osmWayId,
    required this.outline,
  });

  // Bounding-box midpoint of the OSM outline; not a surveyed entrance.
  LatLng get center {
    final latitudes = outline.map((p) => p.latitude).toList()..sort();
    final longitudes = outline.map((p) => p.longitude).toList()..sort();
    return LatLng(
      (latitudes.first + latitudes.last) / 2,
      (longitudes.first + longitudes.last) / 2,
    );
  }
}

Future<Map<String, CampusMapLocation>> loadCampusMapLocations() async {
  final raw = await rootBundle.loadString('assets/data/hau_osm.json');
  final data =
      jsonDecode(raw.replaceFirst('\uFEFF', '')) as Map<String, dynamic>;
  return {
    for (final item in data['facilities'] as List<dynamic>)
      item['name'] as String: CampusMapLocation(
        name: item['name'] as String,
        osmWayId: item['osmWayId'] as int,
        outline: [
          for (final point in item['outline'] as List<dynamic>)
            LatLng((point[0] as num).toDouble(), (point[1] as num).toDouble()),
        ],
      ),
  };
}
