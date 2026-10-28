import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'ledger.dart';
import 'local_api.dart';
import 'category_history_widgets.dart';

Future<void> showCategoryRules(BuildContext context, LocalFinanceApi api) async {
  await api.snapshot();
  if (!context.mounted) return;
  await showDialog<void>(context: context, barrierDismissible: false,
    builder: (_) => Dialog.fullscreen(child: CategoryRulesPage(
      snapshot: () => api.vault.ledger.snapshot(includeVoided: true),
      onSave: api.saveCategoryRule, onApply: api.applyCategoryRules,
      onHistory: () => showCategoryHistory(context, api),
      onRefresh: () async { await api.snapshot(); },
    )));
}

class CategoryRulesPage extends StatefulWidget {
  const CategoryRulesPage({super.key, required this.snapshot, required this.onSave,
    required this.onApply, this.onRefresh, this.onHistory});
  final Json Function() snapshot;
  final Future<void> Function(Json) onSave, onApply;
  final Future<void> Function()? onRefresh, onHistory;
  @override
  State<CategoryRulesPage> createState() => _CategoryRulesPageState();
}

class _CategoryRulesPageState extends State<CategoryRulesPage> {
  late Json _data;
  late final TextEditingController _from, _through;
  List<Json>? _preview;
  final Set<String> _selected = {};
  int _visible = 100;
  bool _busy = false, _reviewed = false;
  String? _error, _notice;
  String _operation = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _data = widget.snapshot();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _from = TextEditingController(text: '${today.substring(0, 7)}-01');
    _through = TextEditingController(text: today);
  }
  @override
  void dispose() { _from.dispose(); _through.dispose(); super.dispose(); }
  void _invalidate() {
    _preview = null; _selected.clear(); _reviewed = false; _visible = 100;
    _operation = const Uuid().v4(); _error = null; _notice = null;
  }
  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await widget.onRefresh?.call();
      if (mounted) setState(() { _data = widget.snapshot(); _invalidate(); });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _history() async {
    if (_busy || widget.onHistory == null) return;
    setState(() { _busy = true; _invalidate(); });
    try {
      await widget.onHistory!();
      await widget.onRefresh?.call();
      if (mounted) setState(() => _data = widget.snapshot());
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _edit([Json? rule]) async {
    final saved = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => CategoryRuleEditor(data: _data, existing: rule, onSave: widget.onSave));
    if (saved == true && mounted) {
      setState(() {
        _data = widget.snapshot(); _invalidate(); _notice = 'Rule saved. No transactions were changed.';
      });
    }
  }
  void _generate() {
    try {
      final changes = CategoryRules.preview(_data, from: _from.text.trim(), through: _through.text.trim());
      setState(() { _invalidate(); _preview = changes; });
    } catch (e) { setState(() { _invalidate(); _error = e.toString(); }); }
  }
  void _select(String id, bool value) {
    setState(() {
      _error = null; _reviewed = false; _operation = const Uuid().v4();
      if (value && _selected.length >= CategoryRules.maxBatch) {
        _error = 'Apply at most ${CategoryRules.maxBatch} changes at a time.';
      } else if (value) { _selected.add(id); } else { _selected.remove(id); }
    });
  }
  Future<void> _apply() async {
    if (_busy) return;
    if (!_reviewed || _selected.isEmpty) {
      setState(() => _error = 'Select changes and confirm their category and budget effects first.');
      return;
    }
    final request = <String, dynamic>{'operationId': _operation, 'expectedRevision': _data['cursor'],
      'from': _from.text.trim(), 'through': _through.text.trim(), 'confirmReviewed': _reviewed,
      'selections': _preview!.where((p) => _selected.contains(p['transactionId'])).toList()};
    final count = _selected.length;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onApply(request);
      if (mounted) {
        setState(() {
          _data = widget.snapshot(); _invalidate();
          _notice = '$count transactions recategorized. Account balances and transaction count are unchanged.';
        });
      }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final rules = CategoryRules.ordered(_data);
    final names = {for (final item in [...LocalLedger.rows(_data['accounts']), ...LocalLedger.rows(_data['categories'])])
      item['id']: item['name'] as String};
    final transactions = {for (final t in LocalLedger.rows(_data['transactions'])) t['id']: t};
    final ruleMap = {for (final r in rules) r['id']: r};
    return PopScope(canPop: !_busy, child: Scaffold(
      appBar: AppBar(title: const Text('Categorization rules'), automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Refresh rules', onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh)), IconButton(tooltip: 'Close rules',
          onPressed: _busy ? null : () => Navigator.of(context).pop(), icon: const Icon(Icons.close))]),
      body: ListView(key: const Key('rules-scroll'), padding: const EdgeInsets.all(20), children: [
        const Text('Local rules suggest categories for recorded transactions. Nothing runs automatically.'),
        const SizedBox(height: 8),
        const Text('Lowest priority number wins. Reconciled, split, transfer and voided transactions are excluded. '
          'Applying changes can move spending between budgets, but never moves money.'),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_error!, key: const Key('rules-error'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_notice != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_notice!)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _busy || rules.length >= CategoryRules.maxRules ? null : () => _edit(),
            icon: const Icon(Icons.add), label: const Text('Add rule')),
          if (widget.onHistory != null) OutlinedButton.icon(onPressed: _busy ? null : _history,
            icon: const Icon(Icons.history), label: const Text('History')),
        ]),
        if (rules.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No saved rules yet.')),
        for (final rule in rules) Card(child: ListTile(
          title: Text('${rule['priority']}. ${rule['name']} (${rule['enabled'] == true ? 'Enabled' : 'Disabled'})'),
          subtitle: Text('${rule['kind']} | Payee ${rule['mode']}: "${rule['pattern']}"\n'
            'Set category: ${names[rule['categoryId']]}'),
          trailing: IconButton(tooltip: 'Edit ${rule['name']}', onPressed: _busy ? null : () => _edit(rule),
            icon: const Icon(Icons.edit_outlined)),
        )),
        const Divider(height: 32),
        Text('Preview changes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(key: const Key('rules-from'), controller: _from, enabled: !_busy,
          decoration: const InputDecoration(labelText: 'From (YYYY-MM-DD)', border: OutlineInputBorder()),
          onChanged: (_) => setState(_invalidate)),
        const SizedBox(height: 12),
        TextField(key: const Key('rules-through'), controller: _through, enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Through (YYYY-MM-DD)', border: OutlineInputBorder()),
          onChanged: (_) => setState(_invalidate)),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
          onPressed: _busy ? null : _generate, icon: const Icon(Icons.preview_outlined),
          label: const Text('Generate preview'))),
        if (_preview != null) ...[
          const SizedBox(height: 12),
          Text('${_preview!.length} proposed changes. ${_selected.length} selected. Nothing is saved until you apply.'),
          if (_preview!.isEmpty) const Text('No category changes match this date range. Protected or already-correct entries are not included.'),
          for (final proposal in _preview!.take(_visible)) Builder(builder: (context) {
            final t = transactions[proposal['transactionId']]!;
            final rule = ruleMap[proposal['ruleId']]!;
            return CheckboxListTile(key: ValueKey('proposal-${t['id']}'),
              value: _selected.contains(t['id']), controlAffinity: ListTileControlAffinity.leading,
              onChanged: _busy ? null : (v) => _select(t['id'] as String, v == true),
              title: Text('${t['effectiveDate']} | ${t['payee']} | ${money(t['amountMinor'])}'),
              subtitle: Text('${names[t['accountId']]}\nCurrent: ${names[proposal['fromCategoryId']]}\n'
                'Proposed: ${names[proposal['categoryId']]}\nRule: ${rule['name']} (priority ${rule['priority']})'),
            );
          }),
          if (_preview!.length > _visible) TextButton(onPressed: _busy ? null : () => setState(() => _visible += 100),
            child: const Text('Show 100 more')),
          if (_preview!.isNotEmpty) ...[
            CheckboxListTile(key: const Key('rules-review'), value: _reviewed,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _busy ? null : (v) => setState(() { _reviewed = v == true; _operation = const Uuid().v4(); }),
              title: const Text('I reviewed the selected category changes and their budget/report effects.')),
            Align(alignment: Alignment.centerLeft, child: FilledButton(
              key: const Key('rules-apply'), onPressed: _busy ? null : _apply,
              child: Text(_busy ? 'Saving...' : 'Apply selected (${_selected.length})'))),
          ],
        ],
      ]),
    ));
  }
}

