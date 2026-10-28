import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'ledger.dart';
import 'local_api.dart';

Future<void> showReconciliation(BuildContext context, LocalFinanceApi api) async {
  await api.snapshot();
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => ReconciliationWorkspace(api: api));
}

class ReconciliationWorkspace extends StatefulWidget {
  const ReconciliationWorkspace({required this.api, super.key});
  final LocalFinanceApi api;
  @override
  State<ReconciliationWorkspace> createState() => _ReconciliationWorkspaceState();
}
class _ReconciliationWorkspaceState extends State<ReconciliationWorkspace> {
  String? _accountId;
  String? _error;
  Future<void> _start() async {
    final changed = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => StatementReview(snapshot: widget.api.vault.ledger.snapshot(), accountId: _accountId!,
        onSave: widget.api.reconcile));
    if (changed == true && mounted) setState(() {});
  }
  Future<void> _reopen(Json statement) async {
    final revision = widget.api.vault.ledger.revision;
    final reason = await showDialog<String>(context: context, builder: (_) => const ReopenStatementDialog());
    if (reason == null || !mounted) return;
    try {
      await widget.api.reopenStatement({'operationId': const Uuid().v4(), 'id': statement['id'],
        'expectedVersion': statement['version'], 'expectedRevision': revision,
        'confirmReopen': true, 'reason': reason});
      if (mounted) setState(() => _error = null);
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }
  Future<void> _details(Json statement) async {
    final entries = LocalLedger.rows(statement['entries']);
    await showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: Text('Statement ending ${statement['endDate']}'),
      content: SizedBox(width: 540, height: 320, child: ListView(children: [
        Text('Starting: ${money(statement['openingMinor'])}   Closing: ${money(statement['closingMinor'])}'),
        Text(statement['reopened'] == true ? 'Reopened: ${statement['reopenReason']}' : 'Completed; included transactions are protected.'),
        if ((statement['note'] as String).isNotEmpty) Text(statement['note'] as String),
        const SizedBox(height: 12),
        if (entries.isEmpty) const Text('No additional transactions on this statement.'),
        for (final e in entries) ListTile(contentPadding: EdgeInsets.zero,
          title: Text('${e['date']}    ${money(e['amountMinor'])}'),
          subtitle: Text('Transaction ${e['transactionId']}')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]));
  }
  @override
  Widget build(BuildContext context) {
    final data = widget.api.vault.ledger.snapshot();
    final accounts = LocalLedger.rows(data['accounts']);
    _accountId ??= accounts.isEmpty ? null : accounts.first['id'] as String;
    final history = _accountId == null ? <Json>[] : Reconciliation.history(data, _accountId!);
    final active = history.where((s) => s['reopened'] == false).toList();
    return AlertDialog(title: const Text('Reconcile statements'),
      content: SizedBox(width: 760, height: 520, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Compare recorded transactions with your statement. This does not move money or create adjustments.'),
        const SizedBox(height: 12),
        if (accounts.isEmpty) const Text('Create an account first.') else ...[
          DropdownButtonFormField<String>(key: ValueKey(_accountId), initialValue: _accountId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
            items: [for (final a in accounts) DropdownMenuItem(value: a['id'] as String,
              child: Text(a['name'] as String, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() { _accountId = v; _error = null; })),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _start, icon: const Icon(Icons.fact_check_outlined), child: const Text('Start reconciliation')),
          const SizedBox(height: 12),
          Text('Starting balance for the next statement: ${money(Reconciliation.opening(data, _accountId!))}'),
          const Text('Only the latest completed statement for this account can be reopened.'),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          Expanded(child: history.isEmpty ? const Center(child: Text('No statements completed yet.'))
            : ListView(children: [for (final s in history.reversed) Card(child: Padding(
              padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s['endDate']} | ${money(s['closingMinor'])} | ${s['reopened'] == true ? 'Reopened' : 'Completed'}'),
                Wrap(spacing: 8, children: [
                  TextButton(onPressed: () => _details(s), child: const Text('Details')),
                  if (active.isNotEmpty && active.last['id'] == s['id'])
                    TextButton(onPressed: () => _reopen(s), child: const Text('Reopen statement')),
                ]),
              ])))])),
        ],
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]);
  }
}

