import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'ledger.dart';
import 'local_api.dart';
import 'recurrence.dart';
import 'schedules.dart';

String _kindLabel(String kind) => switch (kind) {
  'income' => 'Income', 'transfer' => 'Transfer / card payment', _ => 'Bill / expense',
};
String _amountLabel(String kind, int amount) => '${kind == 'income' ? '+' : kind == 'expense' ? '-' : ''}${money(amount)}';

class ScheduleOverview extends StatelessWidget {
  const ScheduleOverview({required this.snapshot, required this.onOpen, super.key});
  final Json snapshot;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final today = Recurrence.today();
    final page = ScheduleEngine.upcoming(snapshot, today: today, limit: 5);
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Upcoming bills and income', style: Theme.of(context).textTheme.titleLarge),
          TextButton(onPressed: onOpen, child: const Text('Open scheduled')),
        ]),
        const Text('Planned only. Balances and budgets change when an occurrence is recorded.'),
        if (page.items.isEmpty) const Padding(padding: EdgeInsets.only(top: 12),
          child: Text('No active bills or income due in the next 30 days or overdue.')),
        for (final occurrence in page.items) ListTile(contentPadding: EdgeInsets.zero,
          title: Text(occurrence.name), subtitle: Text('${occurrence.dueDate} | ${occurrence.timing(today)}'),
          trailing: Text(_amountLabel(occurrence.schedule['kind'] as String, occurrence.amount)), onTap: onOpen),
        if (page.hasMore) const Text('More scheduled items are available in Scheduled.'),
      ])));
  }
}

class SchedulePanel extends StatefulWidget {
  const SchedulePanel({required this.api, required this.onChanged, required this.onOpenTransaction, super.key});
  final LocalFinanceApi api;
  final Future<void> Function() onChanged;
  final Future<void> Function(Json) onOpenTransaction;
  @override
  State<SchedulePanel> createState() => _SchedulePanelState();
}

class _SchedulePanelState extends State<SchedulePanel> {
  String _view = 'Upcoming';
  int _days = 30;
  int _limit = 200;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    // Refresh date labels only. This never creates transactions or notifications.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _clock?.cancel(); super.dispose(); }

