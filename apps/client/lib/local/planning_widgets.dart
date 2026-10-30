import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../money.dart';
import 'budgets.dart';
import 'ledger.dart';
import 'planning_api.dart';
import 'planning.dart';
import 'recurrence.dart';

class PlanningPanel extends StatefulWidget {
  const PlanningPanel({required this.api, required this.calendar,
    required this.onOpenTransaction, required this.onOpenScheduled, this.today, super.key});
  final PlanningWorkspaceApi api;
  final bool calendar;
  final Future<void> Function(Json) onOpenTransaction;
  final VoidCallback onOpenScheduled;
  final String? today;
  @override
  State<PlanningPanel> createState() => _PlanningPanelState();
}

class _PlanningPanelState extends State<PlanningPanel> {
  String get _today => widget.today ?? Recurrence.today();
  late String _month = _today.substring(0, 7);
  late String _date = _today;
  String _account = '';
  int _days = 30, _selected = 0, _visibleDays = 30;
  Set<String> _excludedSchedules = {};
  SharedPreferences? _prefs;
  String? _preferenceError;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _prefs = prefs);
    } catch (_) {
      if (mounted) setState(() => _preferenceError = 'Warning preferences could not be loaded. Default minimums are shown.');
    }
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  String _key(Json account) => 'forecast.minimum.v1.${account['id']}';
  int? _minimum(Json account) {
    final saved = _prefs?.getString(_key(account));
    if (saved == 'off') return null;
    return int.tryParse(saved ?? '') ?? (PlanningEngine.cashAccount(account) ? 0 : null);
  }
  Future<void> _editMinimum(Json account) async {
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (_) => ForecastMinimumDialog(name: account['name'] as String,
        minimum: _minimum(account), onSave: (value) async {
          final prefs = _prefs ?? await SharedPreferences.getInstance();
          if (!await prefs.setString(_key(account), value)) throw StateError('Preference was not saved.');
          if (mounted) setState(() { _prefs = prefs; _preferenceError = null; });
        }));
  }
  Future<void> _pickMonth() async {
    final date = await showDatePicker(context: context, initialDate: Recurrence.parse('$_month-01'),
      firstDate: DateTime(1900), lastDate: DateTime(9999, 12, 31), helpText: 'Choose a calendar month');
    if (date != null && mounted) setState(() { _month = Recurrence.format(date).substring(0, 7); _date = Recurrence.format(date); });
  }
  void _shiftMonth(int delta) => setState(() { _month = LocalLedger.shiftMonth(_month, delta); _date = '$_month-01'; });

  Future<void> _configureForecast(Json data) async {
    final schedules = LocalLedger.rows(data['schedules'] ?? <Json>[]);
    final result = await showDialog<ForecastConfiguration>(context: context,
      builder: (_) => ForecastConfigurationDialog(days: _days,
        excludedScheduleIds: _excludedSchedules, schedules: schedules));
    if (result != null && mounted) {
      setState(() {
        _days = result.days;
        _excludedSchedules = result.excludedScheduleIds;
        _selected = 0;
        _visibleDays = 30;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.api.planningSnapshot;
    final accounts = LocalLedger.rows(data['accounts']);
    if (_account.isNotEmpty && !accounts.any((a) => a['id'] == _account)) _account = '';
    final chosen = accounts.where((a) => _account.isEmpty ? PlanningEngine.cashAccount(a) : a['id'] == _account).toList();
    final ids = chosen.map((a) => a['id'] as String).toSet();
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.calendar ? 'Financial calendar' : 'Scheduled cash-flow forecast',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Read-only planning. Scheduled activity does not change actual balances. Budget allocations are not assumed spending.'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(key: ValueKey('planning-account:$_account'), initialValue: _account, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Account view', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: '', child: Text('All cash accounts (checking, savings, cash)', overflow: TextOverflow.ellipsis)),
          for (final a in accounts) DropdownMenuItem(value: a['id'] as String,
            child: Text(a['name'] as String, overflow: TextOverflow.ellipsis))],
        onChanged: (value) => setState(() { _account = value ?? ''; })),
      if (_preferenceError != null) Text(_preferenceError!),
      if (chosen.length == 1) TextButton.icon(onPressed: () => _editMinimum(chosen.single),
        icon: const Icon(Icons.notifications_none),
        label: Text(_minimum(chosen.single) == null ? 'Low-balance warning: off'
          : 'Low-balance minimum: ${money(_minimum(chosen.single))}')),
      if (chosen.length != 1) const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('Select one account to configure its minimum. The combined view does not include credit cards, loans, or other assets.')),
      const SizedBox(height: 16),
    ]);
    if (accounts.isEmpty || ids.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header,
        const Text('No accounts in this view. Add a cash account or select another account above.')]);
    }
    try {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header,
        if (widget.calendar) _calendar(data, ids, accounts) else _forecast(data, ids, accounts, chosen),
        const SizedBox(height: 24),
        Text('Limits: scheduled amounts may differ from actual payments. Unscheduled spending, interest, fees, exchange rates, '
          'and bank pending items are not predicted. ${data['datedOpenings'] == true ? 'Signed opening postings use their effective dates.' : 'Opening balances have no dates in this preview.'} '
          'Paused schedules are excluded. Review overdue items separately.'),
      ]);
    } catch (error) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header,
        Text('Planning unavailable: $error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!widget.calendar) TextButton(onPressed: () => setState(() {
          _days = 30; _excludedSchedules = {}; _selected = 0; _visibleDays = 30;
        }), child: const Text('Reset baseline'))]);
    }
  }

  Widget _calendar(Json data, Set<String> ids, List<Json> accounts) {
    final first = Recurrence.parse('$_month-01');
    final last = DateTime.utc(first.year, first.month + 1, 0);
    final events = PlanningEngine.calendar(data, from: Recurrence.format(first),
      through: Recurrence.format(last), today: _today).where((e) => e.accountIds.any(ids.contains)).toList();
    final byDate = <String, List<PlanningEvent>>{};
    for (final e in events) { (byDate[e.date] ??= []).add(e); }
    final offset = first.weekday - 1;
    final cells = ((offset + last.day + 6) ~/ 7) * 7;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        IconButton(key: const ValueKey('calendar-previous'), tooltip: 'Previous month',
          onPressed: _month == '1900-01' ? null : () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
        TextButton(onPressed: _pickMonth, child: Text(BudgetEngine.label(_month))),
        IconButton(key: const ValueKey('calendar-next'), tooltip: 'Next month',
          onPressed: _month == '9999-12' ? null : () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () => setState(() { _month = _today.substring(0, 7); _date = _today; }), child: const Text('Today')),
      ]),
      const Text('Day badges show activity counts. Select a day for recorded, scheduled, overdue, skipped, or voided details.'),
      const SizedBox(height: 12),
      Row(children: [for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(label)))]),
      const SizedBox(height: 6),
      LayoutBuilder(builder: (context, constraints) => GridView.builder(shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(), itemCount: cells,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 3,
          mainAxisSpacing: 3, mainAxisExtent: constraints.maxWidth < 520 ? 62 : 82),
        itemBuilder: (context, index) {
          final day = index - offset + 1;
          if (day < 1 || day > last.day) return const SizedBox.shrink();
          final date = '$_month-${day.toString().padLeft(2, '0')}';
          final count = byDate[date]?.length ?? 0;
          final overdue = byDate[date]?.any((e) => e.status == 'Overdue') ?? false;
          return Semantics(label: '$date, $count activities${overdue ? ', overdue' : ''}', selected: _date == date,
            child: Material(color: _date == date ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6), child: InkWell(key: ValueKey('calendar-$date'),
                onTap: () => setState(() => _date = date), child: Padding(padding: const EdgeInsets.all(4),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$day', style: TextStyle(fontWeight: date == _today ? FontWeight.bold : FontWeight.normal)),
                  if (count > 0) Text('$count', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: overdue ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary)),
                ])))));
        })),
      const SizedBox(height: 18),
      Text('Activity on $_date', style: Theme.of(context).textTheme.titleLarge),
      _events(byDate[_date] ?? [], ids, accounts),
    ]);
  }

  Widget _forecast(Json data, Set<String> ids, List<Json> accounts, List<Json> chosen) {
    final baseline = PlanningEngine.forecast(data, today: _today, days: _days);
    final result = _excludedSchedules.isEmpty ? baseline : PlanningEngine.forecast(
      data, today: _today, days: _days, excludedScheduleIds: _excludedSchedules);
    final scenario = _excludedSchedules.isNotEmpty;
    final selected = result.days[_selected.clamp(0, result.days.length - 1)];
    final starting = ids.fold<int>(0, (sum, id) => BudgetEngine.add(sum, result.starting[id]!));
    final minimum = result.days.map((d) => d.total(ids)).reduce(math.min);
    final overdue = ids.fold<int>(0, (sum, id) => sum + (result.overdueCounts[id] ?? 0));
    final futureRecorded = LocalLedger.rows(data['transactions']).any((t) => t['voided'] != true &&
      (t['effectiveDate'] as String).compareTo(_today) > 0 &&
      LocalLedger.rows(t['postings']).any((p) => ids.contains(p['ledgerId'])));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 280, child: DropdownButtonFormField<int>(key: ValueKey('forecast-horizon:$_days'),
        initialValue: _days, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Forecast period', border: OutlineInputBorder()),
        items: [for (final days in ({30, 60, 90, 365, _days}.toList()..sort())) DropdownMenuItem(value: days,
          child: Text('$days days including today', overflow: TextOverflow.ellipsis))],
        onChanged: (value) => setState(() { _days = value!; _selected = 0; _visibleDays = 30; }))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(key: const ValueKey('configure-forecast'),
          onPressed: () => _configureForecast(data), icon: const Icon(Icons.tune),
          label: const Text('Configure forecast')),
        TextButton(key: const ValueKey('reset-forecast'),
          onPressed: _days == 30 && !scenario ? null : () => setState(() {
            _days = 30; _excludedSchedules = {}; _selected = 0; _visibleDays = 30;
          }), child: const Text('Reset baseline')),
      ]),
      const SizedBox(height: 8),
      Text(scenario
        ? 'What-if scenario: ${_excludedSchedules.length} schedule(s) excluded. Normal schedules and recorded activity remain unchanged.'
        : 'Baseline: all active unresolved schedules. No what-if exclusions.'),
      const Text('Forecast configuration is session-only; it is not saved or synchronized. Reset restores all schedules and 30 days.'),
      const SizedBox(height: 14),
      Wrap(spacing: 28, runSpacing: 14, children: [
        _stat('Recorded through $_today', starting), _stat('${scenario ? 'What-if' : 'Projected'} ${result.days.last.date}', result.days.last.total(ids)),
        if (scenario) _stat('Baseline with all schedules', baseline.days.last.total(ids)),
        _stat('Lowest projected closing balance', minimum),
      ]),
      const SizedBox(height: 12),
      const Text('The start includes recorded entries dated today or earlier. Today\'s remaining schedules are added afterward. '
        'Warnings use end-of-day balances, not intraday timing.'),
      if (futureRecorded) const Text('Future-dated recorded entries are included on their effective dates, not in the starting balance. '
        'The account register total may therefore differ.'),
      if (overdue > 0) Card(color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$overdue unresolved overdue account impacts are excluded. Transfers affect two accounts. No payment date is assumed.'),
          TextButton(onPressed: widget.onOpenScheduled, child: const Text('Review overdue activity')),
        ]))),
      for (final a in chosen) if (_minimum(a) != null && result.firstBelow(a['id'] as String, _minimum(a)!) != null)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(
          '${a['name']}: below ${money(_minimum(a))} on ${result.firstBelow(a['id'] as String, _minimum(a)!)}',
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
      const SizedBox(height: 14),
      Text(scenario
        ? 'Daily closing balance: solid = what-if; dotted = normal schedule baseline; dashed = recorded entries only. Tap to inspect a day.'
        : 'Daily closing balance: solid = with schedules; dashed = recorded entries only. Tap the chart to inspect a day.'),
      const SizedBox(height: 8),
      Text('${result.days.first.date} through ${result.days.last.date}; USD. Chart scale adapts to the displayed series.'),
      LayoutBuilder(builder: (context, c) => Semantics(label: 'Cash flow chart. Exact values are available in the daily balances list below.',
        child: GestureDetector(onTapDown: (tap) => setState(() => _selected =
          ((tap.localPosition.dx / c.maxWidth) * (result.days.length - 1)).round().clamp(0, result.days.length - 1)),
          child: SizedBox(height: 170, width: double.infinity, child: CustomPaint(painter: _ForecastPainter(
            result.days.map((d) => d.total(ids)).toList(), result.days.map((d) => d.total(ids, includePlans: false)).toList(),
            Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.outline, _selected,
            baseline: scenario ? baseline.days.map((d) => d.total(ids)).toList() : null,
            baselineColor: Theme.of(context).colorScheme.tertiary)))))),
      if (result.days.length > 1) Slider(value: _selected.toDouble(), min: 0, max: (result.days.length - 1).toDouble(),
        divisions: result.days.length - 1, label: selected.date,
        semanticFormatterCallback: (value) => '${result.days[value.round()].date}: ${money(result.days[value.round()].total(ids))}',
        onChanged: (value) => setState(() => _selected = value.round())),
      Text('${selected.date}: ${money(selected.total(ids))} ${scenario ? 'what-if' : 'projected'}', style: Theme.of(context).textTheme.titleLarge),
      Text('Recorded-only closing balance: ${money(selected.total(ids, includePlans: false))}'),
      if (scenario) Text('Normal schedule baseline: ${money(baseline.days[_selected].total(ids))}. '
        'What-if difference: ${money(BudgetEngine.add(selected.total(ids), -baseline.days[_selected].total(ids)))}.'),
      if (selected.date == _today) const Text('Recorded entries listed for today are already included in the starting balance.'),
      _events(selected.events.where((e) => e.accountIds.any(ids.contains)).toList(), ids, accounts),
      const SizedBox(height: 16),
      ExpansionTile(title: const Text('Daily balances'), subtitle: const Text('Exact values and daily activity'), children: [
        for (var i = 0; i < math.min(_visibleDays, result.days.length); i++) ListTile(dense: true,
          selected: _selected == i, title: Text(result.days[i].date),
          subtitle: Text('Recorded only: ${money(result.days[i].total(ids, includePlans: false))}'
            '${scenario ? '\nNormal baseline: ${money(baseline.days[i].total(ids))}' : ''}'),
          trailing: Text(money(result.days[i].total(ids))), onTap: () => setState(() => _selected = i)),
        if (_visibleDays < result.days.length) TextButton(onPressed: () => setState(() => _visibleDays += 30), child: const Text('Show 30 more days')),
      ]),
    ]);
  }
  Widget _stat(String name, int value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(name), Text(money(value), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
  ]);
  Widget _events(List<PlanningEvent> events, Set<String> ids, List<Json> accounts) {
    final names = {for (final a in accounts) a['id']: a['name']};
    if (events.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No activity on this date.'));
    return Column(children: [for (final e in events) Card(child: ListTile(
      title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('${e.status} | ${e.kind}\n${e.accountIds.map((id) => names[id]).join(' / ')}'
        '${e.status == 'Skipped' || e.status == 'Voided' ? '\nNo balance effect' : ''}'),
      isThreeLine: true,
      trailing: Text(money(e.changeFor(ids))),
      onTap: () async {
        await showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(e.name),
          content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e.date} | ${e.status} | ${e.kind}'),
            if (e.occurrence != null) Text('Original scheduled date: ${e.occurrence!.originalDueDate}'),
            for (final change in e.changes.entries) Text('${names[change.key]}: ${money(change.value)}'),
            if (e.changes.isEmpty) const Text('No balance effect.'),
            if (e.planned) const Text('This is a plan, not a recorded transaction. Use Scheduled to record, postpone, or skip it.'),
            if (e.transaction != null) Text(e.transaction!['notes'] as String? ?? ''),
          ]))), actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
            if (e.planned) TextButton(onPressed: () { Navigator.pop(c); widget.onOpenScheduled(); }, child: const Text('Open Scheduled')),
            if (e.transaction != null && e.status != 'Voided') TextButton(onPressed: () {
              Navigator.pop(c); widget.onOpenTransaction(e.transaction!);
            }, child: const Text('Open recorded transaction')),
          ]));
      },
    ))]);
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter(this.projected, this.recorded, this.primary, this.outline, this.selected,
    {this.baseline, required this.baselineColor});
  final List<int>? baseline;
  final Color baselineColor;
  final List<int> projected, recorded;
  final Color primary, outline;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [...projected, ...recorded, ...?baseline];
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = math.max(1, high - low);
    Offset point(int i, int value) => Offset((projected.length == 1 ? size.width / 2 : i * size.width / (projected.length - 1)),
      size.height - 12 - (value - low) / span * (size.height - 24));
    if (baseline != null) {
      final paint = Paint()..color = baselineColor..strokeWidth = 2;
      if (baseline!.length == 1) { canvas.drawCircle(point(0, baseline!.first), 6, paint..style = PaintingStyle.stroke); }
      for (var i = 1; i < baseline!.length; i++) {
        final a = point(i - 1, baseline![i - 1]), b = point(i, baseline![i]);
        final length = (b - a).distance;
        for (var d = 0.0; d < length; d += 6) {
          canvas.drawCircle(Offset.lerp(a, b, d / length)!, 1.5, paint);
        }
      }
    }
    final path = Path()..moveTo(point(0, projected[0]).dx, point(0, projected[0]).dy);
    for (var i = 1; i < projected.length; i++) { final p = point(i, projected[i]); path.lineTo(p.dx, p.dy); }
    canvas.drawPath(path, Paint()..color = primary..strokeWidth = 2.5..style = PaintingStyle.stroke);
    final dashed = Paint()..color = outline..strokeWidth = 1.5;
    if (recorded.length == 1) {
      final p = point(0, recorded.first);
      canvas.drawLine(p.translate(-9, 0), p.translate(9, 0), dashed);
    }
    for (var i = 1; i < recorded.length; i++) {
      final a = point(i - 1, recorded[i - 1]), b = point(i, recorded[i]);
      final length = (b - a).distance;
      for (var d = 0.0; d < length; d += 10) {
        canvas.drawLine(Offset.lerp(a, b, d / length)!, Offset.lerp(a, b, math.min(d + 5, length) / length)!, dashed);
      }
    }
    final p = point(selected, projected[selected]);
    canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), Paint()..color = outline.withValues(alpha: .4));
    canvas.drawCircle(p, 5, Paint()..color = primary);
  }
  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) => true;
}