class StatementReview extends StatefulWidget {
  const StatementReview({required this.snapshot, required this.accountId, required this.onSave, super.key});
  final Json snapshot;
  final String accountId;
  final Future<void> Function(Json) onSave;
  @override
  State<StatementReview> createState() => _StatementReviewState();
}
class _StatementReviewState extends State<StatementReview> {
  final _date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _closing = TextEditingController();
  final _note = TextEditingController();
  final _selected = <String>{};
  final _operation = const Uuid().v4();
  List<Json>? _rows;
  int? _target;
  bool _reviewed = false, _upgrade = false, _busy = false;
  String? _error;
  int get _start => Reconciliation.opening(widget.snapshot, widget.accountId);
  bool get _needsUpgrade => (widget.snapshot['schema'] as int) < LocalLedger.reconciliationSchema;
  int get _checked => Reconciliation.total(_start, (_rows ?? <Json>[])
      .where((t) => _selected.contains(t['id'])).map((t) => Reconciliation.effect(t, widget.accountId)));
  @override
  void dispose() { _date.dispose(); _closing.dispose(); _note.dispose(); super.dispose(); }
  void _preview() {
    try {
      final date = _date.text.trim(); LocalLedger.date(date);
      final previous = Reconciliation.active(widget.snapshot, widget.accountId);
      if (previous.isNotEmpty && date.compareTo(previous.last['endDate'] as String) <= 0) {
        throw const FormatException('Use a later ending date or reopen the latest statement first.');
      }
      final target = parseMinor(_closing.text, allowNegative: true);
      final rows = Reconciliation.candidates(widget.snapshot, widget.accountId, date);
      setState(() { _target = target; _rows = rows; _selected.clear(); _reviewed = false; _error = null; });
    } catch (e) { setState(() => _error = e.toString()); }
  }
  Future<void> _save() async {
    if (_busy || _rows == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (!_reviewed || (_needsUpgrade && !_upgrade)) throw const FormatException('Confirm review and any required format upgrade first.');
      await widget.onSave({'operationId': _operation, 'expectedRevision': widget.snapshot['cursor'],
        'accountId': widget.accountId, 'endDate': _date.text.trim(), 'closingMinor': _target,
        'transactionIds': _selected.toList()..sort(), 'note': _note.text.trim(), 'confirmReviewed': true,
        'confirmReconciliationUpgrade': _upgrade});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) setState(() { _busy = false; _error = e.toString(); }); }
  }
  @override
  Widget build(BuildContext context) {
    final account = Reconciliation.account(widget.snapshot, widget.accountId);
    int? checked; String? calculationError;
    try { checked = _checked; } catch (e) { calculationError = e.toString(); }
    final difference = _target == null || checked == null ? null : _target! - checked;
    return PopScope(canPop: !_busy, child: AlertDialog(
      title: Text('Reconcile ${account['name']}'),
      content: SizedBox(width: 740, height: 600, child: ListView(children: [
        Text('Starting cleared balance: ${money(_start)}'),
        const Text('First statement starts at the account opening balance. Later statements start at the prior completed balance. Select only transactions cleared on this statement, including older outstanding items.'),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('statement-date'), controller: _date, enabled: !_busy && _rows == null,
          decoration: const InputDecoration(labelText: 'Statement ending date (YYYY-MM-DD)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('statement-closing'), controller: _closing, enabled: !_busy && _rows == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Statement closing balance (USD)', border: OutlineInputBorder(),
            helperText: 'Use a negative balance for money owed on a credit card or loan.', helperMaxLines: 3)),
        const SizedBox(height: 12),
        if (_rows == null) FilledButton(onPressed: _busy ? null : _preview, child: const Text('Review statement')) else ...[
          TextButton(onPressed: _busy ? null : () => setState(() { _rows = null; _selected.clear(); _reviewed = false; }),
            child: const Text('Change statement details')),
          Text('${_rows!.length} outstanding transactions through ${_date.text.trim()}. ${_selected.length} selected.'),
          const Text('A recorded transaction is not automatically considered cleared. Compare each selection with the statement.'),
          const SizedBox(height: 8),
          SizedBox(height: 240, child: _rows!.isEmpty ? const Center(child: Text('No outstanding transactions by this date.'))
            : ListView.builder(itemCount: _rows!.length, itemBuilder: (_, i) {
              final t = _rows![i]; final id = t['id'] as String;
              return CheckboxListTile(key: ValueKey('statement-row:$id'), controlAffinity: ListTileControlAffinity.leading,
                value: _selected.contains(id), isThreeLine: false,
                title: Text('${t['payee'] == '' ? t['kind'] : t['payee']} | ${money(Reconciliation.effect(t, widget.accountId))}'),
                subtitle: Text('${t['effectiveDate']} | ${t['kind']}'),
                onChanged: _busy ? null : (v) => setState(() {
                  if (v == true) { _selected.add(id); } else { _selected.remove(id); }
                  _reviewed = false;
                }));
            })),
          const SizedBox(height: 12),
          Text('Selected cleared balance: ${checked == null ? 'Unavailable' : money(checked)}'),
          Text('Statement difference: ${difference == null ? 'Unavailable' : money(difference)}',
            key: const ValueKey('statement-difference'), style: TextStyle(fontWeight: FontWeight.bold,
              color: difference == 0 ? null : Theme.of(context).colorScheme.error)),
          if (calculationError != null) Text(calculationError),
          const Text('Finish is available only at exactly zero. No automatic adjustment is created.'),
          const SizedBox(height: 12),
          TextField(controller: _note, enabled: !_busy, maxLength: 300,
            decoration: const InputDecoration(labelText: 'Statement note (optional)', border: OutlineInputBorder())),
          if (_needsUpgrade) ...[
            const Text('Export an encrypted backup first. Completing the first statement preserves records but upgrades the financial format; older builds cannot open it.'),
            CheckboxListTile(key: const ValueKey('statement-upgrade'), value: _upgrade,
              controlAffinity: ListTileControlAffinity.leading, title: const Text('I have a backup and accept the dev.9 format upgrade'),
              onChanged: _busy ? null : (v) => setState(() => _upgrade = v ?? false)),
          ],
          CheckboxListTile(key: const ValueKey('statement-reviewed'), value: _reviewed,
            controlAffinity: ListTileControlAffinity.leading, title: const Text('I checked these transactions and the ending balance against the statement'),
            onChanged: _busy ? null : (v) => setState(() => _reviewed = v ?? false)),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        if (_rows != null) FilledButton(onPressed: _busy || difference != 0 || !_reviewed || (_needsUpgrade && !_upgrade) ? null : _save,
          child: const Text('Finish reconciliation'))],
    ));
  }
}

class ReopenStatementDialog extends StatefulWidget {
  const ReopenStatementDialog({super.key});
  @override
  State<ReopenStatementDialog> createState() => _ReopenStatementDialogState();
}
class _ReopenStatementDialogState extends State<ReopenStatementDialog> {
  final _reason = TextEditingController();
  bool _confirmed = false;
  @override
  void dispose() { _reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Reopen latest statement?'),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('The statement stays in history, but its transactions become outstanding again for this account. Balances do not change. Transfers remain protected if reconciled in another account.'),
      const SizedBox(height: 12),
      TextField(controller: _reason, maxLength: 300, onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
      CheckboxListTile(value: _confirmed, title: const Text('Reopen without deleting transactions'),
        onChanged: (v) => setState(() => _confirmed = v ?? false)),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _confirmed && _reason.text.trim().isNotEmpty
        ? () => Navigator.pop(context, _reason.text.trim()) : null, child: const Text('Reopen statement'))]);
}
