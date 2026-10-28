import 'package:flutter/material.dart';
import '../money.dart';
import 'ledger.dart';
import 'transaction_register.dart';

class TransactionRegisterPanel extends StatefulWidget {
  const TransactionRegisterPanel({super.key, required this.readSnapshot,
    this.initialFilter = const RegisterFilter(), this.onFilterChanged, this.onEdit, this.onImport});
  final Json Function() readSnapshot;
  final RegisterFilter initialFilter;
  final ValueChanged<RegisterFilter>? onFilterChanged;
  final Future<void> Function(Json)? onEdit;
  final VoidCallback? onImport;
  @override
  State<TransactionRegisterPanel> createState() => _TransactionRegisterPanelState();
}

class _TransactionRegisterPanelState extends State<TransactionRegisterPanel> {
  late RegisterFilter _filter;
  late final TextEditingController _query, _from, _through, _minimum, _maximum;
  int _limit = 100;
  bool _opening = false;
  @override
  void initState() {
    super.initState(); _filter = widget.initialFilter;
    _query = TextEditingController(text: _filter.query);
    _from = TextEditingController(text: _filter.from); _through = TextEditingController(text: _filter.through);
    _minimum = TextEditingController(text: _filter.minimum); _maximum = TextEditingController(text: _filter.maximum);
  }
  @override
  void dispose() {
    for (final c in [_query, _from, _through, _minimum, _maximum]) { c.dispose(); }
    super.dispose();
  }
  void _change(RegisterFilter value) {
    setState(() { _filter = value; _limit = 100; });
    widget.onFilterChanged?.call(value);
  }
  void _reset() {
    for (final c in [_query, _from, _through, _minimum, _maximum]) { c.clear(); }
    _change(const RegisterFilter());
  }
  RegisterEntry? _latest(String id) {
    final snapshot = widget.readSnapshot();
    final transactions = LocalLedger.rows(snapshot['transactions']).where((t) => t['id'] == id).toList();
    return TransactionRegister.calculate({...snapshot, 'transactions': transactions},
      _filter.copyWith(query: '', categoryId: '', kind: 'all', status: 'all', source: 'all',
        from: '', through: '', minimum: '', maximum: '')).entries.firstOrNull;
  }
  Future<void> _inspect(String id) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final entry = _latest(id);
      if (entry == null) throw const FormatException('This record is no longer available. Refresh the workspace.');
      final edit = await showDialog<bool>(context: context, builder: (_) => RegisterDetails(
        entry: entry, selectedAccount: _filter.accountId, allowEdit: widget.onEdit != null));
      if (edit == true && mounted && widget.onEdit != null) {
        final latest = _latest(id);
        if (latest == null || !latest.canEdit) {
          throw const FormatException('This record is now protected or unavailable. Refresh before editing.');
        }
        await widget.onEdit!(latest.transaction);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => _opening = false); }
  }
  Future<void> _pickDate(bool from) async {
    final value = from ? _from.text : _through.text;
    final parsed = DateTime.tryParse(value);
    final initial = parsed != null && parsed.year >= 1900 && parsed.year <= 9999 ? parsed : DateTime.now();
    final selected = await showDatePicker(context: context, initialDate: initial,
      firstDate: DateTime(1900), lastDate: DateTime(9999, 12, 31));
    if (selected == null || !mounted) return;
    final text = selected.toIso8601String().substring(0, 10);
    (from ? _from : _through).text = text;
    _change(from ? _filter.copyWith(from: text) : _filter.copyWith(through: text));
  }
  Widget _choice(String key, String label, String value, Map<String, String> options, ValueChanged<String> change) {
    final items = {...options, if (!options.containsKey(value)) value: 'Unavailable selection (reset filters)'};
    return DropdownButtonFormField<String>(key: ValueKey('$key:$value'), initialValue: value,
      isExpanded: true, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [for (final item in items.entries) DropdownMenuItem(value: item.key,
        child: Text(item.value, overflow: TextOverflow.ellipsis))], onChanged: (v) { if (v != null) change(v); });
  }
  Widget _text(String key, String label, TextEditingController controller, ValueChanged<String> change, {bool? date}) =>
    TextField(key: Key(key), controller: controller, onChanged: change, maxLength: 40,
      decoration: InputDecoration(labelText: label, counterText: '', border: const OutlineInputBorder(),
        suffixIcon: date == null ? null : IconButton(tooltip: 'Choose $label',
          onPressed: () => _pickDate(date), icon: const Icon(Icons.calendar_today_outlined))));

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.readSnapshot();
    RegisterResult? result; String? error;
    try { result = TransactionRegister.calculate(snapshot, _filter); }
    catch (e) { error = e.toString(); }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 8, children: [
        Text('Transactions', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (widget.onImport != null) OutlinedButton.icon(onPressed: widget.onImport,
          icon: const Icon(Icons.file_upload_outlined), label: const Text('Import CSV')),
      ]),
      const SizedBox(height: 8),
      const Text('Recorded entries only, including future-dated records. Schedules are not transactions.'),
      const SizedBox(height: 16),
      TextField(key: const Key('register-query'), controller: _query, maxLength: 500,
        decoration: InputDecoration(labelText: 'Search payee, notes, account, or category',
          prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), counterText: '',
          suffixIcon: IconButton(tooltip: 'Clear search', onPressed: () { _query.clear(); _change(_filter.copyWith(query: '')); },
            icon: const Icon(Icons.clear))), onChanged: (v) => _change(_filter.copyWith(query: v))),
      const SizedBox(height: 6),
      const Text('All words must match. Use "quoted phrases" or -word to exclude a term. Search stays in this session.'),
      const SizedBox(height: 12),
      _choice('register-sort', 'Sort by whole transaction', _filter.sort, TransactionRegister.sorts,
        (v) => _change(_filter.copyWith(sort: v))),
      const SizedBox(height: 10),
      Card(child: ExpansionTile(key: const Key('register-filters'),
        initiallyExpanded: _filter.advancedCount > 0,
        title: Text('Filters (${_filter.advancedCount} active)'),
        childrenPadding: const EdgeInsets.all(12), children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth >= 620 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
            return Wrap(spacing: 16, runSpacing: 14, children: [
              for (final field in <Widget>[
                _choice('register-account', 'Account', _filter.accountId,
                  {'': 'All accounts', for (final a in LocalLedger.rows(snapshot['accounts'])) a['id'] as String: a['name'] as String},
                  (v) => _change(_filter.copyWith(accountId: v))),
                _choice('register-category', 'Category (includes split contributions)', _filter.categoryId,
                  {'': 'All categories', for (final c in LocalLedger.rows(snapshot['categories'])) c['id'] as String: '${c['name']} (${c['kind']})'},
                  (v) => _change(_filter.copyWith(categoryId: v))),
                _choice('register-kind', 'Transaction type', _filter.kind,
                  {'all': 'All types', 'income': 'Income', 'expense': 'Expense', 'transfer': 'Transfer / card payment'},
                  (v) => _change(_filter.copyWith(kind: v))),
                _choice('register-status', 'Reconciliation / record status', _filter.status, TransactionRegister.statuses,
                  (v) => _change(_filter.copyWith(status: v))),
                _choice('register-source', 'Statement link', _filter.source, TransactionRegister.sources,
                  (v) => _change(_filter.copyWith(source: v))),
                _text('register-from', 'From (YYYY-MM-DD)', _from, (v) => _change(_filter.copyWith(from: v)), date: true),
                _text('register-through', 'Through (YYYY-MM-DD)', _through, (v) => _change(_filter.copyWith(through: v)), date: false),
                _text('register-minimum', 'Minimum whole amount (USD)', _minimum, (v) => _change(_filter.copyWith(minimum: v))),
                _text('register-maximum', 'Maximum whole amount (USD)', _maximum, (v) => _change(_filter.copyWith(maximum: v))),
              ]) SizedBox(width: width, child: field),
            ]);
          }),
          const SizedBox(height: 12),
          const Text('Dates and amount limits are inclusive. Amounts are unsigned whole transaction values. '
            'With an account selected, statement-link and reconciliation filters refer to that account; otherwise they match either side.'),
        ])),
      TextButton.icon(key: const Key('register-reset'), onPressed: _reset,
        icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Reset search and filters')),
      if (error != null) Card(color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(padding: const EdgeInsets.all(14), child: Text(error, key: const Key('register-error')))),
      if (result != null) ..._results(result),
      const SizedBox(height: 90),
    ]);
  }

  List<Widget> _results(RegisterResult result) => [
    Text('${result.entries.length} matching transactions', key: const Key('register-count'),
      style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    Wrap(spacing: 12, runSpacing: 8, children: [
      _total('Matched income', result.income, 'register-income'),
      _total('Matched expenses', result.expenses, 'register-expenses'),
      _total('Transfers (not spending)', result.transfers, 'register-transfers'),
    ]),
    Text('Totals include every match, not just visible rows. ${result.voidedCount} voided records excluded from totals.'),
    if (_filter.categoryId.isNotEmpty) const Text('Income and expense totals use only the selected category contribution. Row amounts and amount filters use the whole transaction.'),
    const SizedBox(height: 12),
    if (result.entries.isEmpty) const Padding(padding: EdgeInsets.all(20),
      child: Text('No transactions match. Reset filters or adjust the search. No records were changed.')),
    for (final entry in result.entries.take(_limit)) Card(child: InkWell(
      key: ValueKey('register-entry-${entry.id}'), onTap: _opening ? null : () => _inspect(entry.id),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.payee.isEmpty ? entry.typeLabel : entry.payee, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium),
        Text('${entry.typeLabel}: ${entry.kind == 'income' ? '+' : entry.kind == 'expense' ? '-' : ''}${money(entry.amount)}'),
        Text('${entry.date} | ${entry.accountName} | ${entry.split ? 'Split: ' : ''}${entry.targetName}'),
        if (_filter.categoryId.isNotEmpty && entry.split) Text('Selected category: ${money(entry.contribution(_filter.categoryId))}'),
        Text('${entry.statusLabel}${entry.kind == 'transfer' && _filter.accountId.isEmpty && entry.statements.length == 1 ? ' on one account' : ''}'
          ' | ${entry.statementLinkedInScope ? 'Statement-linked' : 'No statement link'}'
          '${entry.scheduleName == null ? '' : ' | Scheduled link'}'),
        if (entry.voided) const Text('Voided: excluded from financial totals.'),
      ])))),
    if (result.entries.length > _limit) TextButton(key: const Key('register-more'),
      onPressed: () => setState(() => _limit += 100), child: const Text('Show 100 more')),
  ];
  Widget _total(String label, int amount, String key) => Card(child: Padding(
    padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label), Text(money(amount), key: Key(key), style: Theme.of(context).textTheme.titleLarge)])));
}

