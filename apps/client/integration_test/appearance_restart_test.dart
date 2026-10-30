import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/appearance.dart';
import 'package:budgetism/demo_finance_api.dart';
import 'package:budgetism/main.dart' show FinanceShell;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('APPEARANCE_TEST_PHASE');
  const directory = String.fromEnvironment('APPEARANCE_TEST_DIRECTORY');
  testWidgets(
    'custom appearance persists across processes and renders readable native themes',
    (tester) async {
      if (!{'write', 'read'}.contains(phase) || directory.isEmpty) {
        throw StateError('Explicit restart phase/directory required');
      }
      final key = 'test.appearance.${sha256.convert(utf8.encode(directory))}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      const settings = AppAppearance(
        mode: ThemeMode.dark,
        accent: 0x2878C8,
        highContrast: true,
        compact: true,
      );
      var completed = false;
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        if (phase == 'write') {
          expect(prefs.containsKey(key), isFalse);
          await AppearancePreferences().save(settings, preferenceKey: key);
        } else {
          expect(
            AppAppearance.read(prefs, key: key).toJson(),
            settings.toJson(),
          );
        }
        if (phase == 'read') {
          final capture = GlobalKey();
          final api = DemoFinanceApi();
          await tester.pumpWidget(
            MaterialApp(
              theme: settings.theme(Brightness.light),
              darkTheme: settings.theme(Brightness.dark),
              themeMode: settings.mode,
              builder:
                  (_, child) => RepaintBoundary(key: capture, child: child!),
              home: Builder(
                builder:
                    (context) => FinanceShell(
                      api: api,
                      username: 'Fictional',
                      onLogout: () {},
                      onToggleTheme: () {},
                      onCheckUpdates: () {},
                      onAppearance:
                          () => showDialog<AppAppearance>(
                            context: context,
                            builder:
                                (_) =>
                                    const AppearanceDialog(initial: settings),
                          ),
                    ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> capturePng(String path) async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            await tester.runAsync(
              () => File(path).writeAsBytes(bytes!.buffer.asUint8List()),
            );
          }

          await capturePng('build/appearance-dark-native.png');
          final nav = find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text('Settings'),
          );
          await tester.tap(nav);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('tool-theme')));
          await tester.tap(find.byKey(const ValueKey('tool-theme')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Light').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Forest'));
          await tester.pumpAndSettle();
          await capturePng('build/appearance-light-native.png');
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(
            AppAppearance.read(prefs, key: key).toJson(),
            settings.toJson(),
          );
          expect(tester.takeException(), isNull);
        }
        completed = true;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        if (phase == 'read' || !completed) await prefs.remove(key);
      }
    },
  );
}
