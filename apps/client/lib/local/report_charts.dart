import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../money.dart';
import 'budgets.dart';
import 'reports.dart';

enum ReportChartMetric {
  incomeAndExpenses('Income and expenses'),
  netIncome('Net income'),
  recordedBalance('Recorded net balance');

  const ReportChartMetric(this.label);
  final String label;
}

/// Presentation-only series. Exact amounts remain integers; doubles are used
/// only to position pixels, never to calculate a financial result.
class ReportChartSeries {
  const ReportChartSeries(this.label, this.values);
  final String label;
  final List<int> values;
  static List<ReportChartSeries> from(
    FinanceReport report,
    ReportChartMetric metric,
  ) {
    switch (metric) {
      case ReportChartMetric.incomeAndExpenses:
        return [
          ReportChartSeries(
            'Income',
            report.months.map((m) => m.income).toList(),
          ),
          ReportChartSeries(
            'Expenses',
            report.months.map((m) => m.expense).toList(),
          ),
        ];
      case ReportChartMetric.netIncome:
        return [
          ReportChartSeries(
            'Net income',
            report.months.map((m) => m.net).toList(),
          ),
        ];
      case ReportChartMetric.recordedBalance:
        return [
          ReportChartSeries(
            'Recorded net balance',
            report.months.map((m) => m.closing).toList(),
          ),
        ];
    }
  }
}

/// Always includes a visible zero baseline and retains negative refunds/debt.
class ReportChartScale {
  ReportChartScale(Iterable<ReportChartSeries> series) {
    var low = 0, high = 0;
    for (final s in series) {
      for (final value in s.values) {
        low = math.min(low, value);
        high = math.max(high, value);
      }
    }
    minimum = low;
    maximum = high;
  }
  late final int minimum, maximum;
  double fraction(int value) => minimum == maximum
      ? .5
      : (value.toDouble() - minimum.toDouble()) /
            (maximum.toDouble() - minimum.toDouble());
}

class ReportCharts extends StatefulWidget {
  const ReportCharts({required this.report, super.key});
  final FinanceReport report;
  @override
  State<ReportCharts> createState() => _ReportChartsState();
}

