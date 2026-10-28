import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../money.dart';
import 'budgets.dart';
import 'ledger.dart';
import 'recurrence.dart';
import 'reports.dart';

typedef ReportSaver = Future<bool> Function(String filename, String content);

/// Native export only. The platform picker requires an explicit destination.
Future<bool> saveReportCsv(String filename, String content) async {
  final result = await getSaveLocation(suggestedName: filename,
    acceptedTypeGroups: [const XTypeGroup(label: 'CSV report', extensions: ['csv'])]);
  if (result == null) return false;
  if (!result.path.toLowerCase().endsWith('.csv')) {
    throw const FormatException('Choose a filename ending in .csv. Other file types will not be overwritten.');
  }
  await XFile.fromData(Uint8List.fromList(utf8.encode(content)),
    mimeType: 'text/csv', name: filename).saveTo(result.path);
  return true;
}

class ReportPanel extends StatefulWidget {
  const ReportPanel({required this.readSnapshot, this.today, this.saveCsv, super.key});
  // No mutation API is supplied to this screen.
  final Json Function() readSnapshot;
  final String? today;
  final ReportSaver? saveCsv;
  @override
  State<ReportPanel> createState() => _ReportPanelState();
}

class _ReportPanelState extends State<ReportPanel> {
  String get _today => widget.today ?? Recurrence.today();
  String _period = 'This month', _view = 'Overview', _kind = 'Expense';
  String? _customFrom, _customThrough;
  Set<String>? _accounts;
  String? _message;
  bool _exporting = false;
  ReportExport _export = ReportExport.summary;

  (String, String) _range() {
    final date = Recurrence.parse(_today);
    switch (_period) {
      case 'Last month':
        final last = DateTime.utc(date.year, date.month, 0);
        return (Recurrence.format(DateTime.utc(last.year, last.month)), Recurrence.format(last));
      case 'Year to date': return ('${date.year}-01-01', _today);
      case 'Last 12 months':
        return (Recurrence.format(DateTime.utc(date.year, date.month - 11)), _today);
      case 'Custom': return (_customFrom!, _customThrough!);
      default: return ('${_today.substring(0, 7)}-01', _today);
    }
  }

  Future<void> _chooseRange() async {
    final (from, through) = _range();
    final choice = await showDateRangePicker(context: context,
      firstDate: DateTime(1900), lastDate: Recurrence.parse(_today),
      initialDateRange: DateTimeRange(start: Recurrence.parse(from), end: Recurrence.parse(through)),
      helpText: 'Report dates (up to 3,660 days)');
    if (choice != null && mounted) {
      setState(() { _period = 'Custom'; _customFrom = Recurrence.format(choice.start);
        _customThrough = Recurrence.format(choice.end); _message = null; });
    }
  }

