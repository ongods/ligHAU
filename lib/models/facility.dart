import 'package:flutter/material.dart';

class Facility {
  final String? id;
  final int version;
  final String? sourceName;
  final double? latitude;
  final double? longitude;
  bool get hasCoordinates => latitude != null && longitude != null;
  String get mapName => sourceName ?? (id == null ? name : '');
  final String name;
  final String category;
  final String location;
  final String description;
  final String hours;
  final int? floors;
  final IconData icon;
  final List<String> facilities;

  const Facility({
    this.id,
    this.version = 0,
    this.sourceName,
    this.latitude,
    this.longitude,
    required this.name,
    required this.category,
    required this.location,
    required this.description,
    required this.hours,
    required this.floors,
    required this.icon,
    this.facilities = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'sourceName': sourceName,
    'latitude': latitude,
    'longitude': longitude,
    'name': name,
    'category': category,
    'location': location,
    'description': description,
    'hours': hours,
    'floors': floors,
    'facilities': facilities,
  };
}
