import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/screens/admin_dashboard_screen.dart';
import 'package:final_project/screens/admin_login_screen.dart';
import 'package:final_project/services/admin_access.dart';
import 'package:final_project/screens/building_info_screen.dart';
import 'package:final_project/screens/chatbot_screen.dart';
import 'package:final_project/screens/login_screen.dart';
import 'package:final_project/screens/map_screen.dart';
import 'package:final_project/screens/search_screen.dart';
import 'package:final_project/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await loader.load();
  });
  final screens = <String, Widget Function()>{
    'welcome': () => const LoginScreen(),
    'details': () => BuildingInfoScreen(facility: mockFacilities[11]),
    'directory': () => const SearchScreen(),
    'assistant': () => const ChatbotScreen(),
    'management': () => const AdminDashboardScreen(),
    'admin login': () => const AdminLoginScreen(),
    'map': () => const MapScreen(),
  };

  for (final width in [320.0, 1440.0]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits at width $width', (tester) async {
        // Futures cached in a previous test belong to its fake async zone.
        rootBundle.clear();
        AdminAccess.signOut();
        addTearDown(AdminAccess.signOut);
        if (entry.key == 'management') {
          AdminAccess.signIn('admin', 'ligHAU-admin');
        }
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: entry.value()),
        );
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          if (entry.key != 'map' ||
              find.byTooltip('Zoom in').evaluate().isNotEmpty) {
            break;
          }
        }
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        if (entry.key == 'map') {
          expect(find.byTooltip('Zoom in'), findsOneWidget);
          expect(find.byTooltip('Recenter campus'), findsOneWidget);
          if (width < 900) {
            await tester.tap(find.text('Browse'));
            await tester.pumpAndSettle();
            expect(find.text('Campus places'), findsOneWidget);
            await tester.tap(find.text(mockFacilities.first.name));
            await tester.pumpAndSettle();
            expect(find.text('Map location coming soon'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
