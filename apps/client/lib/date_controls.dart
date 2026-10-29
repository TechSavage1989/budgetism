import 'package:flutter/material.dart';

/// Presentation-only date helpers. Values remain calendar dates, never instants.
/// No storage, finance API, timezone conversion or implicit save belongs here.
class FinanceDates {
  static final first = DateTime(1900);
  static final last = DateTime(9999, 12, 31);
  static DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  static String format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static DateTime? parse(String text) {
    final value = text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final date = int.parse(value.substring(8, 10));
    if (year < 1900 || year > 9999) return null;
    final result = DateTime(year, month, date);
    return result.year == year && result.month == month && result.day == date ? result : null;
  }

  static DateTime shift(DateTime value, int days) {
    final result = DateTime.utc(value.year, value.month, value.day).add(Duration(days: days));
    return day(result);
  }

  static DateTime clamp(DateTime value, DateTime first, DateTime last) {
    final date = day(value);
    return date.isBefore(first) ? first : date.isAfter(last) ? last : date;
  }

  static (String, String) preset(String name, DateTime now) {
    final today = day(now);
    final start = switch (name) {
      'Last 7 days' => shift(today, -6),
      'Last 30 days' => shift(today, -29),
      'Month to date' => DateTime(today.year, today.month),
      'Last month' => DateTime(today.year, today.month - 1),
      'Year to date' => DateTime(today.year),
      _ => today,
    };
    final end = name == 'Last month' ? DateTime(today.year, today.month, 0) : today;
    return (format(clamp(start, first, last)), format(clamp(end, first, last)));
  }
}

Future<DateTime?> chooseFinanceDate(BuildContext context, {required String value,
    required String label, DateTime? firstDate, DateTime? lastDate, DateTime? today}) async {
  final first = FinanceDates.day(firstDate ?? FinanceDates.first);
  final last = FinanceDates.day(lastDate ?? FinanceDates.last);
  if (first.isAfter(last)) return null;
  return showDatePicker(context: context,
    initialDate: FinanceDates.clamp(FinanceDates.parse(value) ?? today ?? DateTime.now(), first, last),
    firstDate: first, lastDate: last, currentDate: today,
    initialEntryMode: DatePickerEntryMode.calendar, helpText: label,
    cancelText: 'Cancel', confirmText: 'Use date');
}

Future<DateTimeRange?> chooseFinanceRange(BuildContext context, {required String from,
    required String through, String label = 'Choose date range', DateTime? lastDate, DateTime? today}) {
  final first = FinanceDates.first;
  final last = FinanceDates.day(lastDate ?? FinanceDates.last);
  final start = FinanceDates.parse(from), end = FinanceDates.parse(through);
  final valid = start != null && end != null && !start.isAfter(end) &&
      !start.isBefore(first) && !end.isAfter(last);
  return showDateRangePicker(context: context, firstDate: first, lastDate: last,
    initialDateRange: valid ? DateTimeRange(start: start, end: end) : null,
    currentDate: today, initialEntryMode: DatePickerEntryMode.calendar,
    helpText: label, cancelText: 'Cancel', confirmText: 'Use dates', saveText: 'Use dates',
    builder: (context, child) => MediaQuery.sizeOf(context).width < 600 ? child! : Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720), child: child)));
}

/// Keep the underlying TextField key and controller for existing forms/tests.
/// Calendar confirmation, Today and Clear notify the owner exactly once.
class FinanceDateField extends StatefulWidget {
  const FinanceDateField({super.key, required this.controller, required this.label,
    this.fieldKey, this.onChanged, this.enabled = true, this.readOnly = false,
    this.allowEmpty = false, this.showToday = true, this.firstDate, this.lastDate,
    this.today, this.helperText});
  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final bool enabled, readOnly, allowEmpty, showToday;
  final DateTime? firstDate, lastDate, today;
  final String? helperText;
  @override
  State<FinanceDateField> createState() => _FinanceDateFieldState();
}

class _FinanceDateFieldState extends State<FinanceDateField> {
  bool _choosing = false;
  DateTime get _first => FinanceDates.day(widget.firstDate ?? FinanceDates.first);
  DateTime get _last => FinanceDates.day(widget.lastDate ?? FinanceDates.last);
  bool get _editable => widget.enabled && !widget.readOnly && !_choosing;
  bool _allowed(DateTime value) => !value.isBefore(_first) && !value.isAfter(_last);

  void _replace(String value) {
    if (widget.controller.text == value) return;
    widget.controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    widget.onChanged?.call(value);
  }