  Future<void> _edit([Json? existing]) async {
    final data = widget.api.vault.ledger.snapshot();
    final accounts = LocalLedger.rows(data['accounts']);
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create an account before adding a schedule.')));
      return;
    }
    final saved = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => ScheduleEditor(accounts: accounts, categories: LocalLedger.rows(data['categories']),
        existing: existing, requiresUpgrade: data['schema'] != LocalLedger.schema, onSave: widget.api.saveSchedule));
    if (saved == true && mounted) await widget.onChanged();
  }

  Future<void> _occurrence(ScheduledOccurrence occurrence, String action) async {
    final changed = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => OccurrenceDialog(occurrence: occurrence, action: action,
        onSave: action == 'confirm' ? widget.api.confirmOccurrence
          : action == 'postpone' ? widget.api.postponeOccurrence : widget.api.skipOccurrence));
    if (changed == true && mounted) await widget.onChanged();
  }

  Future<void> _pause(Json schedule) async {
    final paused = schedule['paused'] == true;
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(paused ? 'Resume schedule?' : 'Pause schedule?'),
      content: Text(paused ? 'Unconfirmed dates, including overdue ones, will appear again. Nothing is recorded automatically.'
          : 'Hide upcoming occurrences until resumed. Recorded transactions and history remain unchanged.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(paused ? 'Resume' : 'Pause'))]));
    if (yes != true || !mounted) return;
    try {
      await widget.api.setSchedulePaused({'operationId': const Uuid().v4(), 'id': schedule['id'],
        'expectedVersion': schedule['version'], 'paused': !paused});
      if (mounted) await widget.onChanged();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.api.vault.ledger.snapshot();
    final today = Recurrence.today();
    final schedules = LocalLedger.rows(data['schedules']);
    final accounts = {for (final a in LocalLedger.rows(data['accounts'])) a['id']: a['name']};
    final page = ScheduleEngine.upcoming(data, today: today, days: _days, limit: _limit);
    final history = LocalLedger.rows(data['occurrences']).where((o) => o['status'] != 'postponed').toList()
      ..sort((a, b) => (b['resolvedAtUtc'] as String).compareTo(a['resolvedAtUtc'] as String));
    final scheduleById = {for (final s in schedules) s['id']: s};
    final allTransactions = {for (final t in LocalLedger.rows(widget.api.vault.ledger.data['transactions'])) t['id']: t};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Scheduled bills and income', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Plan recurring bills, paychecks, and transfers. Nothing changes your balances until you record an occurrence.'),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add schedule')),
        for (final view in ['Upcoming', 'Schedules', 'History']) ChoiceChip(label: Text(view), selected: _view == view,
          onSelected: (_) => setState(() => _view = view)),
      ]),
      const SizedBox(height: 16),
      if (_view == 'Upcoming') ...[
        SizedBox(width: 300, child: DropdownButtonFormField<int>(initialValue: _days, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Upcoming range', border: OutlineInputBorder()),
          items: [for (final days in [30, 60, 90, 365]) DropdownMenuItem(value: days,
            child: Text('Next $days days + all overdue', maxLines: 1, overflow: TextOverflow.ellipsis))],
          onChanged: (value) => setState(() => _days = value!))),
        const SizedBox(height: 12),
        Text('As of $today. Confirm a bill only when it has actually been paid.'),
        if (page.items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No active occurrences in this range. Add a schedule or check paused schedules.')),
        for (final occurrence in page.items) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 14, runSpacing: 8, children: [
              Text(occurrence.name, style: Theme.of(context).textTheme.titleMedium),
              Text(_amountLabel(occurrence.schedule['kind'] as String, occurrence.amount),
                style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 6),
            Text('${_kindLabel(occurrence.schedule['kind'] as String)} | ${accounts[occurrence.schedule['accountId']]}'),
            Text('${occurrence.dueDate} | ${occurrence.timing(today)}', style: TextStyle(
              color: occurrence.dueDate.compareTo(today) < 0 ? Theme.of(context).colorScheme.error : null)),
            if (occurrence.record != null) Text('Postponed from ${occurrence.originalDueDate}. Later dates are unchanged.'),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => _occurrence(occurrence, 'confirm'), child: const Text('Record transaction')),
              TextButton(onPressed: () => _occurrence(occurrence, 'postpone'), child: const Text('Postpone')),
              TextButton(onPressed: () => _occurrence(occurrence, 'skip'), child: const Text('Skip')),
            ]),
          ]))),
        if (page.hasMore) ...[
          Text('Showing the earliest $_limit occurrences. Other dates are not skipped or recorded.'),
          if (_limit < 1000) TextButton(onPressed: () => setState(() => _limit += 200), child: const Text('Show 200 more'))
          else const Text('Resolve earlier occurrences or pause old schedules to see more.'),
        ],
      ],
      if (_view == 'Schedules') ...[
        const Text('Edits change unconfirmed occurrences only. To change recurrence dates, pause the old schedule and create a new one.'),
        if (schedules.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No schedules yet.')),
        for (final schedule in schedules) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(schedule['name'] as String, style: Theme.of(context).textTheme.titleMedium),
            Text('${Recurrence.label(schedule['frequency'] as String)} | First due ${schedule['startDate']}'
              '${schedule['endDate'] == null ? '' : ' | Last due on/before ${schedule['endDate']}'}'),
            Text('${_kindLabel(schedule['kind'] as String)} | ${accounts[schedule['accountId']]} | ${money(schedule['amountMinor'])}'
              ' | ${schedule['paused'] == true ? 'Paused' : 'Active'}'),
            Wrap(spacing: 10, children: [
              TextButton(onPressed: () => _edit(schedule), child: const Text('Edit schedule')),
              TextButton(onPressed: () => _pause(schedule), child: Text(schedule['paused'] == true ? 'Resume' : 'Pause')),
            ]),
          ]))),
      ],
      if (_view == 'History') ...[
        const Text('Recording and skipping settle only that occurrence. Voiding its transaction does not make it due again.'),
        if (history.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No recorded or skipped occurrences yet.')),
        for (final record in history.take(_limit)) Builder(builder: (context) {
          final schedule = scheduleById[record['scheduleId']]!;
          final transaction = allTransactions[record['transactionId']];
          final voided = transaction?['voided'] == true;
          return Card(child: ListTile(
            title: Text(schedule['name'] as String),
            subtitle: Text('Scheduled ${record['originalDueDate']} | '
              '${record['status'] == 'skipped' ? 'Skipped' : voided ? 'Recorded transaction was voided' : 'Recorded ${transaction?['effectiveDate']}'}'),
            trailing: Text(money(transaction?['amountMinor'] ?? record['plannedAmountMinor'])),
            onTap: transaction == null || voided ? null : () async {
              await widget.onOpenTransaction(transaction);
              if (mounted) await widget.onChanged();
            },
          ));
        }),
        if (history.length > _limit && _limit < 1000)
          TextButton(onPressed: () => setState(() => _limit += 200), child: const Text('Show 200 more')),
      ],
      const SizedBox(height: 28),
    ]);
  }
}

class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({required this.accounts, required this.categories, required this.requiresUpgrade,
    required this.onSave, this.existing, super.key});
  final List<Json> accounts;
  final List<Json> categories;
  final bool requiresUpgrade;
  final Future<void> Function(Json) onSave;
  final Json? existing;
  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}
