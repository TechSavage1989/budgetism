import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'ledger.dart';
import 'schedules.dart';

/// Explicit, read-only suggestions. Saving attaches one existing transaction;
/// neither this dialog nor its filters can create or edit a financial posting.
class ScheduleMatchDialog extends StatefulWidget {
  const ScheduleMatchDialog({required this.occurrence, required this.snapshot,
    required this.onSave, super.key});
  final ScheduledOccurrence occurrence;
  final Json snapshot;
  final Future<void> Function(Json) onSave;
  @override
  State<ScheduleMatchDialog> createState() => _ScheduleMatchDialogState();
}

class _ScheduleMatchDialogState extends State<ScheduleMatchDialog> {
  final _search = TextEditingController();
  int _window = 7;
  bool _differentAmounts = false, _reviewed = false, _busy = false;
  String? _selectedId, _error;
  String _operationId = const Uuid().v4();

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _reset() {
    _selectedId = null; _reviewed = false; _error = null; _operationId = const Uuid().v4();
  }

  List<Json> get _candidates {
    final query = _search.text.trim().toLowerCase();
    return ScheduleMatching.candidates(widget.snapshot, widget.occurrence.schedule, widget.occurrence.dueDate,
      windowDays: _window, includeDifferentAmounts: _differentAmounts).where((t) =>
        query.isEmpty || '${t['payee']} ${t['notes']} ${t['effectiveDate']}'.toLowerCase().contains(query)).toList();
  }

  Future<void> _save() async {
    if (_busy) return;
    final matches = _candidates.where((t) => t['id'] == _selectedId).toList();
    if (!_reviewed || matches.length != 1) {
      setState(() => _error = 'Select one transaction and confirm that it is the same payment.');
      return;
    }
    final transaction = matches.single;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onSave({...widget.occurrence.command(_operationId),
        'transactionId': transaction['id'], 'expectedTransactionVersion': transaction['version'],
        'expectedRevision': widget.snapshot['cursor'], 'confirmMatch': true});
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = error.toString(); });
    }
  }

  String _allocation(Json t) {
    final names = {for (final c in LocalLedger.rows(widget.snapshot['categories'])) c['id']: c['name']};
    if (t['kind'] == 'transfer') {
      final accounts = {for (final a in LocalLedger.rows(widget.snapshot['accounts'])) a['id']: a['name']};
      return 'Transfer to ${accounts[t['counterpartyAccountId']]}';
    }
    final splits = LocalLedger.rows(t['splits'] ?? <Json>[]);
    if (splits.isEmpty) return 'Category: ${names[t['counterpartyAccountId']]}';
    return 'Split transaction: ${splits.map((s) => '${names[s['categoryId']]} ${money(s['amountMinor'])}').join('; ')}';
  }

  @override
  Widget build(BuildContext context) {
    final occurrence = widget.occurrence;
    final candidates = _candidates;
    final selected = candidates.where((t) => t['id'] == _selectedId).toList();
    final accounts = {for (final a in LocalLedger.rows(widget.snapshot['accounts'])) a['id']: a['name']};
    final categoryNames = {for (final c in LocalLedger.rows(widget.snapshot['categories'])) c['id']: c['name']};
    return PopScope(canPop: !_busy, child: AlertDialog(
      scrollable: true,
      title: const Text('Match existing transaction'),
      content: SizedBox(width: 640, child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(occurrence.name, style: Theme.of(context).textTheme.titleMedium),
          Text('${accounts[occurrence.schedule['accountId']]} | Due ${occurrence.dueDate} | Expected ${money(occurrence.amount)}'),
          Text(occurrence.schedule['kind'] == 'transfer'
              ? 'Scheduled destination: ${accounts[occurrence.schedule['counterpartyAccountId']]}'
              : 'Scheduled category: ${categoryNames[occurrence.schedule['counterpartyAccountId']]}'),
          const SizedBox(height: 10),
          const Text('Choose a payment already entered or imported. This settles this occurrence without creating a transaction. '
            'Actual amount, date, payee, categories, splits and balances stay unchanged.'),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(key: const ValueKey('match-range'), initialValue: _window, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Recorded date range around due date', border: OutlineInputBorder()),
            items: [for (final days in ScheduleMatching.windows) DropdownMenuItem(value: days,
              child: Text('Within $days days before or after', maxLines: 1, overflow: TextOverflow.ellipsis))],
            onChanged: _busy ? null : (value) => setState(() { _window = value!; _reset(); })),
          CheckboxListTile(key: const ValueKey('match-different-amounts'), contentPadding: EdgeInsets.zero,
            value: _differentAmounts, controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Include different amounts'),
            subtitle: const Text('For variable bills. Review the actual amount before linking.'),
            onChanged: _busy ? null : (value) => setState(() { _differentAmounts = value ?? false; _reset(); })),
          TextField(key: const ValueKey('match-search'), controller: _search, enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Find payee, notes or date', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(_reset)),
          const SizedBox(height: 10),
          Text('${candidates.length} eligible transaction${candidates.length == 1 ? '' : 's'}. '
            'Already linked, voided and different-account/type entries are excluded.'),
          if (candidates.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No eligible transactions. Widen the date range, include different amounts, or record the payment first.')),
          if (candidates.isNotEmpty) SizedBox(height: 200, child: ListView.builder(
            itemCount: candidates.length > 100 ? 100 : candidates.length,
            itemBuilder: (context, index) {
              final t = candidates[index]; final active = t['id'] == _selectedId;
              return Semantics(selected: active, button: true, child: ListTile(
                key: ValueKey('match-candidate-${t['id']}'), selected: active, enabled: !_busy,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                leading: Icon(active ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text('${t['payee'] == '' ? 'Transaction' : t['payee']}\n${money(t['amountMinor'])} | ${t['effectiveDate']}'),
                subtitle: Text(_allocation(t), maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: _busy ? null : () => setState(() {
                  _selectedId = t['id'] as String; _reviewed = false; _error = null; _operationId = const Uuid().v4();
                }),
              ));
            })),
          if (candidates.length > 100) const Text('Showing the first 100 results. Narrow the search to find another transaction.'),
          if (selected.isNotEmpty) ...[
            const Divider(),
            Text('Selected: ${money(selected.single['amountMinor'])} on ${selected.single['effectiveDate']}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(_allocation(selected.single)),
            if (selected.single['amountMinor'] != occurrence.amount)
              const Text('The actual amount differs from the schedule. The actual amount is kept.'),
            if (selected.single['effectiveDate'] != occurrence.dueDate)
              const Text('The actual date differs from the due date. The actual date is kept.'),
            CheckboxListTile(key: const ValueKey('match-review'), contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading, value: _reviewed,
              title: const Text('I confirm this is the same payment and have reviewed its amount, date and categories.'),
              onChanged: _busy ? null : (value) => setState(() => _reviewed = value ?? false)),
          ],
          const SizedBox(height: 10),
          const Text('Match the whole transaction to one occurrence only. This preview has no unlink action; review carefully.'),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ])),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('match-save'), onPressed: _busy ? null : _save,
          child: const Text('Link without new transaction'))],
    ));
  }
}
