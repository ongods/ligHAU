import 'support/fake_admin_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/screens/admin_dashboard_screen.dart';
import 'package:final_project/screens/admin_login_screen.dart';
import 'package:final_project/screens/api_usage_screen.dart';
import 'package:final_project/screens/login_screen.dart';
import 'package:final_project/screens/map_screen.dart';
import 'package:final_project/services/admin_access.dart';
import 'package:final_project/theme/app_theme.dart';
import 'support/fake_facility_repository.dart';

void main() {
  setUp(installFakeAdminAuth);
  setUp(() async {
    AdminAccess.signOut();
    installFakeCatalog();
  });
  tearDown(AdminAccess.signOut);

  testWidgets('admin entry opens credential form instead of dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );
    await tester.ensureVisible(find.text('Admin Login'));
    await tester.tap(find.text('Admin Login'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.text('Manage Buildings'), findsNothing);
  });

  testWidgets('dashboard cannot open without an admin session', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AdminDashboardScreen()),
    );
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.text('Manage Buildings'), findsNothing);
  });

  testWidgets(
    'API usage button is visible on the dashboard and opens monitoring',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await signInTestAdmin();
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const AdminDashboardScreen()),
      );
      final button = find.widgetWithText(FilledButton, 'API usage & quota');
      expect(button.hitTestable(), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(ApiUsageScreen), findsOneWidget);
      expect(find.byTooltip('Refresh API usage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty and incorrect credentials cannot open dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AdminLoginScreen()),
    );
    await tester.tap(find.text('Sign in as admin'));
    await tester.pump();
    expect(find.text('Enter your admin username.'), findsOneWidget);
    expect(find.text('Enter your admin password.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.text('Sign in as admin'));
    await tester.pump();
    expect(find.text('Incorrect admin username or password.'), findsOneWidget);
    expect(AdminAccess.isAuthenticated, isFalse);
    expect(find.text('Manage Buildings'), findsNothing);
  });

  testWidgets(
    'valid login enters dashboard and sign-out clears access and history',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      );
      await tester.ensureVisible(find.text('Admin Login'));
      await tester.tap(find.text('Admin Login'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'test-admin');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test-admin-password',
      );
      await tester.tap(find.text('Sign in as admin'));
      await tester.pumpAndSettle();
      expect(find.text('Manage Buildings'), findsOneWidget);
      expect(AdminAccess.isAuthenticated, isTrue);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(AdminAccess.isAuthenticated, isFalse);
      final context = tester.element(find.byType(LoginScreen));
      expect(Navigator.of(context).canPop(), isFalse);
    },
  );

  testWidgets('exit returns to welcome and removes the map from navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MapScreen()),
    );
    await tester.tap(find.byTooltip('Exit campus guide'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
    final context = tester.element(find.byType(LoginScreen));
    expect(Navigator.of(context).canPop(), isFalse);
  });
}
