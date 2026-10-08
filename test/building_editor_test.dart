import 'support/fake_admin_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/screens/admin_dashboard_screen.dart';
import 'package:final_project/screens/building_info_screen.dart';
import 'package:final_project/services/admin_access.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/building_editor_dialog.dart';
import 'support/fake_facility_repository.dart';

Finder field(String name) => find.byKey(ValueKey('building-$name'));

Future<void> fill(WidgetTester tester, String name, String value) async {
  await tester.ensureVisible(field(name));
  await tester.pumpAndSettle();
  await tester.enterText(field(name), value);
  await tester.pumpAndSettle();
}

Future<void> dashboard(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const AdminDashboardScreen()),
  );
}

void main() {
  setUp(installFakeAdminAuth);
  setUp(() async {
    await signInTestAdmin();
    installFakeCatalog();
  });
  tearDown(AdminAccess.signOut);

  test('hours preserve midnight, noon, minutes and overnight schedules', () {
    expect(formatCampusTime(const TimeOfDay(hour: 0, minute: 5)), '12:05 AM');
    expect(formatCampusTime(const TimeOfDay(hour: 12, minute: 0)), '12:00 PM');
    final parsed = parseOperatingHours('9:15 PM – 2:30 AM (next day)')!;
    expect(parsed.opening, const TimeOfDay(hour: 21, minute: 15));
    expect(parsed.closing, const TimeOfDay(hour: 2, minute: 30));
    expect(
      formatOperatingHours(parsed.opening, parsed.closing),
      '9:15 PM – 2:30 AM (next day)',
    );
    expect(parseOperatingHours('7:65 AM – 8:00 PM'), isNull);
  });

  testWidgets('add saves all detail fields and standard time-picker input', (
    tester,
  ) async {
    await dashboard(tester);
    await tester.tap(find.byTooltip('Add building'));
    await tester.pumpAndSettle();
    await fill(tester, 'name', 'Research Building');
    await fill(tester, 'location', 'Near the main gate');
    await fill(tester, 'latitude', '15.1325');
    await fill(tester, 'longitude', '120.5901');
    await fill(tester, 'description', 'A place for campus research.');
    await fill(tester, 'facilities', 'Laboratory\nStudent lounge\nLaboratory');
    await fill(tester, 'floors', '2');
    await tester.ensureVisible(field('closing-time'));
    await tester.pumpAndSettle();
    await tester.tap(field('closing-time'));
    await tester.pumpAndSettle();
    final pickerFields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(pickerFields.at(0), '09');
    await tester.enterText(pickerFields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Research Building'));
    await tester.tap(find.text('Research Building'));
    await tester.pumpAndSettle();
    final facility = tester
        .widget<BuildingInfoScreen>(find.byType(BuildingInfoScreen))
        .facility;
    expect(facility.description, 'A place for campus research.');
    expect(facility.location, 'Near the main gate');
    expect(facility.latitude, 15.1325);
    expect(facility.longitude, 120.5901);
    expect(facility.facilities, ['Laboratory', 'Student lounge']);
    expect(facility.floors, 2);
    expect(facility.hours, '7:00 AM – 9:30 PM');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edit pre-fills details and updates the actual dashboard record',
    (tester) async {
      await dashboard(tester);
      final original = mockFacilities.first;
      await tester.ensureVisible(find.byTooltip('Edit ${original.name}'));
      await tester.tap(find.byTooltip('Edit ${original.name}'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('description')).controller!.text,
        original.description,
      );
      expect(
        tester.widget<TextFormField>(field('facilities')).controller!.text,
        original.facilities.join('\n'),
      );
      await fill(tester, 'description', 'Updated place description.');
      await fill(tester, 'facilities', 'Reception\nDormitory');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(original.name));
      await tester.tap(find.text(original.name));
      await tester.pumpAndSettle();
      final facility = tester
          .widget<BuildingInfoScreen>(find.byType(BuildingInfoScreen))
          .facility;
      expect(facility.description, 'Updated place description.');
      expect(facility.facilities, ['Reception', 'Dormitory']);
      expect(facility.hours, original.hours);
      expect(facility.floors, isNull);
      expect(facility.icon, original.icon);
    },
  );

  testWidgets(
    'required fields prevent empty records and Cancel keeps the list intact',
    (tester) async {
      await dashboard(tester);
      final before = find.byType(ListTile).evaluate().length;
      await tester.tap(find.byTooltip('Add building'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.byType(BuildingEditorDialog), findsOneWidget);
      expect(find.text('Enter a building name.'), findsOneWidget);
      expect(find.text('Enter the location.'), findsOneWidget);
      expect(find.text('Describe this place.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, before);
    },
  );

  testWidgets(
    'duplicate names are rejected and edit dialog fits a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await dashboard(tester);
      await tester.ensureVisible(
        find.byTooltip('Edit ${mockFacilities.first.name}'),
      );
      await tester.tap(find.byTooltip('Edit ${mockFacilities.first.name}'));
      await tester.pumpAndSettle();
      await fill(tester, 'name', mockFacilities[1].name);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('A building with this name already exists.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(mockFacilities.first.name), findsOneWidget);
    },
  );
}
