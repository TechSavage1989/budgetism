import 'dart:convert';
import 'package:flutter/material.dart';
import '../date_controls.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'ledger.dart';
import 'entry_controls.dart';

class LocalTransactionEditor extends StatefulWidget {
  const LocalTransactionEditor({required this.accounts, required this.categories,
    required this.onSave, this.onVoid, this.existing, this.history = const [], super.key});
  final List<Json> accounts, categories, history;
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
  final _payee = TextEditingController(), _amount = TextEditingController(), _notes = TextEditingController();
  final _payeeFocus = FocusNode(), _amountFocus = FocusNode();
  final _splits = <_Split>[];
  late final List<Json> _history;
  late String _account;
  String _kind = 'expense';
  String? _counterparty;
  DateTime _date = DateTime.now();
  bool _split = false, _busy = false, _picking = false;
  String? _error, _lastPayload, _saveOperation;
  int _savedCount = 0;
  bool get _blocked => _busy || _picking;
  @override
  void initState() {
    super.initState();
    _history = widget.history.map(LocalLedger.clone).toList();
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
    _payee.dispose(); _amount.dispose(); _notes.dispose(); _payeeFocus.dispose(); _amountFocus.dispose();
    for (final split in _splits) { split.amount.dispose(); }
    super.dispose();
  }
  List<Json> get _choices => _kind == 'transfer'
    ? widget.accounts.where((a) => a['id'] != _account).toList()
    : widget.categories.where((c) => c['kind'] == (_kind == 'income' ? 'Income' : 'Expense')).toList();
  String? _validChoice(String? id) {
    if (id != null) return _choices.any((c) => c['id'] == id) ? id : null;
    return _kind == 'transfer' || _choices.isEmpty ? null : _choices.first['id'] as String;
  }
  String get _day => FinanceDates.format(_date);
  Future<void> _save({bool another = false}) async {
    if (_blocked || (another && widget.existing != null)) return;
    _payeeFocus.unfocus();
    setState(() { _busy = true; _error = null; });
    try {
      final amount = parseMinor(_amount.text);
      if (amount <= 0) throw const FormatException('Amount must be greater than zero.');
      final target = _validChoice(_counterparty);
      if (target == null && (!_split || _kind == 'transfer')) {
        throw FormatException(_kind == 'transfer' ? 'Choose the destination account before saving this transfer.' : 'Choose a category.');
      }
      final parts = _split && _kind != 'transfer' ? <Json>[
        for (final line in _splits) {'categoryId': _validChoice(line.category), 'amountMinor': parseMinor(line.amount.text)}
      ] : <Json>[];
      if (_split && _kind != 'transfer' && (parts.length < 2 || parts.fold<int>(0, (s, p) => s + (p['amountMinor'] as int)) != amount)) {
        throw const FormatException('Use at least two splits whose amounts equal the transaction total.');
      }
      final input = <String, dynamic>{
        if (widget.existing != null) ...{'id': widget.existing!['id'], 'expectedVersion': widget.existing!['version']},
        'kind': _kind, 'accountId': _account, 'counterpartyAccountId': target,
        'amountMinor': amount, 'currency': 'USD', 'effectiveDate': _day,
        'payee': _payee.text.trim(), 'notes': _notes.text.trim(), 'splits': parts};
      final fingerprint = jsonEncode(input);
      if (_lastPayload != fingerprint) {
        _lastPayload = fingerprint; _saveOperation = const Uuid().v4();
      }
      final request = {...input, 'operationId': _saveOperation!};
      await widget.onSave(request);
      if (!mounted) return;
      if (!another) { Navigator.pop(context, true); return; }
      setState(() {
        _history.add({...request, 'id': _saveOperation!, 'voided': false});
        _savedCount++;
        _counterparty = _kind == 'transfer' || _split ? null : target;
        _split = false;
        for (final part in _splits) { part.amount.dispose(); }
        _splits.clear(); _payee.clear(); _amount.clear(); _notes.clear();
        _lastPayload = null; _saveOperation = null;
      });
      _amountFocus.requestFocus();
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _chooseDate() async {
    if (_blocked) return;
    setState(() => _picking = true);
    try {
      final value = await chooseFinanceDate(context, value: _day, label: 'Transaction date');
      if (value != null && mounted) setState(() => _date = value);
    } finally { if (mounted) setState(() => _picking = false); }
  }
  Future<void> _void() async {
    if (_blocked) return;
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
  Widget _choice(String key, String label, String? value, List<Json> options, ValueChanged<String> changed) =>
    SearchableFinanceChoice(key: Key(key), label: label, value: value,
      options: {for (final item in options) item['id'] as String: item['name'] as String},
      enabled: !_blocked, onChanged: (v) => setState(() { changed(v); _error = null; }));
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_blocked, child: AlertDialog(
    title: Text(widget.existing == null ? 'New transaction' : 'Edit transaction'),
    content: SizedBox(width: 520, child: SingleChildScrollView(key: const Key('entry-scroll'), child: AbsorbPointer(absorbing: _blocked,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_savedCount > 0) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(
          'Saved $_savedCount ${_savedCount == 1 ? 'transaction' : 'transactions'}. Ready for another entry. Closing will not undo saved entries.',
          key: const Key('entry-saved'), style: Theme.of(context).textTheme.bodyMedium)),
        DropdownButtonFormField<String>(key: const Key('entry-kind'), initialValue: _kind,
          isExpanded: true, decoration: const InputDecoration(labelText: 'Transaction type', border: OutlineInputBorder()),
          items: const [DropdownMenuItem(value: 'expense', child: Text('Expense')),
            DropdownMenuItem(value: 'income', child: Text('Income')),
            DropdownMenuItem(value: 'transfer', child: Text('Transfer / card payment'))],
          onChanged: (v) => setState(() { _kind = v!; _counterparty = null; _split = false; _payeeFocus.unfocus(); })),
        const SizedBox(height: 12),
        _choice('entry-account', _kind == 'income' ? 'Receiving account' : 'From / primary account', _account,
          widget.accounts, (v) { _account = v; if (_kind == 'transfer') _counterparty = null; }),
        const SizedBox(height: 12),
        if (!_split || _kind == 'transfer') _choice('entry-category', _kind == 'transfer' ? 'To account' : 'Category',
          _validChoice(_counterparty), _choices, (v) => _counterparty = v),
        const SizedBox(height: 12),
        TextField(key: const Key('entry-amount'), controller: _amount, focusNode: _amountFocus,
          onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (USD)', border: OutlineInputBorder())),
        if (_kind != 'transfer') SwitchListTile(key: const Key('entry-split'), contentPadding: EdgeInsets.zero,
          title: const Text('Split across categories'), value: _split, onChanged: (v) => setState(() {
            _split = v;
            if (v && _splits.isEmpty) { _splits.addAll([_Split(_validChoice(_counterparty), ''), _Split(_validChoice(null), '')]); }
          })),
        if (_split && _kind != 'transfer') ...[
          for (var i = 0; i < _splits.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [
            _choice('entry-split-category-$i', 'Category ${i + 1}', _validChoice(_splits[i].category), _choices,
              (v) => _splits[i].category = v),
            const SizedBox(height: 8), Row(children: [Expanded(child: TextField(key: Key('entry-split-amount-$i'),
              controller: _splits[i].amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()))),
              IconButton(tooltip: 'Remove split', onPressed: _splits.length <= 2 ? null : () => setState(() { _splits.removeAt(i).amount.dispose(); }),
                icon: const Icon(Icons.remove_circle_outline)),
            ]),
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
        PayeeField(controller: _payee, focusNode: _payeeFocus, history: _history, kind: _kind, enabled: !_blocked),
        Wrap(spacing: 8, runSpacing: 4, children: [
          OutlinedButton.icon(onPressed: _blocked ? null : _chooseDate,
            icon: const Icon(Icons.calendar_month_outlined), label: Text(_day)),
          TextButton(onPressed: _blocked ? null : () => setState(() => _date = FinanceDates.day(DateTime.now())), child: const Text('Today')),
          TextButton(onPressed: _blocked ? null : () => setState(() => _date = FinanceDates.shift(DateTime.now(), -1)), child: const Text('Yesterday')),
        ]),
        const SizedBox(height: 12),
        TextField(key: const Key('entry-notes'), controller: _notes, maxLength: 500, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
        if (widget.existing == null) const Text('Save and add another keeps the account, type, date and ordinary category for this entry session only. '
          'Amounts, payee, notes, splits and transfer destinations are cleared.'),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, key: const Key('entry-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])))),
    actions: [
      if (widget.existing != null && widget.onVoid != null) TextButton(onPressed: _blocked ? null : _void, child: const Text('Void transaction')),
      TextButton(onPressed: _blocked ? null : () => Navigator.pop(context, _savedCount > 0 ? true : null),
        child: Text(_savedCount > 0 ? 'Close' : 'Cancel')),
      if (widget.existing == null) OutlinedButton(key: const Key('entry-save-another'),
        onPressed: _blocked ? null : () => _save(another: true), child: const Text('Save and add another')),
      FilledButton(key: const Key('entry-save'), onPressed: _blocked ? null : () => _save(), child: const Text('Save transaction')),
    ],
  ));
}
