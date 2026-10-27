import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'ledger.dart';

class LocalTransactionEditor extends StatefulWidget {
  const LocalTransactionEditor({required this.accounts, required this.categories,
    required this.onSave, this.onVoid, this.existing, super.key});
  final List<Json> accounts;
  final List<Json> categories;
  final Json? existing;
  final Future<void> Function(Json) onSave;
  final Future<void> Function(Json)? onVoid;
  @override
  State<LocalTransactionEditor> createState() => _LocalTransactionEditorState();
}
class _Split {
  _Split(this.category, String amount) : amount = TextEditingController(text: amount);
  String? category;
  final TextEditingController amount;
}
class _LocalTransactionEditorState extends State<LocalTransactionEditor> {
  final _payee = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final _splits = <_Split>[];
  late String _account;
  String _kind = 'expense';
  String? _counterparty;
  DateTime _date = DateTime.now();
  bool _split = false;
  bool _busy = false;
  String? _error;
  final _saveOperation = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _account = t?['accountId'] as String? ?? widget.accounts.first['id'] as String;
    if (t != null) {
      _kind = t['kind'] as String; _counterparty = t['counterpartyAccountId'] as String?;
      _payee.text = t['payee'] as String; _notes.text = t['notes'] as String;
      _amount.text = decimalAmount(t['amountMinor'] as int); _date = DateTime.parse(t['effectiveDate'] as String);
      final parts = LocalLedger.rows(t['splits'] ?? []);
      _split = parts.isNotEmpty;
      for (final p in parts) { _splits.add(_Split(p['categoryId'] as String, decimalAmount(p['amountMinor'] as int))); }
    }
  }
  @override
  void dispose() {
    _payee.dispose(); _amount.dispose(); _notes.dispose();
    for (final split in _splits) { split.amount.dispose(); }
    super.dispose();
  }
  List<Json> get _choices => _kind == 'transfer'
    ? widget.accounts.where((a) => a['id'] != _account).toList()
    : widget.categories.where((c) => c['kind'] == (_kind == 'income' ? 'Income' : 'Expense')).toList();
  String? _validChoice(String? id) => _choices.any((c) => c['id'] == id)
    ? id : (_choices.isEmpty ? null : _choices.first['id'] as String);
  String get _day => _date.toIso8601String().substring(0, 10);
  Future<void> _save() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final amount = parseMinor(_amount.text);
      if (amount <= 0) throw const FormatException('Amount must be greater than zero.');
      final parts = _split && _kind != 'transfer' ? <Json>[
        for (final line in _splits) {'categoryId': _validChoice(line.category), 'amountMinor': parseMinor(line.amount.text)}
      ] : <Json>[];
      if (_split && _kind != 'transfer' && (parts.length < 2 || parts.fold<int>(0, (s, p) => s + (p['amountMinor'] as int)) != amount)) {
        throw const FormatException('Use at least two splits whose amounts equal the transaction total.');
      }
      await widget.onSave({'operationId': _saveOperation,
        if (widget.existing != null) ...{'id': widget.existing!['id'], 'expectedVersion': widget.existing!['version']},
        'kind': _kind, 'accountId': _account, 'counterpartyAccountId': _validChoice(_counterparty),
        'amountMinor': amount, 'currency': 'USD', 'effectiveDate': _day,
        'payee': _payee.text.trim(), 'notes': _notes.text.trim(), 'splits': parts});
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _busy = false; _error = error.toString(); }); }
  }
  Future<void> _void() async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Void transaction?'), content: const Text('Remove this transaction from balances and spending. Its previous values remain in the local audit history.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Void transaction'))]));
    if (yes != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onVoid!({'operationId': const Uuid().v4(), 'id': widget.existing!['id'], 'expectedVersion': widget.existing!['version']});
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _busy = false; _error = error.toString(); }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: Text(widget.existing == null ? 'New transaction' : 'Edit transaction'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: AbsorbPointer(absorbing: _busy,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(initialValue: _kind,
          decoration: const InputDecoration(labelText: 'Transaction type', border: OutlineInputBorder()),
          items: const [DropdownMenuItem(value: 'expense', child: Text('Expense')),
            DropdownMenuItem(value: 'income', child: Text('Income')),
            DropdownMenuItem(value: 'transfer', child: Text('Transfer / card payment'))],
          onChanged: (v) => setState(() { _kind = v!; _counterparty = null; _split = false; })),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _account,
          decoration: InputDecoration(labelText: _kind == 'income' ? 'Receiving account' : 'From / primary account', border: const OutlineInputBorder()),
          items: widget.accounts.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text(a['name'] as String))).toList(),
          onChanged: (v) => setState(() { _account = v!; _counterparty = null; })),
        const SizedBox(height: 12),
        if (!_split || _kind == 'transfer') DropdownButtonFormField<String>(key: ValueKey('counter:$_kind:$_account'),
          initialValue: _validChoice(_counterparty),
          decoration: InputDecoration(labelText: _kind == 'transfer' ? 'To account' : 'Category', border: const OutlineInputBorder()),
          items: _choices.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
          onChanged: (v) => setState(() => _counterparty = v)),
        const SizedBox(height: 12),
        TextField(controller: _amount, onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (USD)', border: OutlineInputBorder())),
        if (_kind != 'transfer') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Split across categories'), value: _split,
          onChanged: (v) => setState(() {
            _split = v;
            if (v && _splits.isEmpty) { _splits.addAll([_Split(_validChoice(_counterparty), ''), _Split(_validChoice(null), '')]); }
          })),
        if (_split && _kind != 'transfer') ...[
          for (var i = 0; i < _splits.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            Expanded(flex: 3, child: DropdownButtonFormField<String>(key: ValueKey('split:$_kind:$i:${_splits[i].category}'),
              isExpanded: true, initialValue: _validChoice(_splits[i].category),
              decoration: InputDecoration(labelText: 'Category ${i + 1}', border: const OutlineInputBorder()),
              items: _choices.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _splits[i].category = v))),
            const SizedBox(width: 8), Expanded(flex: 2, child: TextField(controller: _splits[i].amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()))),
            IconButton(tooltip: 'Remove split', onPressed: _splits.length <= 2 ? null : () => setState(() { _splits.removeAt(i).amount.dispose(); }),
              icon: const Icon(Icons.remove_circle_outline)),
          ])),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _splits.length >= 50 ? null : () => setState(() => _splits.add(_Split(_validChoice(null), ''))),
            icon: const Icon(Icons.add), label: const Text('Add split'))),
          Builder(builder: (_) {
            try {
              final remaining = parseMinor(_amount.text) - _splits.fold<int>(0, (s, p) => s + parseMinor(p.amount.text.isEmpty ? '0' : p.amount.text));
              return Text('Unallocated: ${money(remaining)}');
            } catch (_) { return const Text('Enter amounts to calculate the remaining allocation.'); }
          }),
          const SizedBox(height: 12),
        ],
        TextField(controller: _payee, maxLength: 150, decoration: InputDecoration(
          labelText: _kind == 'transfer' ? 'Description' : 'Payee', border: const OutlineInputBorder())),
        OutlinedButton.icon(onPressed: () async {
          final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(1900), lastDate: DateTime(2100));
          if (d != null && mounted) setState(() => _date = d);
        }, icon: const Icon(Icons.calendar_today_outlined), label: Text(_day)),
        const SizedBox(height: 12),
        TextField(controller: _notes, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])))),
    actions: [
      if (widget.existing != null && widget.onVoid != null) TextButton(onPressed: _busy ? null : _void, child: const Text('Void transaction')),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('Save transaction')),
    ],
  ));
}
