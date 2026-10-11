import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/config/map_config.dart';
import 'package:final_project/data/campus_map_data.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/screens/chatbot_screen.dart';
import 'package:final_project/screens/map_screen.dart';
import 'package:final_project/theme/app_theme.dart';
import 'support/fake_facility_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [
    const Size(360, 800),
    const Size(360, 520),
    const Size(1024, 600),
  ]) {
    testWidgets('map controls and selected place do not overlap at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = installFakeCatalog();
      addTearDown(repository.dispose);
      // Load cached asset futures outside the fake clock and isolate each size.
      rootBundle.clear();
      await tester.runAsync(() async {
        await loadCampusMapLocations();
        await MapConfig.load();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const MapScreen(),
        ),
      );
      // Asset reads run outside the test clock; allow both location and logo loads.
      await tester.runAsync(() async {
        await loadCampusMapLocations();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 1));
      final panel = find.byKey(const ValueKey('campus-map-panel'));
      final toolbar = find.byKey(const ValueKey('map-toolbar'));
      final credits = find.byKey(const ValueKey('map-attribution'));
      expect(panel, findsOneWidget);
      expect(
        tester.getRect(toolbar).bottom,
        lessThan(tester.getRect(credits).top),
      );
      for (final tooltip in ['Zoom in', 'Zoom out', 'Recenter campus']) {
        expect(
          tester
              .getRect(toolbar)
              .contains(tester.getCenter(find.byTooltip(tooltip))),
          isTrue,
        );
      }
      if (size.width < 900) {
        await tester.ensureVisible(find.text('Browse'));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Browse'));
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text(mockFacilities.first.name).first);
      } else {
        await tester.scrollUntilVisible(
          find.text(mockFacilities.first.name),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('campus-directory-panel')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(mockFacilities.first.name).first);
      await tester.pump(const Duration(seconds: 1));
      final selection = find.byKey(const ValueKey('map-selection-panel'));
      expect(selection, findsOneWidget);
      expect(
        tester.getRect(panel).bottom,
        lessThan(tester.getRect(selection).top),
      );
      expect(tester.getRect(panel).left, tester.getRect(selection).left);
      expect(tester.getRect(panel).right, tester.getRect(selection).right);
      expect(tester.getSize(panel).height, greaterThan(200));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'chat keeps side gutters and its composer inside the frame with the keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: const ChatbotScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final frame = tester.getRect(find.byKey(const ValueKey('chat-panel')));
      final field = tester.getRect(find.byType(TextField));
      final send = tester.getRect(find.byTooltip('Send question'));
      expect(frame.left, 16);
      expect(frame.right, 344);
      expect(frame.bottom, lessThanOrEqualTo(520));
      expect(field.left, greaterThan(frame.left));
      expect(field.right, lessThanOrEqualTo(send.left));
      expect(send.right, lessThan(frame.right));
      expect(send.bottom, lessThan(frame.bottom));
      expect(tester.takeException(), isNull);
    },
  );
}