  Future<void> _chooseAccounts(List<Json> accounts) async {
    final chosen = Set<String>.from(_accounts ?? accounts.map((a) => a['id'] as String));
    final result = await showDialog<Set<String>>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, update) => AlertDialog(title: const Text('Report accounts'),
        content: SizedBox(width: 440, height: 320, child: Column(children: [
          Wrap(spacing: 8, children: [
            TextButton(onPressed: () => update(() { chosen.addAll(accounts.map((a) => a['id'] as String)); }), child: const Text('Select all')),
            TextButton(onPressed: () => update(chosen.clear), child: const Text('Clear selection')),
          ]),
          Expanded(child: ListView(children: [for (final a in accounts) CheckboxListTile(
            title: Text(a['name'] as String), subtitle: Text((a['type'] as String).replaceAll('_', ' ')),
            value: chosen.contains(a['id']), onChanged: (v) => update(() {
              if (v == true) { chosen.add(a['id'] as String); } else { chosen.remove(a['id']); }
            }))])),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: chosen.isEmpty ? null : () => Navigator.pop(dialogContext, chosen), child: const Text('Apply accounts'))])));
    if (result != null && mounted) setState(() { _accounts = result; _message = null; });
  }

  Future<void> _exportCsv(FinanceReport report) async {
    if (_exporting) return;
    final type = _export;
    setState(() { _exporting = true; _message = null; });
    try {
      final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Export an unencrypted report?'),
        content: Text('${ReportCsv.label(type)} for ${report.from} through ${report.through}. '
          'This CSV contains financial information outside workspace encryption. Save it somewhere private. '
          'It is not a backup. Formula-like text is prefixed with "Text: " and control characters are replaced.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('confirm-report-export'),
            onPressed: () => Navigator.pop(context, true), child: const Text('Choose save location'))]));
      if (accepted != true || !mounted) return;
      final saved = await (widget.saveCsv ?? saveReportCsv)(
        'Budgetism-${type.name}-${report.from}-${report.through}.csv', ReportCsv.encode(report, type));
      if (mounted) setState(() => _message = saved ? 'CSV report saved. Your workspace was not changed.' : 'Export cancelled.');
    } catch (_) {
      if (mounted) setState(() => _message = 'The report could not be saved. Check the destination, use a .csv filename, and try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.readSnapshot();
    final accounts = LocalLedger.rows(data['accounts']);
    final (from, through) = _range();
    FinanceReport? report;
    String? error;
    try {
      report = ReportEngine.calculate(data, from: from, through: through, today: _today, accountIds: _accounts);
    } on FormatException catch (e) { error = e.message; }
    final canExport = widget.saveCsv != null || (!kIsWeb &&
      [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(defaultTargetPlatform));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Financial reports', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Recorded activity only. Transfers and card payments are not income or spending. Plans, allocations, voided entries and future dates are excluded.'),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final name in ['This month', 'Last month', 'Year to date', 'Last 12 months'])
          ChoiceChip(label: Text(name), selected: _period == name, onSelected: _exporting ? null : (_) => setState(() { _period = name; _message = null; })),
        OutlinedButton.icon(onPressed: _exporting ? null : _chooseRange,
          icon: const Icon(Icons.date_range_outlined), label: Text(_period == 'Custom' ? 'Edit custom dates' : 'Custom dates')),
        OutlinedButton.icon(key: const ValueKey('report-accounts'), onPressed: _exporting || accounts.isEmpty ? null : () => _chooseAccounts(accounts),
          icon: const Icon(Icons.account_balance_wallet_outlined), label: Text(_accounts == null ? 'All accounts' : '${_accounts!.length} selected accounts')),
      ]),
      const SizedBox(height: 12),
      Text('$from through $through (inclusive) - USD'),
      if (accounts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Create an account to start reporting.')),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (report != null && accounts.isNotEmpty) ...[
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final view in ['Overview', 'Categories', 'Monthly', 'Balances'])
          ChoiceChip(key: ValueKey('report-view-$view'), label: Text(view), selected: _view == view,
            onSelected: (_) => setState(() => _view = view))]),
        const SizedBox(height: 16),
        if (_view == 'Overview') _overview(report),
        if (_view == 'Categories') _categories(report),
        if (_view == 'Monthly') _monthly(report),
        if (_view == 'Balances') _balances(report),
        const SizedBox(height: 20),
        const Divider(),
        const Text('Recorded balances use saved, undated opening balances plus recorded entries through the ending date. They are not historical market valuations. Debt is negative. Partial months use only the selected dates.'),
        const SizedBox(height: 12),
        if (canExport) Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 280, child: DropdownButtonFormField<ReportExport>(initialValue: _export, isExpanded: true,
            decoration: const InputDecoration(labelText: 'CSV report', border: OutlineInputBorder()),
            items: [for (final type in ReportExport.values) DropdownMenuItem(value: type,
              child: Text(ReportCsv.label(type), overflow: TextOverflow.ellipsis))],
            onChanged: _exporting ? null : (value) => setState(() => _export = value!))),
          FilledButton.icon(key: const ValueKey('export-report'), onPressed: _exporting ? null : () => _exportCsv(report),
            icon: const Icon(Icons.save_alt_outlined), label: Text(_exporting ? 'Exporting...' : 'Export CSV')),
        ]) else const Text('CSV saving is available in desktop builds.'),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
      ],
    ]);
  }

  Widget _overview(FinanceReport report) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 10, runSpacing: 10, children: [
      _metric('Income', report.income), _metric('Expenses', report.expense),
      _metric('Net income', report.netIncome), _metric('Closing recorded net balance', report.closing),
    ]),
    const SizedBox(height: 16),
    Text('${report.transactions.length} income/expense transactions; ${report.transferCount} transfers excluded from income/spending.'),
    Text('Selected account balance change: ${money(report.balanceChange)}. Transfers outside the selected accounts can make this differ from net income.'),
    if (report.transactions.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('No income or expenses in this selection.')),
    const SizedBox(height: 12),
    TextButton.icon(onPressed: () => setState(() => _view = 'Categories'),
      icon: const Icon(Icons.list_alt_outlined), label: const Text('Inspect category totals and transactions')),
  ]);

  Widget _metric(String title, int amount) => SizedBox(width: 240, child: Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title), const SizedBox(height: 8), SelectableText(money(amount), style: Theme.of(context).textTheme.titleLarge),
    ]))));

  Widget _categories(FinanceReport report) {
    final rows = report.categories.where((c) => c.kind == _kind).toList();
    final total = _kind == 'Income' ? report.income : report.expense;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: [for (final kind in ['Expense', 'Income']) ChoiceChip(label: Text(kind == 'Expense' ? 'Spending' : 'Income'),
        selected: _kind == kind, onSelected: (_) => setState(() => _kind = kind))]),
      const SizedBox(height: 8),
      Text('Total: ${money(total)}. Select a category to inspect its transaction contributions.'),
      if (rows.isEmpty) const Text('No category activity in this selection.'),
      for (final c in rows) Card(child: InkWell(key: ValueKey('report-category-${c.id}'),
        onTap: () => showDialog<void>(context: context, builder: (_) => ReportCategoryDialog(report: report, category: c)),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 4, children: [Text(c.name, style: Theme.of(context).textTheme.titleMedium),
            Text('${money(c.amount)} - ${c.count} transactions')]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: total == 0 ? 0 : (c.amount / total).clamp(0.0, 1.0), minHeight: 6),
        ])))),
    ]);
  }

  Widget _monthly(FinanceReport report) {
    final maximum = report.months.fold<int>(0, (n, m) => [n, m.income, m.expense].reduce((a, b) => a > b ? a : b));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Income and expenses by month. Months without activity are shown as zero. All amounts below are exact; bars are visual aids.'),
      for (final m in report.months) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(BudgetEngine.label(m.month), style: Theme.of(context).textTheme.titleMedium),
        _bar('Income', m.income, maximum, Theme.of(context).colorScheme.primary),
        _bar('Expenses', m.expense, maximum, Theme.of(context).colorScheme.secondary),
        Wrap(spacing: 16, runSpacing: 4, children: [Text('Net income: ${money(m.net)}'), Text('Closing recorded net balance: ${money(m.closing)}')]),
      ]))),
    ]);
  }

  Widget _bar(String label, int value, int maximum, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ${money(value)}'), const SizedBox(height: 4),
      LinearProgressIndicator(value: maximum == 0 ? 0 : (value / maximum).clamp(0.0, 1.0), color: color, minHeight: 6),
    ]));

  Widget _balances(FinanceReport report) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Selected recorded net balance: ${money(report.closing)}'),
    const Text('Starting balances are immediately before the selected period. Transfers change individual accounts, not income or spending.'),
    for (final a in report.balances) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(a.name, style: Theme.of(context).textTheme.titleMedium), Text(a.type.replaceAll('_', ' ')),
      const SizedBox(height: 8),
      Wrap(spacing: 16, runSpacing: 6, children: [Text('Starting: ${money(a.before)}'), Text('Change: ${money(a.change)}'), Text('Closing: ${money(a.closing)}')]),
    ]))),
  ]);
}

