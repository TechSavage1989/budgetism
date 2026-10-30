import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../money.dart';
import 'reports.dart';
import 'report_comparison.dart';

class ReportComparisonPanel extends StatelessWidget {
  const ReportComparisonPanel({required this.current, required this.previous, required this.values, super.key});
  final FinanceReport current, previous;
  final List<ReportComparisonValue> values;
  @override
  Widget build(BuildContext context) {
    final currentRange = ReportComparisonRange(current.from, current.through);
    final previousRange = ReportComparisonRange(previous.from, previous.through);
    final low = values.fold<int>(0, (n, v) => math.min(n, math.min(v.current, v.previous)));
    final high = values.fold<int>(0, (n, v) => math.max(n, math.max(v.current, v.previous)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Period comparison', style: Theme.of(context).textTheme.titleLarge),
      Text('Current: ${current.from} through ${current.through} (${currentRange.days} days).'),
      Text('Comparison: ${previous.from} through ${previous.through} (${previousRange.days} days).'),
      const Text('Totals, not daily averages. Previous-year dates clamp February 29 to February 28; periods can differ in length. Percentage change is unavailable for zero or negative comparison totals.'),
      Text('Same accounts and category scope: ${current.categoryScope}. Transfers and opening balances are excluded.'),
      const SizedBox(height: 8),
      Text('Shared signed scale: ${money(low)} to ${money(high)} USD. Bars compare period totals, not aligned dates.'),
      for (final v in values) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.label, style: Theme.of(context).textTheme.titleMedium),
        _bar(context, 'Current', v.current, low, high, Theme.of(context).colorScheme.primary),
        _bar(context, 'Comparison', v.previous, low, high, Theme.of(context).colorScheme.tertiary),
        SelectableText('Difference: ${money(v.delta)}; change: ${v.percentage}'),
      ]))),
    ]);
  }
  Widget _bar(BuildContext context, String label, int amount, int low, int high, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('$label: ${money(amount)}'),
    const SizedBox(height: 4),
    SizedBox(height: 14, width: double.infinity, child: CustomPaint(painter: _ComparisonBar(amount, low, high, color,
      Theme.of(context).colorScheme.outline))),
    const SizedBox(height: 6),
  ]);
}

class _ComparisonBar extends CustomPainter {
  const _ComparisonBar(this.amount, this.low, this.high, this.color, this.axis);
  final int amount, low, high;
  final Color color, axis;
  @override
  void paint(Canvas canvas, Size size) {
    double x(int v) => high == low ? size.width / 2 :
      (v.toDouble() - low.toDouble()) / (high.toDouble() - low.toDouble()) * size.width;
    final zero = x(0), end = x(amount);
    if (amount != 0) {
      canvas.drawRect(Rect.fromLTRB(math.min(zero, end), 3, math.max(zero, end), size.height - 3), Paint()..color = color);
    }
    canvas.drawLine(Offset(zero, 0), Offset(zero, size.height), Paint()..color = axis..strokeWidth = 1);
  }
  @override
  bool shouldRepaint(covariant _ComparisonBar oldDelegate) => amount != oldDelegate.amount || low != oldDelegate.low ||
    high != oldDelegate.high || color != oldDelegate.color || axis != oldDelegate.axis;
}
