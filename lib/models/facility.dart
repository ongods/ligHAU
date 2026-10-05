import 'package:flutter/material.dart';

class Facility {
  final String name;
  final String category;
  final String location;
  final String description;
  final String hours;
  final int? floors;
  final IconData icon;
  final List<String> facilities;

  const Facility({
    required this.name,
    required this.category,
    required this.location,
    required this.description,
    required this.hours,
    required this.floors,
    required this.icon,
    this.facilities = const [],
  });
}