/// No mutation API: editing is an explicit handoff to the existing editor.
class RegisterDetails extends StatelessWidget {
  const RegisterDetails({super.key, required this.entry, required this.selectedAccount, required this.allowEdit});
  final RegisterEntry entry;
  final String selectedAccount;
  final bool allowEdit;
  @override
  Widget build(BuildContext context) {
    final t = entry.transaction;
    return AlertDialog(title: const Text('Transaction details'),
      content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(entry.payee.isEmpty ? '(No payee)' : entry.payee, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${entry.typeLabel} | ${entry.date}'),
          Text('Whole transaction: ${money(entry.amount)} USD'),
          Text('${entry.kind == 'transfer' ? 'From' : 'Account'}: ${entry.accountName}'),
          if (entry.kind == 'transfer') Text('To: ${entry.targetName}'),
          if (entry.voided) const Text('Voided record. It has no effect on current balances or totals.'),
          if (entry.contributions.isNotEmpty) ...[
            const Divider(), Text(entry.split ? 'Split category contributions' : 'Category'),
            for (final c in entry.contributions.entries) Text('${entry.categoryNames[c.key]}: ${money(c.value)}'),
          ],
          const Divider(), const Text('Notes'), SelectableText(entry.notes.isEmpty ? '(None)' : entry.notes),
          const Divider(), const Text('Statement links'),
          if (entry.receipts.isEmpty) const Text('No CSV receipt. This does not prove how the entry was originally created.'),
          for (final r in entry.receipts) Text('${r['fileName']} | Row ${r['rowNumber']} | ${r['action']}'
            '${(r['reference'] as String? ?? '').isEmpty ? '' : ' | Reference: ${r['reference']}'}'),
          const Divider(), const Text('Active reconciliation statements'),
          if (entry.statements.isEmpty) const Text('Not included in an active completed statement.'),
          for (final s in entry.statements) Text('${s.accountName} | Statement ending ${s.endDate}'),
          if (entry.statements.isNotEmpty) const Text('Reopen the applicable statements in Reconcile statements before editing. Transfers are protected while either account is reconciled.'),
          if (selectedAccount.isNotEmpty && !entry.reconciledInScope && entry.statements.isNotEmpty)
            const Text('This account is unreconciled, but the other account still protects the transaction.'),
          if (entry.scheduleName != null) ...[
            const Divider(), Text('Linked schedule: ${entry.scheduleName}'),
            Text('Occurrence ${(t['occurrenceIndex'] as int) + 1}. This is an existing transaction, not an extra planned payment.'),
          ],
          const Divider(), ExpansionTile(title: const Text('Record information'), children: [
            SelectableText('Transaction ID: ${entry.id}\nVersion: ${t['version']}\nCreated (UTC): ${t['createdUtc']}'),
          ]),
        ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')),
        if (allowEdit && entry.canEdit) FilledButton(key: const Key('register-edit'),
          onPressed: () => Navigator.pop(context, true), child: const Text('Edit transaction'))],
    );
  }
}
