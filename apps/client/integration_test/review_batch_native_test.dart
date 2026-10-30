import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/appearance.dart';
import 'package:budgetism/server_bank_widgets.dart';
import '../test/server_bank_test.dart' show BankApiFixture, bankState;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native review selection filters and explicit batch decisions never call posting',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _NativeBatchApi();
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: const AppAppearance(accent: 0x22836A).theme(Brightness.light),
          home: RepaintBoundary(
            key: capture,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ServerBankPanel(api: api, onChanged: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> press(String text) async {
        await tester.ensureVisible(find.text(text).last);
        await tester.tap(find.text(text).last);
        await tester.pumpAndSettle();
      }

      await press('Select visible eligible');
      expect(find.text('2 selected'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('review-search')), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(api.writes, isEmpty);
      await press('Reset filters');
      await press('Select visible eligible');
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await tester.runAsync(
        () => File(
          'build/review-batch-native.png',
        ).writeAsBytes(bytes!.buffer.asUint8List()),
      );
      await press('Ignore selected');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('batch-apply')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for all selected decisions'),
        'Fictional test duplicates',
      );
      await tester.pump();
      await press(
        'I reviewed this selection and want to apply this reason to every selected source.',
      );
      await press('Apply selected decisions');
      expect(api.writes.single['route'], 'review-batch');
      expect((api.writes.single['sources'] as List).length, 2);
      expect(find.text('0 selected'), findsOneWidget);
      expect(api.postings, 0);
      await press('Select visible eligible');
      await press('Reopen decisions');
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for all selected decisions'),
        'Review these fictional decisions again',
      );
      await tester.pump();
      await press(
        'I reviewed this selection and want to apply this reason to every selected source.',
      );
      await press('Apply selected decisions');
      expect(api.writes.length, 2);
      expect(api.writes.last['action'], 'reopen');
      expect(api.postings, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _NativeBatchApi extends BankApiFixture {
  int connectionVersion = 4;
  bool decided = false;
  int postings = 0;
  @override
  Future<void> createTransaction(Map<String, dynamic> data) async {
    postings++;
    throw StateError('Posting is forbidden in a source-decision batch');
  }

  @override
  Future<Map<String, dynamic>> bankRequest(
    String route, [
    Map<String, dynamic>? body,
    int? offset,
    int? version,
  ]) async {
    if (body == null) {
      final data = bankState();
      final row = Map<String, dynamic>.from(
        (data['sources'] as List).single as Map,
      );
      data['batchReviewSupported'] = true;
      data['connection']['version'] = connectionVersion;
      data['sources'] = [
        for (var i = 0; i < 3; i++)
          {
            ...row,
            'id': '10000000-0000-4000-8000-00000000000${i + 4}',
            'description':
                i == 0
                    ? 'Fictional cafe'
                    : i == 1
                    ? 'Fictional lunch'
                    : 'Fictional pending',
            'status': i == 2 ? 'pending' : 'posted',
            'needsReview': i < 2 && !decided,
            'decision': decided && i < 2 ? 'ignored' : null,
            'reviewedVersion': decided && i < 2 ? 1 : null,
          },
      ];
      data['totalSources'] = 3;
      data['needsReviewCount'] = decided ? 0 : 2;
      return data;
    }
    if (route != 'review-batch') {
      throw StateError('Only explicit source decisions allowed');
    }
    if (body['expectedConnectionVersion'] != connectionVersion) throw StateError('Stale fictional connection version');
    writes.add({'route': route, ...body});
    decided = body['action'] != 'reopen';
    return {'connectionVersion': ++connectionVersion, 'reviewedSources': 2};
  }
}
