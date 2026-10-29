import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'csv_import.dart';
import 'csv_profiles.dart';
import 'csv_rule_suggestions.dart';
import 'csv_rule_widgets.dart';
import 'import_profile_widgets.dart';
import 'ledger.dart';
import 'local_api.dart';

Future<void> showCsvImport(BuildContext context, LocalFinanceApi api) async {
  await api.snapshot();
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => CsvImportScreen(api: api), fullscreenDialog: true));
}

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({required this.api, this.chooseFile, super.key});
  final LocalFinanceApi api;
  final Future<XFile?> Function()? chooseFile;
  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  late Json _snapshot = widget.api.vault.ledger.snapshot();
  String? _account, _expense, _income;
  String _text = '', _filename = '', _delimiter = ',', _dateFormat = 'ymd';
  String _operation = const Uuid().v4();
  CsvTable? _table;
  List<CsvEntry>? _entries;
  final _choices = <int, Json>{};
  final _reviewedCategoryRows = <int>{};
  final _suggestedBy = <int, String>{};
  bool _rulesDialogOpen = false;
  int _date = 0, _payee = 1, _amount = 2, _debit = 2, _credit = 3, _reference = -1, _notes = -1, _page = 0;
  bool _splitColumns = false, _reverse = false, _busy = false, _upgrade = false, _reviewed = false;
  String? _error, _success, _profileId, _profileApplied;
  bool _profilePending = false, _profileDialogOpen = false;
  List<Json> get _profiles => ImportProfiles.list(_snapshot);
  CsvMapping get _mapping => CsvMapping(dateColumn: _date, payeeColumn: _payee,
    amountColumn: _splitColumns ? -1 : _amount, debitColumn: _debit, creditColumn: _credit,
    referenceColumn: _reference, notesColumn: _notes, dateFormat: _dateFormat, reverseSign: _reverse);
  List<Json> get _accounts => LocalLedger.rows(_snapshot['accounts']);
  List<Json> get _categories => LocalLedger.rows(_snapshot['categories']);
  @override
  void initState() {
    super.initState();
    if (_accounts.isNotEmpty) _account = _accounts.first['id'] as String;
    for (final c in _categories) {
      if (c['kind'] == 'Expense' && c['name'] == 'Other spending') _expense = c['id'] as String;
      if (c['kind'] == 'Income' && c['name'] == 'Other income') _income = c['id'] as String;
    }
  }
  void _mappingChanged() {
    _entries = null; _choices.clear(); _reviewedCategoryRows.clear(); _suggestedBy.clear();
    _reviewed = false; _profileApplied = null;
    _operation = const Uuid().v4(); _error = null; _success = null;
  }
  Future<void> _loadProfile() async {
    if (_busy || _text.isEmpty || _profileId == null) return;
    setState(() { _busy = true; _error = null; _success = null; });
    try {
      final snapshot = await widget.api.snapshot();
      final profile = ImportProfiles.list(snapshot).where((p) => p['id'] == _profileId).firstOrNull;
      if (profile == null) throw const FormatException('This profile is no longer active. Refresh profiles or choose manual mapping.');
      final settings = profile['settings'] as Json;
      final table = CsvTable.parse(_text, delimiter: settings['delimiter'] as String);
      final mapping = CsvProfiles.resolve(profile, table, LocalLedger.rows(snapshot['categories']));
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot; _mappingChanged(); _table = table;
        _delimiter = settings['delimiter'] as String; _dateFormat = mapping.dateFormat;
        _date = mapping.dateColumn; _payee = mapping.payeeColumn;
        _splitColumns = mapping.amountColumn < 0; _reverse = mapping.reverseSign;
        _amount = mapping.amountColumn < 0 ? 2 : mapping.amountColumn;
        _debit = mapping.debitColumn < 0 ? 2 : mapping.debitColumn;
        _credit = mapping.creditColumn < 0 ? (table.headers.length > 3 ? 3 : 0) : mapping.creditColumn;
        _reference = mapping.referenceColumn; _notes = mapping.notesColumn;
        _expense = settings['expenseCategoryId'] as String?; _income = settings['incomeCategoryId'] as String?;
        _profileApplied = profile['name'] as String; _profilePending = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _mappingChanged(); _table = null; _profilePending = true;
          _error = 'Unable to apply profile: $error';
        });
      }
    } finally { if (mounted) setState(() => _busy = false); }
  }
  void _manualMapping() {
    if (_busy) return;
    setState(() {
      _profileId = null; _profilePending = false; _profileApplied = null;
      _dateFormat = 'ymd'; _splitColumns = false; _reverse = false;
      try { if (_text.isNotEmpty) _parse(); }
      catch (error) { _table = null; _error = error.toString(); }
    });
  }
  Future<void> _saveProfile({bool update = false}) async {
    if (_busy || _table == null || _profilePending) return;
    try {
      final settings = CsvProfiles.capture(_table!, _mapping, delimiter: _delimiter,
        expenseCategoryId: _expense, incomeCategoryId: _income, categories: _categories);
      final existing = update ? _profiles.where((p) => p['id'] == _profileId).firstOrNull : null;
      if (update && existing == null) throw const FormatException('Choose an active profile to update.');
      final ids = _profiles.map((p) => p['id']).toSet();
      setState(() { _busy = true; _profileDialogOpen = true; _error = null; });
      final saved = await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (_) => ImportProfileEditor(data: _snapshot, settings: settings,
          existing: existing, onSave: widget.api.saveImportProfile));
      if (mounted && saved == true) {
        setState(() {
          _snapshot = widget.api.vault.ledger.snapshot(); _mappingChanged();
          _profileId = existing?['id'] as String? ?? _profiles.firstWhere((p) => !ids.contains(p['id']))['id'] as String;
          _success = 'Import profile saved. No transactions or import receipts changed.';
        });
      }
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() { _busy = false; _profileDialogOpen = false; }); }
  }
  Future<void> _manageProfiles() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.snapshot();
      if (!mounted) return;
      setState(() => _profileDialogOpen = true);
      await showDialog<void>(context: context, barrierDismissible: false,
        builder: (_) => ImportProfilesManager(snapshot: () => widget.api.vault.ledger.snapshot(),
          onSave: widget.api.saveImportProfile, onState: widget.api.archiveImportProfile,
          onRefresh: () async { await widget.api.snapshot(); }));
      if (mounted) {
        setState(() {
          _snapshot = widget.api.vault.ledger.snapshot(); _mappingChanged();
          if (!_profiles.any((p) => p['id'] == _profileId)) _profileId = null;
          _profilePending = _profileId != null;
        });
      }
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() { _busy = false; _profileDialogOpen = false; }); }
  }
  void _parse() {
    _mappingChanged(); _profilePending = _profileId != null;
    _table = CsvTable.parse(_text, delimiter: _delimiter);
    final names = _table!.headers.map((h) => h.toLowerCase()).toList();
    int guess(List<String> options, int fallback) {
      final found = names.indexWhere(options.contains);
      return found < 0 ? fallback : found;
    }
    _date = guess(['date', 'posted date', 'transaction date'], 0);
    _payee = guess(['description', 'payee', 'memo', 'merchant'], 1);
    _amount = guess(['amount', 'transaction amount'], 2);
    _debit = guess(['debit', 'withdrawal', 'withdrawals'], 2);
    _credit = guess(['credit', 'deposit', 'deposits'], names.length > 3 ? 3 : 0);
    _reference = -1; _notes = -1;
    _entries = null; _choices.clear(); _error = null; _success = null;
  }
  Future<void> _chooseFile() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final file = await (widget.chooseFile?.call() ?? openFile(acceptedTypeGroups: const [XTypeGroup(label: 'UTF-8 CSV',
        extensions: ['csv'], uniformTypeIdentifiers: ['public.comma-separated-values-text'])]));
      if (file == null) return;
      if (!mounted) return;
      setState(() { _text = ''; _filename = ''; _table = null; _mappingChanged(); });
      if (await file.length() > CsvTable.maxBytes) throw const FormatException('Choose a CSV no larger than 2 MB.');
      final bytes = await file.readAsBytes();
      if (bytes.length > CsvTable.maxBytes) throw const FormatException('CSV exceeds the 2 MB limit.');
      final text = utf8.decode(bytes);
      if (!mounted) return;
      setState(() { _text = text; _filename = file.name; _table = null; _entries = null; _parse(); });
    } catch (error) {
      if (mounted) setState(() { _table = null; _mappingChanged(); _error = 'Unable to read CSV: $error'; });
    } finally { if (mounted) setState(() => _busy = false); }
  }
  void _example() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    setState(() {
      _text = 'Date,Description,Amount\n$today,Fictional income,500.00\n$today,Fictional expense,-200.00\n';
      _filename = 'Budgetism-example.csv'; _delimiter = ','; _dateFormat = 'ymd'; _reverse = false; _splitColumns = false;
      _parse();
    });
  }
  bool _done(Json row) => CsvImport.consumed(_snapshot, _account!, _table!.digest, row);
  List<Json> _matches(Json row) => CsvImport.candidates(_snapshot, _account!, row);
  bool _possible(Json row) => _matches(row).isNotEmpty ||
    (_entries ?? <CsvEntry>[]).any((e) => e.values != null && e.rowNumber < row['rowNumber'] &&
      e.values!['date'] == row['date'] && e.values!['signedMinor'] == row['signedMinor']) ||
    LocalLedger.rows(_snapshot['imports']).any((r) => r['accountId'] == _account && r['date'] == row['date'] &&
      r['signedMinor'] == row['signedMinor'] && (r['payee'] as String).toLowerCase() == (row['payee'] as String).toLowerCase());
  Future<void> _preview() async {
    if (_busy || _table == null || _profilePending) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_account == null) throw const FormatException('Create or choose an account first.');
      final rows = CsvImport.preview(_table!, _mapping);
      final snapshot = await widget.api.snapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot; _entries = rows; _choices.clear(); _reviewedCategoryRows.clear(); _suggestedBy.clear();
        _page = 0; _upgrade = false; _reviewed = false;
        _operation = const Uuid().v4();
        for (final entry in rows.where((e) => e.values != null)) {
          final row = entry.values!;
          final incoming = (row['signedMinor'] as int) > 0;
          _choices[entry.rowNumber] = {'action': _done(row) || _possible(row) || CsvImport.transferHint(row['payee'] as String) ? 'skip' : 'create',
            'kind': incoming ? 'income' : 'expense', 'targetId': incoming ? _income : _expense, 'allowDuplicate': false};
        }
      });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _reviewRules() async {
    if (_busy || _entries == null || _table == null || _account == null) return;
    setState(() { _busy = true; _error = null; _success = null; });
    try {
      final fresh = await widget.api.snapshot();
      if (fresh['cursor'] != _snapshot['cursor']) {
        throw const FormatException('Workspace changed. Go back to mapping and preview the CSV again.');
      }
      final review = CsvRuleSuggestions.preview(snapshot: _snapshot, accountId: _account!,
        fileHash: _table!.digest, entries: _entries!, choices: _choices, reviewedRows: _reviewedCategoryRows);
      if (!mounted) return;
      setState(() => _rulesDialogOpen = true);
      await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (_) => CsvRuleSuggestionsDialog(review: review, onAccept: (selected) async {
          final current = await widget.api.snapshot();
          final changes = CsvRuleSuggestions.accept(review: review, snapshot: current,
            accountId: _account!, fileHash: _table!.digest, entries: _entries!, choices: _choices,
            reviewedRows: _reviewedCategoryRows, selectedRows: selected, confirmed: true);
          if (!mounted) return;
          setState(() {
            _choices.addAll(changes); _reviewedCategoryRows.addAll(selected);
            for (final p in review.suggestions.where((p) => selected.contains(p.rowNumber))) {
              _suggestedBy[p.rowNumber] = p.ruleName;
            }
            _reviewed = false; _operation = const Uuid().v4();
            _success = '${changes.length} category suggestions applied to this preview. No transactions saved.';
          });
        }));
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() { _busy = false; _rulesDialogOpen = false; }); }
  }
  List<Json> get _selected => [for (final entry in _entries ?? <CsvEntry>[])
    if (entry.values != null && !_done(entry.values!) && _choices[entry.rowNumber]?['action'] != 'skip')
      {...entry.values!, ..._choices[entry.rowNumber]!}];
  Future<void> _commit() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (!_reviewed) throw const FormatException('Review the rows and confirm the review checkbox.');
      final selected = _selected;
      if (selected.isEmpty || selected.length > 500) throw const FormatException('Select between 1 and 500 rows.');
      await widget.api.importCsv({'operationId': _operation, 'expectedRevision': _snapshot['cursor'],
        'accountId': _account, 'fileHash': _table!.digest, 'fileName': _filename,
        'confirmImportUpgrade': _upgrade, 'rows': selected});
      if (!mounted) return;
      final added = selected.where((r) => r['action'] == 'create').length;
      setState(() {
        _snapshot = widget.api.vault.ledger.snapshot();
        _success = 'Import saved: $added new transactions, ${selected.length - added} matched to existing transactions. Skipped rows were not saved.';
        _entries = null; _table = null; _text = ''; _choices.clear(); _reviewedCategoryRows.clear(); _suggestedBy.clear();
      });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _history() async {
    final groups = <String, List<Json>>{};
    for (final row in LocalLedger.rows(widget.api.vault.ledger.snapshot()['imports'])) {
      (groups[row['batchId'] as String] ??= []).add(row);
    }
    await showDialog<void>(context: context, builder: (c) => AlertDialog(title: const Text('Import history'),
      content: SizedBox(width: 600, height: 400, child: groups.isEmpty ? const Text('No imported rows yet.') :
        ListView(children: groups.values.toList().reversed.map((rows) => ExpansionTile(
          title: Text(rows.first['fileName'] as String),
          subtitle: Text('${rows.length} handled rows | ${rows.first['atUtc']}'),
          children: rows.map((r) => ListTile(title: Text('Row ${r['rowNumber']}: ${r['payee']}'),
            subtitle: Text('${r['date']} | ${r['action'] == 'match' ? 'Matched existing' : 'Imported'}'),
            trailing: Text(money(r['signedMinor'])))).toList())).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]));
  }
  Widget _select<T>(String label, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<T>(
      key: ValueKey('$label:$value'), initialValue: value, isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: items, onChanged: _busy ? null : onChanged));
  DropdownMenuItem<T> _option<T>(T value, String label) => DropdownMenuItem(value: value,
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis));
  Widget _column(String label, int current, ValueChanged<int> change, {bool optional = false}) =>
    _select<int>(label, current, [if (optional) _option(-1, 'Not mapped'),
      for (var i = 0; i < _table!.headers.length; i++) _option(i, '${i + 1}: ${_table!.headers[i]}')],
      (v) => setState(() { _mappingChanged(); change(v!); }));
  Widget _profileControls() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Saved import profiles', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    _select<String>('Saved profile', _profileId ?? '', [_option('', 'Choose a saved profile'),
      for (final p in _profiles) _option(p['id'] as String, p['name'] as String),
      if (_profileId != null && !_profiles.any((p) => p['id'] == _profileId)) _option(_profileId!, 'Unavailable profile'),
    ], (v) => setState(() {
      _mappingChanged(); _profileId = v == '' ? null : v; _profilePending = _profileId != null;
    })),
    Wrap(spacing: 10, runSpacing: 8, children: [
      OutlinedButton(key: const Key('apply-profile'), onPressed: _busy || _profileId == null || _text.isEmpty ? null : _loadProfile,
        child: const Text('Apply selected profile')),
      TextButton(onPressed: _busy || _text.isEmpty ? null : _manualMapping, child: const Text('Use manual mapping')),
      TextButton(onPressed: _busy ? null : _manageProfiles, child: const Text('Manage profiles')),
    ]),
    if (_profilePending) const Text('The selected profile has not been applied. Apply it or choose manual mapping before previewing.'),
    if (_profileApplied != null) Text('Applied profile: $_profileApplied. Destination account was not changed. Review the mapping below.'),
    const SizedBox(height: 12),
  ]);
  Widget _configuration() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _profileControls(),
    _select<String>('Destination account', _account, [for (final a in _accounts) _option(a['id'] as String, '${a['name']} (${a['type']})')],
      (v) => setState(() { _mappingChanged(); _account = v; })),
    Wrap(spacing: 12, runSpacing: 10, children: [
      FilledButton.icon(onPressed: _busy || _accounts.isEmpty ? null : _chooseFile, icon: const Icon(Icons.file_open_outlined), label: const Text('Choose CSV file')),
      OutlinedButton(onPressed: _busy || _accounts.isEmpty ? null : _example, child: const Text('Use fictional example CSV')),
      TextButton(onPressed: _busy ? null : _history, child: const Text('Import history')),
    ]),
    if (_accounts.isEmpty) const Text('Create an account before importing.'),
    const SizedBox(height: 14),
    if (_filename.isNotEmpty) Text('File: $_filename'),
    const SizedBox(height: 10),
    _select<String>('Separator', _delimiter, [_option(',', 'Comma'), _option(';', 'Semicolon'), _option('\t', 'Tab')], (v) {
      setState(() { _delimiter = v!; if (_text.isNotEmpty) { try { _parse(); } catch (error) { _table = null; _error = error.toString(); } } });
    }),
    if (_table != null) ...[
      Text('${_table!.records.length} data records. Headers are required. UTF-8 and USD decimal-point amounts only.'),
      const SizedBox(height: 12),
      _column('Date column', _date, (v) => _date = v),
      _select<String>('Date format', _dateFormat, [_option('ymd', 'YYYY-MM-DD'), _option('mdy', 'MM/DD/YYYY'), _option('dmy', 'DD/MM/YYYY')], (v) => setState(() { _mappingChanged(); _dateFormat = v!; })),
      _column('Description column', _payee, (v) => _payee = v),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Separate debit and credit columns'),
        value: _splitColumns, onChanged: _busy ? null : (v) => setState(() { _mappingChanged(); _splitColumns = v; })),
      if (_splitColumns) ...[
        _column('Debit / money out column', _debit, (v) => _debit = v),
        _column('Credit / money in column', _credit, (v) => _credit = v),
      ] else ...[
        _column('Signed amount column', _amount, (v) => _amount = v),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _reverse,
          title: const Text('Reverse signs: this file uses positive amounts for money out'),
          onChanged: _busy ? null : (v) => setState(() { _mappingChanged(); _reverse = v ?? false; })),
      ],
      _column('Unique bank transaction ID (optional)', _reference, (v) => _reference = v, optional: true),
      const Text('Map an ID only when the bank guarantees it is unique per account. Do not map a check number, merchant or category.'),
      const SizedBox(height: 12), _column('Notes column (optional)', _notes, (v) => _notes = v, optional: true),
      _select<String>('Default expense category', _expense, [for (final c in _categories.where((c) => c['kind'] == 'Expense')) _option(c['id'] as String, c['name'] as String)], (v) => setState(() { _mappingChanged(); _expense = v; })),
      _select<String>('Default income category', _income, [for (final c in _categories.where((c) => c['kind'] == 'Income')) _option(c['id'] as String, c['name'] as String)], (v) => setState(() { _mappingChanged(); _income = v; })),
      Wrap(spacing: 10, runSpacing: 8, children: [
        OutlinedButton(onPressed: _busy || _profilePending ? null : () => _saveProfile(), child: const Text('Save as new profile')),
        OutlinedButton(onPressed: _busy || _profilePending || _profileId == null ? null : () => _saveProfile(update: true), child: const Text('Update selected profile')),
      ]),
      const SizedBox(height: 12),
      FilledButton(onPressed: _busy || _profilePending ? null : _preview, child: const Text('Preview transactions')),
    ],
  ]);
  Widget _row(CsvEntry entry) {
    final row = entry.values;
    if (row == null) return Card(child: ListTile(title: Text('Row ${entry.rowNumber}: cannot import'), subtitle: Text(entry.error!)));
    final done = _done(row), possible = _possible(row);
    final choice = _choices[entry.rowNumber]!;
    final matches = _matches(row);
    final signed = row['signedMinor'] as int;
    final mode = choice['action'] == 'match' ? 'match:${choice['transactionId']}' : choice['action'] as String;
    final kind = choice['kind'] as String;
    final targets = kind == 'transfer' ? _accounts.where((a) => a['id'] != _account).toList()
      : _categories.where((c) => c['kind'] == (signed < 0 ? 'Expense' : 'Income')).toList();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Row ${entry.rowNumber} | ${row['date']} | ${signed > 0 ? '+' : ''}${money(signed)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6), Text(row['payee'] as String),
        if (row['notes'] != '') Text(row['notes'] as String),
        if (done) const Text('Already handled: this source row or unique bank ID will not be imported again.'),
        if (!done) ...[
          if (possible) const Text('Possible duplicate: same account, date and amount, or prior import history. Review before adding another transaction.'),
          if (CsvImport.transferHint(row['payee'] as String)) const Text('This description may be a transfer or card payment. Review the type and destination.'),
          const SizedBox(height: 12),
          _select<String>('Action for row ${entry.rowNumber}', mode, [
            _option('skip', 'Skip this row'), _option('create', 'Import a new transaction'),
            for (final t in matches) _option('match:${t['id']}', 'Match existing: ${t['payee']} [${t['id']}]'),
          ], (v) => setState(() {
            _reviewed = false; _suggestedBy.remove(entry.rowNumber);
            choice['action'] = v!.startsWith('match:') ? 'match' : v;
            choice['transactionId'] = v.startsWith('match:') ? v.substring(6) : null;
          })),
          if (choice['action'] == 'create') ...[
            _select<String>('Type for row ${entry.rowNumber}', kind, [
              _option(signed < 0 ? 'expense' : 'income', signed < 0 ? 'Expense' : 'Income'),
              _option('transfer', 'Transfer / credit card payment'),
            ], (v) => setState(() {
              _reviewed = false; _reviewedCategoryRows.remove(entry.rowNumber); _suggestedBy.remove(entry.rowNumber);
              choice['kind'] = v; choice['targetId'] = v == 'transfer' ? null : signed < 0 ? _expense : _income;
            })),
            _select<String>('${kind == 'transfer' ? (signed > 0 ? 'From account' : 'To account') : 'Category'} for row ${entry.rowNumber}',
              targets.any((t) => t['id'] == choice['targetId']) ? choice['targetId'] as String? : null,
              [for (final t in targets) _option(t['id'] as String, t['name'] as String)],
              (v) => setState(() {
                _reviewed = false; choice['targetId'] = v; _reviewedCategoryRows.add(entry.rowNumber); _suggestedBy.remove(entry.rowNumber);
              })),
            if (_suggestedBy.containsKey(entry.rowNumber)) Text('Category suggested by ${_suggestedBy[entry.rowNumber]}.',
              key: ValueKey('csv-rule-applied-${entry.rowNumber}')),
            if (possible) CheckboxListTile(contentPadding: EdgeInsets.zero, value: choice['allowDuplicate'] == true,
              title: const Text('I checked: import this as a separate transaction despite the possible duplicate'),
              onChanged: _busy ? null : (v) => setState(() { _reviewed = false; choice['allowDuplicate'] = v ?? false; })),
          ],
          if (choice['action'] == 'match') const Text('Keeps the existing transaction unchanged. Only the source-row receipt is saved.'),
        ],
    ])));
  }
  Widget _review() {
    final entries = _entries!;
    final selected = _selected;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Review $_filename', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('${entries.length} rows | ${entries.where((e) => e.error != null).length} invalid | ${selected.length} selected'),
      const Text('Invalid, previously handled and skipped rows are excluded. Review transfers and credit-card payments explicitly.'),
      const Text('This importer does not settle an unrecorded schedule. Record scheduled payments in Scheduled first, then match their existing transactions here to avoid double counting.'),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        OutlinedButton(onPressed: _busy ? null : () => setState(() { _entries = null; _reviewed = false; _error = null; }), child: const Text('Back to mapping')),
        TextButton(onPressed: _busy || _page == 0 ? null : () => setState(() => _page--), child: const Text('Previous rows')),
        Text('Page ${_page + 1} of ${(entries.length / 25).ceil()}'),
        TextButton(onPressed: _busy || (_page + 1) * 25 >= entries.length ? null : () => setState(() => _page++), child: const Text('Next rows')),
      ]),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
        key: const Key('review-csv-rules'), onPressed: _busy ? null : _reviewRules,
        icon: const Icon(Icons.rule), label: const Text('Review category suggestions'))),
      const SizedBox(height: 8),
      ...entries.skip(_page * 25).take(25).map(_row),
      if ((_snapshot['schema'] as int) < LocalLedger.importSchema) ...[
        const Text('First import: export a backup first. This preserves finances and the password setting, but older builds cannot open the import-history format.'),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _upgrade,
          title: const Text('I have a backup and understand this workspace will require dev.7 or newer'),
          onChanged: _busy ? null : (v) => setState(() => _upgrade = v ?? false)),
      ],
      CheckboxListTile(contentPadding: EdgeInsets.zero, key: const ValueKey('import-reviewed'), value: _reviewed,
        title: const Text('I reviewed dates, signs, categories, transfers and duplicate decisions'),
        onChanged: _busy ? null : (v) => setState(() => _reviewed = v ?? false)),
      FilledButton(key: const ValueKey('commit-import'), onPressed: _busy || selected.isEmpty ? null : _commit,
        child: Text('Import ${selected.length} selected rows')),
    ]);
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(
    appBar: AppBar(title: const Text('Import CSV statement')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: SingleChildScrollView(
      padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Files stay local. Only importing selected rows saves transactions. Saving a profile stores mapping settings, not statement rows. Use fictional data while testing.'),
        const SizedBox(height: 16),
        if (_busy && !_profileDialogOpen && !_rulesDialogOpen) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_success != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_success!, key: const ValueKey('import-success'))),
        if (_entries == null) _configuration() else _review(),
        const SizedBox(height: 24),
      ])))),
  ));
}
