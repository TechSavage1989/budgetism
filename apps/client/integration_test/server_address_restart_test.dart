import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/main.dart' show ConnectionScreen;
import 'package:budgetism/server_address.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('SERVER_ADDRESS_TEST_PHASE');
  const directory = String.fromEnvironment('SERVER_ADDRESS_TEST_DIRECTORY');
  testWidgets(
    'native address preference survives a separate process and forget removes only its test key',
    (tester) async {
      if (!{'write', 'read'}.contains(phase) || directory.isEmpty) {
        throw StateError('Explicit restart phase/directory required');
      }
      final key =
          'test.serverAddress.${sha256.convert(utf8.encode(directory))}';
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final store = ServerAddressPreferences(key: key);
      final capture = GlobalKey();
      var handshakes = 0, completed = false;
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        if (phase == 'write') {
          expect(
            preferences.containsKey(key),
            isFalse,
            reason: 'Refuse to replace an existing test value',
          );
          await store.save('https://fictional-budget.example/private/');
        } else {
          expect(
            await store.read(),
            'https://fictional-budget.example/private',
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: capture,
              child: ConnectionScreen(
                addressPreferences: store,
                onCheckUpdates: () {},
                onSignedIn: (_, _) {},
                apiFactory: (url) {
                  handshakes++;
                  return FinanceApi(url);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final address = find.widgetWithText(TextField, 'Private server URL');
        expect(
          tester.widget<TextField>(address).controller!.text,
          'https://fictional-budget.example/private',
        );
        expect(handshakes, 0);
        expect(find.widgetWithText(TextField, 'Password'), findsNothing);
        if (phase == 'read') {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await tester.runAsync(
            () => File(
              'build/server-address-native.png',
            ).writeAsBytes(bytes!.buffer.asUint8List()),
          );
          await tester.ensureVisible(find.text('Forget saved address'));
          await tester.tap(find.text('Forget saved address'));
          await tester.pumpAndSettle();
          await preferences.reload();
          expect(preferences.containsKey(key), isFalse);
          expect(handshakes, 0);
        }
        completed = true;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        // Only this invocation's unique fictional metadata key can be removed.
        if (phase == 'read' || !completed) await preferences.remove(key);
      }
    },
  );
}