class ForecastMinimumDialog extends StatefulWidget {
  const ForecastMinimumDialog({required this.name, required this.minimum, required this.onSave, super.key});
  final String name;
  final int? minimum;
  final Future<void> Function(String) onSave;
  @override
  State<ForecastMinimumDialog> createState() => _ForecastMinimumDialogState();
}
class _ForecastMinimumDialogState extends State<ForecastMinimumDialog> {
  late final _amount = TextEditingController(text: widget.minimum == null ? '' : decimalAmount(widget.minimum!));
  late bool _enabled = widget.minimum != null;
  bool _busy = false;
  String? _error;
  @override
  void dispose() { _amount.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final value = !_enabled ? 'off' : parseMinor(_amount.text, allowNegative: true).toString();
      await widget.onSave(value);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'Enter a valid amount with at most two decimal places, and check that settings can be saved.'; });
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: const Text('Low-balance warning'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.name), const SizedBox(height: 12),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable minimum warning'), value: _enabled,
        onChanged: _busy ? null : (v) => setState(() => _enabled = v)),
      TextField(key: const ValueKey('forecast-minimum'), controller: _amount, enabled: _enabled && !_busy,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: const InputDecoration(labelText: 'Minimum end-of-day balance (USD)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      const Text('This device-only display preference does not move money. It is not encrypted, synchronized, or included in financial backups. '
        'Debt balances are negative; this is not an available-credit forecast.'),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]))), actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('Save minimum')),
    ]));
}

