import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'ledger.dart';
import 'local_api.dart';

Future<void> showCategoryHistory(BuildContext context, LocalFinanceApi api) async {
  await api.snapshot();
  if (!context.mounted) return;
  await showDialog<void>(context: context, barrierDismissible: false,
    builder: (_) => Dialog.fullscreen(child: CategoryHistoryPage(
      readData: () => LocalLedger.clone(api.vault.ledger.data),
      onRefresh: () async { await api.snapshot(); }, onUndo: api.undoCategoryBatch,
    )));
}

String _time(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? 'Unavailable time' : date.toLocal().toString().substring(0, 16);
}

class CategoryHistoryPage extends StatefulWidget {
  const CategoryHistoryPage({super.key, required this.readData, required this.onUndo, this.onRefresh});
  final Json Function() readData;
  final Future<void> Function(Json) onUndo;
  final Future<void> Function()? onRefresh;
  @override
  State<CategoryHistoryPage> createState() => _CategoryHistoryPageState();
}

class _CategoryHistoryPageState extends State<CategoryHistoryPage> {
  late Json _data;
  bool _busy = false;
  int _limit = 50;
  String? _error, _notice;
  @override
  void initState() { super.initState(); _data = widget.readData(); }
  Future<void> _refresh() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await widget.onRefresh?.call();
      if (mounted) setState(() { _data = widget.readData(); _limit = 50; });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _inspect(String id) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await widget.onRefresh?.call();
      _data = widget.readData();
      final review = CategoryHistory.preview(_data, id);
      if (!mounted) return;
      final saved = await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (_) => CategoryUndoDialog(review: review, onUndo: widget.onUndo));
      if (mounted) {
        setState(() {
          _data = widget.readData();
          if (saved == true) _notice = 'Batch undone. Saved rules, account balances and transaction count are unchanged.';
        });
      }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    List<Json> batches = [];
    String? error = _error;
    try { batches = CategoryHistory.batches(_data); } catch (e) { error = e.toString(); }
    return PopScope(canPop: !_busy, child: Scaffold(
      appBar: AppBar(title: const Text('Categorization history'), automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Refresh history', onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh)), IconButton(tooltip: 'Close history',
          onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      body: ListView(key: const Key('category-history-scroll'), padding: const EdgeInsets.all(20), children: [
        const Text('Review applied rule batches, including earlier builds. Opening history does not change your records.'),
        const SizedBox(height: 8),
        const Text('Undo restores only the previous categories, for the complete batch. '
          'It is unavailable if any transaction changed or is reconciled. Saved rules are not removed or disabled.'),
        const SizedBox(height: 8), const Text('Newest batches first. Times use this device\'s local timezone.'),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(error, key: const Key('category-history-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_notice != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_notice!)),
        const SizedBox(height: 12),
        Text('${batches.length} applied batches', key: const Key('category-history-count')),
        if (batches.isEmpty && error == null) const Padding(padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No categorization batches yet. Saving a rule alone does not create a batch.')),
        for (final batch in batches.take(_limit)) Card(child: ListTile(
          key: ValueKey('category-batch-${batch['operationId']}'),
          title: Text('${_time(batch['atUtc'])} | ${batch['count'] ?? '?'} transactions'),
          subtitle: Text('${batch['from'] ?? '?'} to ${batch['through'] ?? '?'}\n'
            '${batch['undone'] == true ? 'Undone' : 'Applied - review undo availability'}'),
          trailing: const Icon(Icons.receipt_long_outlined),
          onTap: _busy || batch['operationId'] is! String ? null : () => _inspect(batch['operationId'] as String),
        )),
        if (batches.length > _limit) TextButton(onPressed: _busy ? null : () => setState(() => _limit += 50),
          child: const Text('Show 50 more batches')),
      ]),
    ));
  }
}

class CategoryUndoDialog extends StatefulWidget {
  const CategoryUndoDialog({super.key, required this.review, required this.onUndo});
  final Json review;
  final Future<void> Function(Json) onUndo;
  @override
  State<CategoryUndoDialog> createState() => _CategoryUndoDialogState();
}

class _CategoryUndoDialogState extends State<CategoryUndoDialog> {
  final _reason = TextEditingController();
  bool _busy = false, _reviewed = false;
  String? _error;
  String _operation = const Uuid().v4();
  @override
  void dispose() { _reason.dispose(); super.dispose(); }
  Future<void> _undo() async {
    if (_busy || widget.review['canUndo'] != true) return;
    if (!_reviewed || _reason.text.trim().isEmpty) {
      setState(() => _error = 'Enter a reason and confirm the complete batch before undoing it.');
      return;
    }
    final input = <String, dynamic>{'operationId': _operation,
      'sourceOperationId': widget.review['sourceOperationId'],
      'expectedRevision': widget.review['expectedRevision'],
      'previewFingerprint': widget.review['fingerprint'],
      'reason': _reason.text.trim(), 'confirmReviewed': _reviewed};
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onUndo(input);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final undone = r['undone'] == true, allowed = r['canUndo'] == true;
    return PopScope(canPop: !_busy, child: AlertDialog(
      title: Text(undone ? 'Undone categorization batch' : 'Review categorization batch'),
      content: SizedBox(width: 650, child: SingleChildScrollView(key: const Key('category-undo-scroll'),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Applied ${_time(r['atUtc'])} | ${r['count']} transactions'),
          Text('Selected dates: ${r['from']} to ${r['through']}'),
          const SizedBox(height: 12),
          if (undone) ...[
            Text('Undone ${_time(r['undoAtUtc'])}'), Text('Reason: ${r['undoReason'] ?? 'Unavailable'}'),
            const Text('This batch cannot be undone twice. The original history remains available.'),
          ] else if (!allowed) const Text('Undo is blocked for the whole batch. Review the reasons below. '
            'Later edits and reconciled records will not be overwritten.'),
          const SizedBox(height: 12),
          const Text('Names use current account/category labels. The saved rule version identifies the original decision.'),
          for (final row in LocalLedger.rows(r['changes'])) Card(child: Padding(padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['payee']} | ${row['date']}', style: Theme.of(context).textTheme.titleMedium),
              Text('${row['accountName']} | ${row['kind']} | ${money(row['amountMinor'])}'),
              Text('Original category: ${row['originalCategoryName']}'),
              Text('Applied category: ${row['appliedCategoryName']}'),
              Text('Current category: ${row['currentCategoryName']}'),
              Text('Rule: ${row['ruleName']} | Version ${row['ruleVersion']}'),
              if (!undone && row['blockedReason'] != null) Text(row['blockedReason'] as String),
            ]))),
          if (allowed) ...[
            const SizedBox(height: 12),
            const Text('Undo restores every original category shown above. Amounts, account balances, transaction count, '
              'import receipts and scheduled links remain unchanged. Budgets and reports will recalculate.'),
            const SizedBox(height: 8),
            const Text('Saved rules remain as configured. A later preview may propose applying them again.'),
            const SizedBox(height: 12),
            TextField(key: const Key('category-undo-reason'), controller: _reason, enabled: !_busy, maxLength: 250,
              decoration: const InputDecoration(labelText: 'Reason for undo', border: OutlineInputBorder()),
              onChanged: (_) => setState(() { _error = null; _reviewed = false; _operation = const Uuid().v4(); })),
            CheckboxListTile(key: const Key('category-undo-review'), value: _reviewed,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _busy ? null : (v) => setState(() { _reviewed = v == true; _operation = const Uuid().v4(); }),
              title: const Text('Restore the original categories for the complete batch. I reviewed the budget and report effects.')),
          ],
          if (_error != null) Text(_error!, key: const Key('category-undo-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]))),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Close')),
        if (allowed) FilledButton(key: const Key('category-undo-submit'), onPressed: _busy ? null : _undo,
          child: Text(_busy ? 'Restoring categories...' : 'Undo this batch'))],
    ));
  }
}