  Future<void> _pick() async {
    if (!_editable || _first.isAfter(_last)) return;
    final controller = widget.controller, before = widget.controller.text;
    setState(() => _choosing = true);
    try {
      final chosen = await chooseFinanceDate(context, value: before, label: widget.label,
        firstDate: _first, lastDate: _last, today: widget.today);
      if (chosen != null && mounted && widget.enabled && !widget.readOnly &&
          identical(controller, widget.controller) && controller.text == before && _allowed(chosen)) {
        _replace(FinanceDates.format(chosen));
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = FinanceDates.day(widget.today ?? DateTime.now());
    return TextField(key: widget.fieldKey, controller: widget.controller,
      enabled: widget.enabled && !_choosing, readOnly: widget.readOnly,
      keyboardType: TextInputType.datetime, autocorrect: false, enableSuggestions: false,
      onChanged: widget.onChanged,
      decoration: InputDecoration(labelText: widget.label, hintText: 'YYYY-MM-DD',
        helperText: widget.helperText, helperMaxLines: 3, border: const OutlineInputBorder(),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.showToday && !widget.readOnly) IconButton(
            tooltip: 'Today: ${widget.label}', icon: const Icon(Icons.today_outlined),
            onPressed: _editable && _allowed(today) ? () => _replace(FinanceDates.format(today)) : null),
          if (widget.allowEmpty && !widget.readOnly) IconButton(
            tooltip: 'Clear: ${widget.label}', icon: const Icon(Icons.clear),
            onPressed: _editable ? () => _replace('') : null),
          IconButton(tooltip: 'Choose date: ${widget.label}', icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _editable && !_first.isAfter(_last) ? _pick : null),
        ])));
  }
}

/// Presets update both endpoints in one callback. Selection is session-only.
class FinanceDateRangeBar extends StatefulWidget {
  const FinanceDateRangeBar({super.key, required this.from, required this.through,
    required this.onChanged, this.enabled = true, this.allowAll = false, this.today});
  final String from, through;
  final void Function(String, String) onChanged;
  final bool enabled, allowAll;
  final DateTime? today;
  @override
  State<FinanceDateRangeBar> createState() => _FinanceDateRangeBarState();
}

class _FinanceDateRangeBarState extends State<FinanceDateRangeBar> {
  bool _choosing = false;
  Future<void> _pick() async {
    if (_choosing || !widget.enabled) return;
    final from = widget.from, through = widget.through;
    setState(() => _choosing = true);
    try {
      final choice = await chooseFinanceRange(context, from: from, through: through, today: widget.today);
      if (choice != null && mounted && widget.enabled && widget.from == from && widget.through == through) {
        widget.onChanged(FinanceDates.format(choice.start), FinanceDates.format(choice.end));
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }
  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
    OutlinedButton.icon(onPressed: widget.enabled && !_choosing ? _pick : null,
      icon: const Icon(Icons.date_range_outlined), label: const Text('Choose date range')),
    for (final name in ['Today', 'Last 7 days', 'Last 30 days', 'Month to date', 'Last month', 'Year to date'])
      TextButton(onPressed: !widget.enabled || _choosing ? null : () {
        final (from, through) = FinanceDates.preset(name, widget.today ?? DateTime.now());
        widget.onChanged(from, through);
      }, child: Text(name)),
    if (widget.allowAll) TextButton(onPressed: !widget.enabled || _choosing ? null : () => widget.onChanged('', ''),
      child: const Text('All dates')),
  ]);
}

/// A visual month grid plus year picker replaces the typed budget year.
class FinanceMonthDialog extends StatefulWidget {
  const FinanceMonthDialog({super.key, required this.month, this.today});
  final String month;
  final DateTime? today;
  @override
  State<FinanceMonthDialog> createState() => _FinanceMonthDialogState();
}

class _FinanceMonthDialogState extends State<FinanceMonthDialog> {
  late int _year = int.parse(widget.month.substring(0, 4));
  late int _month = int.parse(widget.month.substring(5));
  bool _years = false;
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Choose budget month'),
    content: SizedBox(width: 340, height: 310, child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(tooltip: 'Previous year', onPressed: _year <= 1900 ? null : () => setState(() => _year--),
          icon: const Icon(Icons.chevron_left)),
        TextButton(onPressed: () => setState(() => _years = !_years), child: Text('$_year', key: const Key('budget-year'))),
        IconButton(tooltip: 'Next year', onPressed: _year >= 9999 ? null : () => setState(() => _year++),
          icon: const Icon(Icons.chevron_right)),
      ]),
      Expanded(child: _years ? YearPicker(firstDate: FinanceDates.first, lastDate: FinanceDates.last,
        selectedDate: DateTime(_year, _month), currentDate: widget.today,
        onChanged: (value) => setState(() { _year = value.year; _years = false; })) : GridView.count(
          crossAxisCount: 3, childAspectRatio: 2.2, mainAxisSpacing: 6, crossAxisSpacing: 6,
          children: [for (var m = 1; m <= 12; m++) ChoiceChip(
            key: ValueKey('budget-month-$m'), label: Text(_months[m - 1]), selected: _month == m,
            onSelected: (_) => setState(() => _month = m))])),
      TextButton(onPressed: () => setState(() {
        final today = FinanceDates.clamp(widget.today ?? DateTime.now(), FinanceDates.first, FinanceDates.last);
        _year = today.year; _month = today.month; _years = false;
      }), child: const Text('This month')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context,
        '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}'), child: const Text('Go to month'))]);
}
