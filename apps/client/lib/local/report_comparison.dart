import 'reports.dart';
import 'recurrence.dart';

enum ReportComparisonPeriod {
  none('No comparison'), previousPeriod('Previous equal-length period'), previousYear('Same dates previous year');
  const ReportComparisonPeriod(this.label);
  final String label;
}

class ReportComparisonRange {
  const ReportComparisonRange(this.from, this.through);
  final String from, through;
  int get days => Recurrence.parse(through).difference(Recurrence.parse(from)).inDays + 1;
  static ReportComparisonRange forPeriod(String from, String through, ReportComparisonPeriod period) {
    final first = Recurrence.parse(from), last = Recurrence.parse(through);
    if (last.isBefore(first) || period == ReportComparisonPeriod.none) {
      throw const FormatException('Choose an ordered period and a comparison mode.');
    }
    DateTime priorFirst, priorLast;
    if (period == ReportComparisonPeriod.previousPeriod) {
      final count = last.difference(first).inDays + 1;
      priorLast = first.subtract(const Duration(days: 1));
      priorFirst = first.subtract(Duration(days: count));
    } else {
      DateTime previousYear(DateTime date) {
        final maxDay = DateTime.utc(date.year - 1, date.month + 1, 0).day;
        return DateTime.utc(date.year - 1, date.month, date.day > maxDay ? maxDay : date.day);
      }
      priorFirst = previousYear(first); priorLast = previousYear(last);
    }
    if (priorFirst.year < 1900) {
      throw const FormatException('Comparison would precede 1900. Choose later dates or turn comparison off.');
    }
    return ReportComparisonRange(Recurrence.format(priorFirst), Recurrence.format(priorLast));
  }
}

class ReportComparisonValue {
  ReportComparisonValue(this.label, this.current, this.previous)
    : delta = ReportEngine.add(current, -previous);
  final String label;
  final int current, previous, delta;
  // A zero or negative baseline has no meaningful conventional growth rate.
  // Percentage is display-only; exact financial values never use floating point.
  String get percentage => previous <= 0 ? 'N/A (zero or negative comparison base)'
    : '${(delta / previous * 100).toStringAsFixed(1)}%';
  static List<ReportComparisonValue> from(FinanceReport current, FinanceReport previous) => [
    ReportComparisonValue('Income', current.income, previous.income),
    ReportComparisonValue('Expenses', current.expense, previous.expense),
    ReportComparisonValue('Net income', current.netIncome, previous.netIncome),
  ];
}