class _ScheduleEditorState extends State<ScheduleEditor> {
  late final _name = TextEditingController(text: widget.existing?['name'] as String? ?? '');
  late final _amount = TextEditingController(text: widget.existing == null ? '' : decimalAmount(widget.existing!['amountMinor'] as int));
  late final _payee = TextEditingController(text: widget.existing?['payee'] as String? ?? '');
  late final _notes = TextEditingController(text: widget.existing?['notes'] as String? ?? '');
  late final _start = TextEditingController(text: widget.existing?['startDate'] as String? ?? Recurrence.today());
  late final _end = TextEditingController(text: widget.existing?['endDate'] as String? ?? '');
  late String _kind = widget.existing?['kind'] as String? ?? 'expense';
  late String _account = widget.existing?['accountId'] as String? ?? widget.accounts.first['id'] as String;
  late String? _target = widget.existing?['counterpartyAccountId'] as String?;
  late String _frequency = widget.existing?['frequency'] as String? ?? 'monthly';
  bool _busy = false;
  bool _upgrade = false;
  String? _error;
  final _operation = const Uuid().v4();
  List<Json> get _targets => _kind == 'transfer' ? widget.accounts.where((a) => a['id'] != _account).toList()
      : widget.categories.where((c) => c['kind'] == (_kind == 'income' ? 'Income' : 'Expense')).toList();
  String? get _selectedTarget => _targets.any((t) => t['id'] == _target) ? _target
      : _targets.isEmpty ? null : _targets.first['id'] as String;
  @override
  void dispose() {
    for (final controller in [_name, _amount, _payee, _notes, _start, _end]) { controller.dispose(); }
    super.dispose();
  }
  Future<void> _save() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_name.text.trim().isEmpty) throw const FormatException('Enter a schedule name.');
      if (widget.requiresUpgrade && !_upgrade) throw const FormatException('Export a backup and confirm the recurring-schedule format upgrade.');
      final amount = parseMinor(_amount.text);
      if (amount <= 0) throw const FormatException('Amount must be greater than zero.');
      Recurrence.parse(_start.text.trim());
      final end = _end.text.trim().isEmpty ? null : _end.text.trim();
      if (end != null) {
        Recurrence.parse(end);
        if (end.compareTo(_start.text.trim()) < 0) throw const FormatException('Last date cannot precede the first date.');
      }
      if (_selectedTarget == null) throw const FormatException('Choose a category or a different destination account.');
      await widget.onSave({'operationId': _operation, if (widget.existing != null) 'id': widget.existing!['id'],
        'expectedVersion': widget.existing?['version'] ?? 0, 'name': _name.text.trim(), 'kind': _kind,
        'accountId': _account, 'counterpartyAccountId': _selectedTarget, 'currency': 'USD', 'amountMinor': amount,
        'payee': _payee.text.trim(), 'notes': _notes.text.trim(), 'startDate': _start.text.trim(),
        'endDate': end, 'frequency': _frequency, 'confirmScheduleUpgrade': _upgrade});
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _busy = false; _error = error.toString(); }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: Text(widget.existing == null ? 'New recurring schedule' : 'Edit recurring schedule'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: AbsorbPointer(absorbing: _busy,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(key: const ValueKey('schedule-name'), controller: _name, maxLength: 100,
          decoration: const InputDecoration(labelText: 'Schedule name', border: OutlineInputBorder())),
        DropdownButtonFormField<String>(initialValue: _kind, decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
          items: [for (final kind in ['expense', 'income', 'transfer']) DropdownMenuItem(value: kind, child: Text(_kindLabel(kind)))],
          onChanged: (value) => setState(() { _kind = value!; _target = null; })),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _account, isExpanded: true,
          decoration: InputDecoration(labelText: _kind == 'income' ? 'Receiving account' : 'Payment / source account', border: const OutlineInputBorder()),
          items: [for (final account in widget.accounts) DropdownMenuItem(value: account['id'] as String, child: Text(account['name'] as String))],
          onChanged: (value) => setState(() { _account = value!; _target = null; })),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(key: ValueKey('schedule-target:$_kind:$_account'), initialValue: _selectedTarget, isExpanded: true,
          decoration: InputDecoration(labelText: _kind == 'transfer' ? 'Destination account' : 'Category', border: const OutlineInputBorder()),
          items: [for (final target in _targets) DropdownMenuItem(value: target['id'] as String, child: Text(target['name'] as String))],
          onChanged: (value) => setState(() => _target = value)),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('schedule-amount'), controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Expected amount (USD)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _frequency,
          decoration: const InputDecoration(labelText: 'Repeat', border: OutlineInputBorder()),
          items: [for (final frequency in Recurrence.frequencies) DropdownMenuItem(value: frequency, child: Text(Recurrence.label(frequency)))],
          onChanged: widget.existing != null ? null : (value) => setState(() => _frequency = value!)),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('schedule-start'), controller: _start, readOnly: widget.existing != null,
          decoration: const InputDecoration(labelText: 'First due date (YYYY-MM-DD)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _end, readOnly: widget.existing != null,
          decoration: const InputDecoration(labelText: 'Last scheduled date (optional, YYYY-MM-DD)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        const Text('Short months use their last day, then return to the original day. February 29 uses February 28 in non-leap years.'),
        if (widget.existing != null) const Text('Recurrence dates stay fixed. Pause and create a new schedule to change them. Edits affect unconfirmed occurrences, not recorded transactions.'),
        const SizedBox(height: 12),
        TextField(controller: _payee, maxLength: 150, decoration: const InputDecoration(labelText: 'Payee / description', border: OutlineInputBorder())),
        TextField(controller: _notes, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
        if (widget.requiresUpgrade) ...[
          const Text('Export a backup first. Saving your first schedule upgrades the workspace; older builds cannot open it. Accounts, budgets, and the password setting are retained.'),
          CheckboxListTile(key: const ValueKey('schedule-upgrade'), value: _upgrade,
            onChanged: (value) => setState(() => _upgrade = value ?? false), controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I exported a backup and understand this workspace will require dev.5 or newer')),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])))),
    actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('Save schedule'))],
  ));
}