/// Detached session configuration, never a saved schedule or financial command.
class ForecastConfiguration {
  ForecastConfiguration(this.days, Set<String> excludedScheduleIds)
      : excludedScheduleIds = Set.unmodifiable(excludedScheduleIds);
  final int days;
  final Set<String> excludedScheduleIds;
}

class ForecastConfigurationDialog extends StatefulWidget {
  const ForecastConfigurationDialog({required this.days,
    required this.excludedScheduleIds, required this.schedules, super.key});
  final int days;
  final Set<String> excludedScheduleIds;
  final List<Json> schedules;
  @override
  State<ForecastConfigurationDialog> createState() => _ForecastConfigurationDialogState();
}

class _ForecastConfigurationDialogState extends State<ForecastConfigurationDialog> {
  late final _days = TextEditingController(text: widget.days.toString());
  late final _excluded = Set<String>.from(widget.excludedScheduleIds);
  String? _error;
  @override
  void dispose() { _days.dispose(); super.dispose(); }
  void _apply() {
    final text = _days.text.trim();
    final days = RegExp(r'^\d{1,3}$').hasMatch(text) ? int.tryParse(text) : null;
    if (days == null || days < 1 || days > 365) {
      setState(() => _error = 'Enter a whole number from 1 to 365 days.');
      return;
    }
    Navigator.pop(context, ForecastConfiguration(days, _excluded));
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Configure forecast'),
    content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(key: const ValueKey('forecast-custom-days'), controller: _days,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Days including today (1–365)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      const Text('Include schedules in this what-if projection. Unchecking a schedule removes only its unresolved occurrences due today or later from the scenario, never recorded transactions or the baseline.'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        TextButton(key: const ValueKey('forecast-include-all'),
          onPressed: () => setState(_excluded.clear), child: const Text('Include all')),
        TextButton(key: const ValueKey('forecast-exclude-all'),
          onPressed: () => setState(() { _excluded.addAll(widget.schedules.map((s) => s['id'] as String)); }),
          child: const Text('Recorded only')),
      ]),
      if (widget.schedules.isEmpty) const Text('No saved schedules. The forecast contains recorded activity only.'),
      for (final schedule in widget.schedules) CheckboxListTile(
        key: ValueKey('forecast-schedule-${schedule['id']}'), contentPadding: EdgeInsets.zero,
        title: Text(schedule['name'] as String),
        subtitle: Text('${schedule['kind']} · ${schedule['frequency']} · ${money(schedule['amountMinor'] as int)}'
          '${schedule['paused'] == true ? ' · Paused; excluded regardless' : ''}'),
        value: !_excluded.contains(schedule['id']),
        onChanged: (include) => setState(() {
          if (include == true) { _excluded.remove(schedule['id']); }
          else { _excluded.add(schedule['id'] as String); }
        })),
      const SizedBox(height: 8),
      const Text('Session-only. Apply changes the view, not balances, schedules, bank data or server settings. Cancel discards these choices. Overdue unresolved items remain excluded and disclosed.'),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(key: const ValueKey('apply-forecast-configuration'), onPressed: _apply,
        child: const Text('Apply forecast')),
    ]);
}
