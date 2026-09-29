import 'package:flutter/material.dart';
import '../models/facility.dart';

const List<String> categories = [
  'All',
  'Buildings',
  'Classrooms',
  'Comfort Rooms',
  'Offices',
  'Parking',
];

const List<Facility> mockFacilities = [
  Facility(
    name: 'San Francisco de Javier Building',
    category: 'Buildings',
    location: 'Near the central campus',
    description:
        'The San Francisco de Javier Building is one of the main academic buildings at Holy Angel University. It houses multiple classrooms, faculty offices, and student facilities across four floors.',
    hours: '7:00 AM – 8:00 PM',
    floors: 4,
    icon: Icons.apartment,
    facilities: ['Classrooms', 'Faculty Offices', 'Comfort Rooms'],
  ),
  Facility(
    name: 'University Library',
    category: 'Buildings',
    location: 'Near the Main Building',
    description:
        'The University Library provides a wide collection of academic resources, study areas, and digital research facilities for students and faculty.',
    hours: '8:00 AM – 7:00 PM',
    floors: 3,
    icon: Icons.local_library,
    facilities: ['Reading Area', 'Computer Lab', 'Study Rooms'],
  ),
  Facility(
    name: 'Chapel',
    category: 'Buildings',
    location: 'Central campus',
    description:
        'The campus chapel serves as a place of worship and reflection for the HAU community. Regular masses and spiritual activities are held here.',
    hours: '6:00 AM – 6:00 PM',
    floors: 1,
    icon: Icons.church,
    facilities: ['Worship Area', 'Confession Room'],
  ),
  Facility(
    name: 'Registrar',
    category: 'Offices',
    location: 'Main Building, Ground Floor',
    description:
        'The Office of the Registrar handles enrollment, academic records, transcript requests, and other student documentation needs.',
    hours: '8:00 AM – 5:00 PM',
    floors: 1,
    icon: Icons.assignment_ind,
    facilities: ['Service Counter', 'Records Section', 'Waiting Area'],
  ),
  Facility(
    name: 'Main Building',
    category: 'Buildings',
    location: 'Central campus entrance',
    description:
        'The Main Building is the central administrative hub of Holy Angel University, housing key offices and departments.',
    hours: '7:00 AM – 7:00 PM',
    floors: 3,
    icon: Icons.business,
    facilities: ['Admin Offices', 'Registrar', 'Comfort Rooms'],
  ),
  Facility(
    name: 'Main Parking Area',
    category: 'Parking',
    location: 'South campus entrance',
    description:
        'The main parking area provides vehicle parking for students, faculty, and visitors with security personnel on duty.',
    hours: 'Open during campus hours',
    floors: 1,
    icon: Icons.local_parking,
    facilities: ['Car Parking', 'Motorcycle Parking', 'Guard Post'],
  ),
  Facility(
    name: 'Comfort Room – Main Building',
    category: 'Comfort Rooms',
    location: 'Main Building, Every Floor',
    description:
        'Comfort rooms are available on every floor of the Main Building for students, faculty, and visitors.',
    hours: '7:00 AM – 7:00 PM',
    floors: 1,
    icon: Icons.wc,
    facilities: ['Male', 'Female', 'PWD Accessible'],
  ),
  Facility(
    name: 'Classroom 201 – SFJ',
    category: 'Classrooms',
    location: 'San Francisco de Javier Building, 2nd Floor',
    description:
        'A standard air-conditioned classroom equipped with a projector and whiteboard, with a capacity of 40 students.',
    hours: '7:00 AM – 8:00 PM',
    floors: 1,
    icon: Icons.meeting_room,
    facilities: ['Projector', 'Whiteboard', 'Air Conditioning'],
  ),
];