class OccurrenceDialog extends StatefulWidget {
  const OccurrenceDialog({required this.occurrence, required this.action, required this.onSave, super.key});
  final ScheduledOccurrence occurrence;
  final String action;
  final Future<void> Function(Json) onSave;
  @override
  State<OccurrenceDialog> createState() => _OccurrenceDialogState();
}
class _OccurrenceDialogState extends State<OccurrenceDialog> {
  late final _amount = TextEditingController(text: decimalAmount(widget.occurrence.amount));
  late final _date = TextEditingController(text: widget.action == 'postpone' ? widget.occurrence.dueDate : Recurrence.today());
  late final _notes = TextEditingController(text: widget.occurrence.schedule['notes'] as String);
  final _operation = const Uuid().v4();
  bool _busy = false;
  String? _error;
  @override
  void dispose() { _amount.dispose(); _date.dispose(); _notes.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final input = widget.occurrence.command(_operation);
      if (widget.action == 'confirm') {
        final amount = parseMinor(_amount.text);
        if (amount <= 0) throw const FormatException('Amount must be greater than zero.');
        Recurrence.parse(_date.text.trim());
        input.addAll({'amountMinor': amount, 'effectiveDate': _date.text.trim(), 'notes': _notes.text.trim()});
      } else if (widget.action == 'postpone') {
        Recurrence.parse(_date.text.trim());
        if (_date.text.trim().compareTo(widget.occurrence.dueDate) <= 0) throw const FormatException('Choose a later due date.');
        input['dueDate'] = _date.text.trim();
      }
      await widget.onSave(input);
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _busy = false; _error = error.toString(); }); }
  }
  @override
  Widget build(BuildContext context) {
    final confirm = widget.action == 'confirm';
    final postpone = widget.action == 'postpone';
    return PopScope(canPop: !_busy, child: AlertDialog(
      title: Text(confirm ? 'Record this occurrence?' : postpone ? 'Postpone this occurrence' : 'Skip this occurrence?'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${widget.occurrence.name} | Due ${widget.occurrence.dueDate}'),
          const SizedBox(height: 12),
          Text(confirm ? 'This creates one actual transaction using the schedule account and category. Confirm only if it has happened. Edit the recorded transaction later to change its account or splits.'
              : postpone ? 'Only this due date changes. The remaining schedule stays anchored to its original dates.'
              : 'No transaction will be created. This occurrence stays in History and cannot be recorded again. Later occurrences remain scheduled.'),
          if (confirm) ...[
            const SizedBox(height: 16),
            TextField(key: const ValueKey('occurrence-amount'), controller: _amount, enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Actual amount (USD)', border: OutlineInputBorder())),
          ],
          if (confirm || postpone) ...[
            const SizedBox(height: 12),
            TextField(key: const ValueKey('occurrence-date'), controller: _date, enabled: !_busy,
              decoration: InputDecoration(labelText: confirm ? 'Recorded date (YYYY-MM-DD)' : 'New due date (YYYY-MM-DD)', border: const OutlineInputBorder())),
          ],
          if (confirm) ...[
            const SizedBox(height: 12), TextField(controller: _notes, enabled: !_busy, maxLength: 500, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]))),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save,
          child: Text(confirm ? 'Record transaction' : postpone ? 'Save due date' : 'Skip occurrence'))],
    ));
  }
}
