import 'support/fake_admin_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/screens/admin_dashboard_screen.dart';
import 'package:final_project/services/admin_access.dart';
import 'package:final_project/theme/app_theme.dart';
import 'support/fake_facility_repository.dart';

final searchField = find.byKey(const ValueKey('admin-building-search'));

Future<void> search(WidgetTester tester, String value) async {
  await tester.ensureVisible(searchField);
  await tester.pumpAndSettle();
  await tester.enterText(searchField, value);
  await tester.pumpAndSettle();
}

void main() {
  setUp(installFakeAdminAuth);
  final buildings = mockFacilities
      .where((f) => f.category == 'Buildings' || f.category == 'Offices')
      .toList();
  setUp(() async {
    await signInTestAdmin();
    installFakeCatalog();
  });
  tearDown(AdminAccess.signOut);

  testWidgets(
    'search matches services regardless of case, shows empty results, and clears on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const AdminDashboardScreen()),
      );
      final registrar = buildings.firstWhere(
        (b) => b.facilities.any((f) => f.contains('Registrar')),
      );
      await search(tester, '  rEgIsTrAr  ');
      expect(find.text(registrar.name), findsOneWidget);
      expect(find.text(buildings.first.name), findsNothing);
      await search(tester, 'unlisted place xyz');
      expect(find.text('No places found'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(buildings.length));
      expect(find.text('No places found'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing and deleting filtered results affect the original record',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const AdminDashboardScreen()),
      );
      final target = buildings.last;
      await search(tester, target.name);
      await tester.ensureVisible(find.byTooltip('Edit ${target.name}'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit ${target.name}'));
      await tester.pumpAndSettle();
      final description = find.byKey(const ValueKey('building-description'));
      expect(
        tester.widget<TextFormField>(description).controller!.text,
        target.description,
      );
      await tester.ensureVisible(description);
      await tester.enterText(description, 'Updated searchable description');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await search(tester, 'Updated searchable description');
      expect(find.text(target.name), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Delete ${target.name}'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete ${target.name}'));
      await tester.pumpAndSettle();
      expect(find.text('Remove "${target.name}"?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No places found'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text(buildings.first.name), findsOneWidget);
      expect(find.text(target.name), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(buildings.length - 1));
    },
  );
}
