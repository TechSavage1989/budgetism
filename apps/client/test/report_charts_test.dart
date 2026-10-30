import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/report_charts.dart';
import 'package:budgetism/local/report_widgets.dart';
import 'package:budgetism/local/reports.dart';

import 'reports_test.dart' show reportFixture;

FinanceReport graphReport(List<ReportMonth> months) => FinanceReport(
  from: '2026-01-01',
  through: '2026-03-31',
  today: '2026-10-28',
  income: 0,
  expense: 0,
  starting: 0,
  closing: 0,
  transferCount: 0,
  transactions: [],
  categories: [],
  balances: [],
  months: months,
);

void main() {
  test('series preserve exact signed refunds, net income and debt', () {
    final report = graphReport([
      const ReportMonth('2026-01', 10000, 12000, -12345),
      const ReportMonth('2026-02', 0, -1500, -10845),
      const ReportMonth('2026-03', 0, 0, -10845),
    ]);
    final dual = ReportChartSeries.from(
      report,
      ReportChartMetric.incomeAndExpenses,
    );
    expect(dual[0].values, [10000, 0, 0]);
    expect(dual[1].values, [12000, -1500, 0]);
    expect(
      ReportChartSeries.from(report, ReportChartMetric.netIncome).single.values,
      [-2000, 1500, 0],
    );
    expect(
      ReportChartSeries.from(
        report,
        ReportChartMetric.recordedBalance,
      ).single.values,
      [-12345, -10845, -10845],
    );
    final scale = ReportChartScale(dual);
    expect(scale.minimum, -1500);
    expect(scale.maximum, 12000);
    expect(scale.fraction(-1500), 0);
    expect(scale.fraction(12000), 1);
    expect(scale.fraction(0), greaterThan(0));
    expect(scale.fraction(0), lessThan(1));
  });
  test(
    'zero and all-negative scales include zero without division by zero',
    () {
      final zero = ReportChartScale([
        const ReportChartSeries('zero', [0, 0]),
      ]);
      expect(zero.fraction(0), .5);
      final negative = ReportChartScale([
        const ReportChartSeries('debt', [-100, -200]),
      ]);
      expect(negative.minimum, -200);
      expect(negative.maximum, 0);
      expect(negative.fraction(-200), 0);
      expect(negative.fraction(0), 1);
      final large = ReportChartScale([
        const ReportChartSeries('large', [-9007199254740991, 9007199254740991]),
      ]);
      expect(large.fraction(0), closeTo(.5, 1e-12));
    },
  );
  for (final width in [320.0, 1100.0]) {
    testWidgets('graph controls and exact signed data fit $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = graphReport([
        const ReportMonth('2026-01', 0, -1500, -12345),
        const ReportMonth('2026-02', 0, 0, -12345),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ReportCharts(report: report),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Expenses: -\$15.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-chart-bars')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-chart-table')));
      await tester.pumpAndSettle();
      expect(
        find.text('Exact monthly values (same selected accounts and dates)'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('report-chart-metric')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recorded net balance').last);
      await tester.pumpAndSettle();
      expect(find.text('Recorded net balance: -\$123.45'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('zero activity has explicit explanation and no invented totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportCharts(
              report: graphReport([const ReportMonth('2026-01', 0, 0, 0)]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'All selected values are zero. The graph shows a flat zero baseline.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('report-chart-month')), findsNothing);
    expect(find.text('Income: \$0.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'range and account cancel preserve snapshot and graph selection scope',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ledger = reportFixture();
      final before = jsonEncode(ledger.data);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportPanel(
                readSnapshot: () => ledger.snapshot(includeVoided: true),
                today: '2026-10-28',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-view-Graphs')));
      await tester.pumpAndSettle();
      expect(find.text('Income: \$500.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-accounts')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear selection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Income: \$500.00'), findsOneWidget);
      await tester.tap(find.text('Last 12 months'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-chart-month')), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('report-chart-month')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last month'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-chart-month')), findsNothing);
      expect(find.text('Income: \$0.00'), findsOneWidget);
      expect(jsonEncode(ledger.data), before);
      expect(tester.takeException(), isNull);
    },
  );
}
