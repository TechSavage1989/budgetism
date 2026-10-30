import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/server_planning_test.dart' show runPlanningScenario;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native private server budgets schedules forecasts reports labels and saved searches',
    (tester) async {
      final capture = GlobalKey();
      await runPlanningScenario(
        tester,
        captureKey: capture,
        capture: (name) async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await tester.runAsync(
            () => File('build/$name').writeAsBytes(bytes!.buffer.asUint8List()),
          );
        },
      );
    },
  );
}