class CategoryRuleEditor extends StatefulWidget {
  const CategoryRuleEditor({super.key, required this.data, required this.onSave, this.existing});
  final Json data;
  final Json? existing;
  final Future<void> Function(Json) onSave;
  @override
  State<CategoryRuleEditor> createState() => _CategoryRuleEditorState();
}

class _CategoryRuleEditorState extends State<CategoryRuleEditor> {
  late final TextEditingController _name, _pattern, _priority, _minimum, _maximum;
  late String _kind, _mode, _source, _account, _category, _fromCategory;
  bool _enabled = true, _upgrade = false, _busy = false;
  String? _error;
  String _operation = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    final priorities = CategoryRules.ordered(widget.data).map((r) => r['priority'] as int).toSet();
    var priority = 10;
    while (priorities.contains(priority) && priority < 9999) { priority++; }
    _name = TextEditingController(text: r?['name'] as String? ?? '');
    _pattern = TextEditingController(text: r?['pattern'] as String? ?? '');
    _priority = TextEditingController(text: '${r?['priority'] ?? priority}');
    _minimum = TextEditingController(text: r?['minimumMinor'] == null ? '' : decimalAmount(r!['minimumMinor'] as int));
    _maximum = TextEditingController(text: r?['maximumMinor'] == null ? '' : decimalAmount(r!['maximumMinor'] as int));
    _kind = r?['kind'] as String? ?? 'expense'; _mode = r?['mode'] as String? ?? 'contains';
    _source = r?['source'] as String? ?? 'all'; _account = r?['accountId'] as String? ?? '';
    _fromCategory = r?['fromCategoryId'] as String? ?? ''; _category = r?['categoryId'] as String? ?? '';
    _enabled = r?['enabled'] as bool? ?? true;
  }
  @override
  void dispose() {
    for (final c in [_name, _pattern, _priority, _minimum, _maximum]) { c.dispose(); }
    super.dispose();
  }
  void _changed() { _operation = const Uuid().v4(); _error = null; }
  Future<void> _save() async {
    if (_busy) return;
    try {
      final input = <String, dynamic>{'operationId': _operation, 'expectedRevision': widget.data['cursor'],
        if (widget.existing != null) ...{'id': widget.existing!['id'], 'expectedVersion': widget.existing!['version']},
        'name': _name.text.trim(), 'pattern': _pattern.text.trim(), 'priority': int.tryParse(_priority.text.trim()),
        'kind': _kind, 'mode': _mode, 'source': _source, 'enabled': _enabled,
        'accountId': _account.isEmpty ? null : _account, 'categoryId': _category,
        'fromCategoryId': _fromCategory.isEmpty ? null : _fromCategory,
        'minimumMinor': _minimum.text.trim().isEmpty ? null : parseMinor(_minimum.text),
        'maximumMinor': _maximum.text.trim().isEmpty ? null : parseMinor(_maximum.text),
        'confirmRuleUpgrade': _upgrade};
      setState(() { _busy = true; _error = null; });
      await widget.onSave(input);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Widget _text(String key, String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 12), child: TextField(key: Key(key), controller: controller,
      enabled: !_busy, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: (_) => setState(_changed)));
  Widget _choice(String key, String label, String value, Map<String, String> items, void Function(String) change) => Padding(
    padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(
      key: ValueKey('$key:$value'), initialValue: value, isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [for (final item in items.entries) DropdownMenuItem(value: item.key,
        child: Text(item.value, overflow: TextOverflow.ellipsis))],
      onChanged: _busy ? null : (v) => setState(() { change(v!); _changed(); })));
  @override
  Widget build(BuildContext context) {
    final categories = <String, String>{for (final c in LocalLedger.rows(widget.data['categories'])
      .where((c) => c['kind'] == (_kind == 'expense' ? 'Expense' : 'Income'))) c['id'] as String: c['name'] as String};
    return PopScope(canPop: !_busy, child: AlertDialog(
      title: Text(widget.existing == null ? 'Add categorization rule' : 'Edit categorization rule'),
      content: SizedBox(width: 580, child: SingleChildScrollView(key: const Key('rule-editor-scroll'), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Saving a rule does not change transactions. Preview and confirm changes separately.'),
          const SizedBox(height: 12),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!,
            key: const Key('rule-error'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
          _text('rule-name', 'Rule name', _name), _text('rule-priority', 'Priority (1 first, 9999 last)', _priority),
          _choice('rule-kind', 'Transaction type', _kind, {'expense': 'Expense', 'income': 'Income'},
            (v) { _kind = v; _category = ''; _fromCategory = ''; }),
          _choice('rule-mode', 'Payee match (case-insensitive)', _mode,
            {'contains': 'Contains', 'exact': 'Exact match', 'prefix': 'Starts with'}, (v) => _mode = v),
          _text('rule-pattern', 'Payee text', _pattern),
          _choice('rule-account', 'Account', _account, {'': 'All accounts',
            for (final a in LocalLedger.rows(widget.data['accounts'])) a['id'] as String: a['name'] as String}, (v) => _account = v),
          _choice('rule-source', 'Transaction source', _source,
            {'all': 'All recorded entries', 'statement': 'Statement-linked entries', 'manual': 'Entries without a statement link'}, (v) => _source = v),
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Statement-linked includes imported entries and manual entries matched to a CSV row.')),
          _choice('rule-from-category', 'Only when current category is', _fromCategory, {'': 'Any category', ...categories}, (v) => _fromCategory = v),
          _text('rule-minimum', 'Minimum amount (USD, optional)', _minimum),
          _text('rule-maximum', 'Maximum amount (USD, optional)', _maximum),
          _choice('rule-category', 'Set category', _category, {'': 'Choose a category', ...categories}, (v) => _category = v),
          SwitchListTile(title: const Text('Rule enabled'), value: _enabled,
            onChanged: _busy ? null : (v) => setState(() { _enabled = v; _changed(); })),
          if ((widget.data['schema'] as int) < LocalLedger.categoryRuleSchema) CheckboxListTile(
            key: const Key('rule-upgrade'), value: _upgrade, controlAffinity: ListTileControlAffinity.leading,
            onChanged: _busy ? null : (v) => setState(() { _upgrade = v == true; _changed(); }),
            title: const Text('I exported a backup and approve the saved-rules format upgrade. Older builds cannot open this workspace afterward.')),
        ],
      ))),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(key: const Key('rule-save'), onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving...' : 'Save rule'))],
    ));
  }
}