class ReportCategoryDialog extends StatefulWidget {
  const ReportCategoryDialog({required this.report, required this.category, super.key});
  final FinanceReport report;
  final ReportCategory category;
  @override
  State<ReportCategoryDialog> createState() => _ReportCategoryDialogState();
}

class _ReportCategoryDialogState extends State<ReportCategoryDialog> {
  int _limit = 100;
  @override
  Widget build(BuildContext context) {
    final rows = widget.report.forCategory(widget.category.id);
    final count = rows.length < _limit ? rows.length : _limit;
    return AlertDialog(title: Text(widget.category.name), content: SizedBox(width: 640, height: 420,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${widget.report.from} through ${widget.report.through} - total ${money(widget.category.amount)}'),
        const Text('Read-only. A split shows this category contribution, not the entire transaction.'),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: count + (count < rows.length ? 1 : 0), itemBuilder: (context, index) {
          if (index == count) return TextButton(onPressed: () => setState(() => _limit += 100), child: Text('Show more (${rows.length - count} remaining)'));
          final t = rows[index];
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.payee.isEmpty ? 'Recorded ${t.kind}' : t.payee),
            Text('${t.date} - ${t.accountName}'),
            Text('Category contribution: ${money(t.categories[widget.category.id])}'),
            Text('Whole transaction: ${money(t.amount)}'),
          ])));
        })),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]);
  }
}
