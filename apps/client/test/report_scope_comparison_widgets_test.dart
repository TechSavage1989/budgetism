import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/report_widgets.dart';
import 'reports_test.dart' show reportFixture;

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('category scope cancel none split comparison and reset fit $width without writes', (tester) async {
      tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final ledger = reportFixture();
      final original = jsonEncode(ledger.data);
      final housing = LocalLedger.rows(ledger.data['categories']).firstWhere((c) => c['name'] == 'Housing')['id'];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(16), child: ReportPanel(readSnapshot: () => ledger.snapshot(includeVoided: true), today: '2026-10-28'))))));
      await tester.pumpAndSettle();
      Future<void> tapKey(String key) async {
        final finder = find.byKey(ValueKey(key));
        if (key.startsWith('report-category-choice-')) {
          await tester.scrollUntilVisible(finder, 100, scrollable: find.descendant(
            of: find.byKey(const ValueKey('report-category-options')), matching: find.byType(Scrollable)));
        } else {
          await tester.ensureVisible(finder);
        }
        await tester.tap(finder); await tester.pumpAndSettle();
      }
      await tapKey('report-category-scope'); await tapKey('report-no-categories');
      await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
      expect(find.text('Category scope: All categories'), findsOneWidget);
      await tapKey('report-category-scope'); await tapKey('report-no-categories'); await tapKey('apply-report-categories');
      expect(find.text('Category scope: No categories'), findsOneWidget);
      expect(find.text('No income or expenses in this selection.'), findsOneWidget);
      await tapKey('report-category-scope'); await tapKey('report-category-choice-$housing'); await tapKey('apply-report-categories');
      expect(find.text('Category scope: Housing'), findsOneWidget);
      expect(find.text('\$140.00'), findsOneWidget);
      await tapKey('report-comparison-none');
      await tester.tap(find.text('Previous equal-length period').last); await tester.pumpAndSettle();
      expect(find.text('Comparison: 2026-09-03 through 2026-09-30 (28 days).'), findsOneWidget);
      expect(find.text('Current: \$140.00'), findsOneWidget);
      expect(find.textContaining('N/A (zero or negative comparison base)'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tapKey('reset-report-controls');
      expect(find.text('Period comparison'), findsNothing);
      expect(find.text('Category scope: All categories'), findsOneWidget);
      expect(find.text('\$230.00'), findsOneWidget);
      expect(jsonEncode(ledger.data), original); expect(tester.takeException(), isNull);
    });
  }
  testWidgets('invalid historical comparison fails visibly with no stale panel', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ReportPanel(
      readSnapshot: () => reportFixture().snapshot(includeVoided: true), today: '1900-01-28')))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-comparison-none'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Same dates previous year').last); await tester.pumpAndSettle();
    expect(find.textContaining('Comparison unavailable:'), findsOneWidget);
    expect(find.text('Period comparison'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
