import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/appearance.dart';
import 'package:budgetism/server_dashboard_widgets.dart';
import '../test/server_dashboard_test.dart' show DashboardApiFixture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native server dashboard scope navigation failure and refresh never mutate',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = DashboardApiFixture();
      final capture = GlobalKey();
      int? destination;
      await tester.pumpWidget(
        MaterialApp(
          theme: const AppAppearance(accent: 0x2878C8).theme(Brightness.dark),
          home: RepaintBoundary(
            key: capture,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ServerDashboardPanel(
                    api: api,
                    revision: 1,
                    now: DateTime(2026, 10, 30),
                    onNavigate: (i) => destination = i,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Net recorded balance'), findsOneWidget);
      expect(find.textContaining('316 saved sources'), findsOneWidget);
      expect(
        find.textContaining('future-dated recorded entries'),
        findsOneWidget,
      );
      Future<void> screenshot(String name) async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        picture.dispose();
        await tester.runAsync(
          () => File('build/$name').writeAsBytes(bytes!.buffer.asUint8List()),
        );
      }

      await screenshot('server-dashboard-native.png');
      await tester.ensureVisible(find.byKey(const Key('dashboard-review')));
      await tester.tap(find.byKey(const Key('dashboard-review')));
      await tester.pump();
      expect(destination, 10);
      api.fail = true;
      await tester.ensureVisible(find.byKey(const Key('dashboard-refresh')));
      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Net recorded balance'), findsNothing);
      expect(find.textContaining('Dashboard unavailable.'), findsOneWidget);
      api.fail = false;
      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Net recorded balance'), findsOneWidget);
      expect(api.writes, 0);
      expect(api.reads, 3);
      tester.view.physicalSize = const Size(560, 1000);
      await tester.pumpAndSettle();
      await screenshot('server-dashboard-compact-native.png');
      expect(tester.takeException(), isNull);
    },
  );
}