class _ReportChartsState extends State<ReportCharts> {
  ReportChartMetric _metric = ReportChartMetric.incomeAndExpenses;
  bool _bars = false, _table = false;
  int _selected = 0;
  @override
  void didUpdateWidget(covariant ReportCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.from != widget.report.from ||
        oldWidget.report.through != widget.report.through) {
      _selected = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final series = ReportChartSeries.from(report, _metric);
    if (report.months.isEmpty) {
      return const Text('No monthly values in this selection.');
    }
    final selected = _selected.clamp(0, report.months.length - 1);
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.tertiary,
    ];
    final scale = ReportChartScale(series);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configure a monthly graph using the dates and accounts above. These controls affect this view only and are not saved.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<ReportChartMetric>(
                key: const ValueKey('report-chart-metric'),
                initialValue: _metric,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Graph measure',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final metric in ReportChartMetric.values)
                    DropdownMenuItem(value: metric, child: Text(metric.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _metric = value);
                },
              ),
            ),
            ChoiceChip(
              key: const ValueKey('report-chart-lines'),
              label: const Text('Lines'),
              selected: !_bars,
              onSelected: (_) => setState(() => _bars = false),
            ),
            ChoiceChip(
              key: const ValueKey('report-chart-bars'),
              label: const Text('Bars'),
              selected: _bars,
              onSelected: (_) => setState(() => _bars = true),
            ),
            FilterChip(
              key: const ValueKey('report-chart-table'),
              label: const Text('Exact values'),
              selected: _table,
              onSelected: (value) => setState(() => _table = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            for (var s = 0; s < series.length; s++)
              Text(
                '${s + 1}. ${series[s].label}${s == 1 && !_bars ? ' (dashed)' : ''}',
                style: TextStyle(color: colors[s], fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Monthly totals; first and last months may be partial. ${_metric == ReportChartMetric.recordedBalance ? 'Closing signed balances, including debt and transfers; not market values or a bank forecast.' : 'Transfers and opening balances are excluded. Negative spending means net refunds.'}',
        ),
        if (scale.minimum == 0 && scale.maximum == 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'All selected values are zero. The graph shows a flat zero baseline.',
            ),
          ),
        const SizedBox(height: 12),
        Text('Scale: ${money(scale.minimum)} to ${money(scale.maximum)} USD'),
        LayoutBuilder(
          builder: (context, constraints) => Semantics(
            label:
                '${_metric.label} monthly graph. Use the month selector or Exact values for complete signed amounts.',
            child: GestureDetector(
              key: const ValueKey('report-chart-canvas'),
              onTapDown: (details) {
                final usable = math.max(1.0, constraints.maxWidth - 32);
                final index =
                    ((details.localPosition.dx - 16) /
                            usable *
                            report.months.length)
                        .floor();
                setState(
                  () => _selected = index.clamp(0, report.months.length - 1),
                );
              },
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ReportChartPainter(
                    series: series,
                    scale: scale,
                    colors: colors,
                    bars: _bars,
                    selected: selected,
                    gridColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(report.months.first.month),
            if (report.months.length > 1) Text(report.months.last.month),
          ],
        ),
        if (report.months.length > 1)
          Slider(
            key: const ValueKey('report-chart-month'),
            value: selected.toDouble(),
            min: 0,
            max: (report.months.length - 1).toDouble(),
            divisions: report.months.length - 1,
            label: BudgetEngine.label(report.months[selected].month),
            semanticFormatterCallback: (value) =>
                BudgetEngine.label(report.months[value.round()].month),
            onChanged: (value) => setState(() => _selected = value.round()),
          ),
        const SizedBox(height: 8),
        Text(
          BudgetEngine.label(report.months[selected].month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final s in series)
          SelectableText('${s.label}: ${money(s.values[selected])}'),
        if (_table) ...[
          const Divider(),
          const Text('Exact monthly values (same selected accounts and dates)'),
          for (var i = 0; i < report.months.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      BudgetEngine.label(report.months[i].month),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 20,
                      runSpacing: 4,
                      children: [
                        for (final s in series)
                          SelectableText('${s.label}: ${money(s.values[i])}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ReportChartPainter extends CustomPainter {
  _ReportChartPainter({
    required this.series,
    required this.scale,
    required this.colors,
    required this.bars,
    required this.selected,
    required this.gridColor,
  });
  final List<ReportChartSeries> series;
  final ReportChartScale scale;
  final List<Color> colors;
  final bool bars;
  final int selected;
  final Color gridColor;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 16.0;
    final width = math.max(1.0, size.width - inset * 2),
        height = size.height - inset * 2;
    double y(int value) => inset + height * (1 - scale.fraction(value));
    final count = series.first.values.length;
    double x(int i) =>
        inset + width * (i + .5) / count;
    final baseline = y(0);
    canvas.drawLine(
      Offset(inset, baseline),
      Offset(size.width - inset, baseline),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(x(selected), inset),
      Offset(x(selected), size.height - inset),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );
    for (var s = 0; s < series.length; s++) {
      final values = series[s].values;
      final paint = Paint()
        ..color = colors[s]
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < values.length; i++) {
        if (bars) {
          final slot = math.min(28.0, width / (count * (series.length + 1)));
          final center = x(i) + (s - (series.length - 1) / 2) * slot;
          final left = (center - slot * .4).clamp(0.0, size.width);
          final right = (center + slot * .4).clamp(0.0, size.width);
          if (values[i] == 0) {
            canvas.drawLine(
              Offset(left, baseline),
              Offset(right, baseline),
              paint,
            );
          } else {
            canvas.drawRect(
              Rect.fromLTRB(
                left,
                math.min(y(values[i]), baseline),
                right,
                math.max(y(values[i]), baseline),
              ),
              Paint()..color = colors[s],
            );
          }
        } else {
          if (i > 0) {
            final a = Offset(x(i - 1), y(values[i - 1])),
                b = Offset(x(i), y(values[i]));
            if (s == 0) {
              canvas.drawLine(a, b, paint);
            } else {
              final distance = (b - a).distance;
              for (var d = 0.0; d < distance; d += 10) {
                canvas.drawLine(
                  Offset.lerp(a, b, d / distance)!,
                  Offset.lerp(a, b, math.min(d + 6, distance) / distance)!,
                  paint,
                );
              }
            }
          }
          canvas.drawCircle(
            Offset(x(i), y(values[i])),
            i == selected ? 4 : 2.5,
            Paint()..color = colors[s],
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReportChartPainter oldDelegate) => true;
}
