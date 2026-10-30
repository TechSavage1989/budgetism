import 'package:flutter/material.dart';
import '../date_controls.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'budgets.dart';
import 'ledger.dart';
import 'planning_api.dart';

class BudgetOverview extends StatelessWidget {
  const BudgetOverview({required this.snapshot, required this.onOpen, super.key});
  final Json snapshot;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    try {
      final summary = BudgetEngine.calculate(snapshot, BudgetEngine.monthOf(DateTime.now()));
      return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16, children: [
              Text('Budgets this month', style: Theme.of(context).textTheme.titleLarge),
              TextButton(onPressed: onOpen, child: const Text('Open budgets')),
            ]),
          if (!summary.hasPlan) const Padding(padding: EdgeInsets.only(bottom: 10),
            child: Text('No allocations set. Create category budgets to plan this month.')),
          BudgetTotals(summary: summary),
          const SizedBox(height: 8),
          const Text('Planning amounts only. Budget allocations do not move money between accounts.'),
        ])));
    } catch (error) {
      return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Budget summary unavailable: $error')));
    }
  }
}

class BudgetTotals extends StatelessWidget {
  const BudgetTotals({required this.summary, super.key});
  final MonthlyBudget summary;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 26, runSpacing: 16, children: [
    _value(context, 'Allocated', summary.allocated),
    _value(context, 'Carried in', summary.carried),
    _value(context, 'Spent', summary.spent),
    _value(context, 'Remaining', summary.remaining, warning: summary.remaining < 0),
  ]);
  Widget _value(BuildContext context, String label, int amount, {bool warning = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(money(amount), style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600, color: warning ? Theme.of(context).colorScheme.error : null)),
    ]);
}

class BudgetPanel extends StatefulWidget {
  const BudgetPanel({required this.api, required this.month, required this.onMonthChanged,
    required this.onChanged, required this.onOpenTransaction, super.key});
  final PlanningWorkspaceApi api;
  final String month;
  final ValueChanged<String> onMonthChanged;
  final Future<void> Function() onChanged;
  final Future<void> Function(Json) onOpenTransaction;
  @override
  State<BudgetPanel> createState() => _BudgetPanelState();
}

class _BudgetPanelState extends State<BudgetPanel> {
  Future<void> _edit(CategoryBudget row) async {
    final changed = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => BudgetEditorDialog(row: row, month: widget.month,
        requiresUpgrade: widget.api.planningSnapshot['schema'] == LocalLedger.legacySchema,
        onSave: widget.api.saveBudget, onRemove: widget.api.removeBudget));
    if (changed == true && mounted) await widget.onChanged();
  }
  Future<void> _copy() async {
    final data = widget.api.planningSnapshot;
    final changed = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => CopyBudgetsDialog(month: widget.month, revision: data['cursor'] as int,
        requiresUpgrade: data['schema'] == LocalLedger.legacySchema, onCopy: widget.api.copyBudgets));
    if (changed == true && mounted) await widget.onChanged();
  }
  Future<void> _pickMonth() async {
    final month = await showDialog<String>(context: context, builder: (_) => FinanceMonthDialog(month: widget.month));
    if (month != null && mounted) widget.onMonthChanged(month);
  }
  Future<void> _details(CategoryBudget row) async {
    final data = widget.api.planningSnapshot;
    final transactions = BudgetEngine.transactionsFor(data, widget.month, row.id);
    final accounts = {for (final a in LocalLedger.rows(data['accounts'])) a['id']: a['name']};
    final selected = await showDialog<Json>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('${row.name} - ${BudgetEngine.label(widget.month)}'),
      content: SizedBox(width: 560, height: 360, child: transactions.isEmpty
        ? const Center(child: Text('No recorded expenses in this category for this month.'))
        : ListView.builder(itemCount: transactions.length, itemBuilder: (_, index) {
          final t = transactions[index];
          final amount = BudgetEngine.contribution(t, row.id);
          final payee = t['payee'] as String;
          return ListTile(title: Text(payee.isEmpty ? 'Expense' : payee),
            subtitle: Text('${t['effectiveDate']} | ${accounts[t['accountId']]}'
              '${amount != t['amountMinor'] ? '\nCategory share of ${money(t['amountMinor'])} transaction' : ''}'),
            trailing: Text(money(amount)), onTap: () => Navigator.pop(dialogContext, t));
        })),
      actions: [Text('Category total: ${money(row.spent)}'),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
    ));
    if (selected != null && mounted) await widget.onOpenTransaction(selected);
  }
  @override
  Widget build(BuildContext context) {
    final data = widget.api.planningSnapshot;
    final MonthlyBudget summary;
    try { summary = BudgetEngine.calculate(data, widget.month); }
    catch (error) { return Text('Unable to calculate budgets: $error'); }
    final previous = widget.month == '1900-01' ? null : LocalLedger.shiftMonth(widget.month, -1);
    final canCopy = previous != null && LocalLedger.rows(data['budgets'] ?? <Json>[])
        .any((b) => b['month'] == previous && b['removed'] != true);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Monthly budgets', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Set expense-category allocations. Remaining = allocation + carried in - spending.'),
      const SizedBox(height: 16),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
        IconButton(key: const ValueKey('budget-previous'), tooltip: 'Previous month',
          onPressed: previous == null ? null : () => widget.onMonthChanged(previous),
          icon: const Icon(Icons.chevron_left)),
        TextButton.icon(onPressed: _pickMonth, icon: const Icon(Icons.calendar_month_outlined),
          label: Text(BudgetEngine.label(widget.month))),
        IconButton(key: const ValueKey('budget-next'), tooltip: 'Next month',
          onPressed: widget.month == '9999-12' ? null : () => widget.onMonthChanged(LocalLedger.shiftMonth(widget.month, 1)),
          icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () => widget.onMonthChanged(BudgetEngine.monthOf(DateTime.now())), child: const Text('This month')),
        Tooltip(message: canCopy ? 'Copy allocation amounts and rollover rules only.' : 'No allocations in the previous month.',
          child: OutlinedButton.icon(onPressed: canCopy ? _copy : null, icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy previous month'))),
      ]),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [BudgetTotals(summary: summary),
          const SizedBox(height: 10),
          Text(summary.overBudgetCount == 0 ? 'No category is over its available budget.'
            : '${summary.overBudgetCount} categories exceed their available budget, including unbudgeted spending.'),
        ]))),
      const SizedBox(height: 14),
      const Text('Select a category to review its expenses. Use the edit button to set its allocation.'),
      const SizedBox(height: 8),
      if (summary.categories.isEmpty) const Text('Add an expense category from User options > Manage categories.'),
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(children: [for (final row in summary.categories)
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: TextButton(onPressed: () => _details(row),
                  child: Align(alignment: Alignment.centerLeft, child: Text(row.name)))),
                  IconButton(tooltip: 'Edit ${row.name} budget', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined))]),
                Wrap(spacing: 16, runSpacing: 8, children: [
                  Text('Allocated: ${row.hasAllocation ? money(row.allocated) : 'Not set'}'),
                  Text('Carried: ${money(row.carried)}'), Text('Spent: ${money(row.spent)}'), _remaining(context, row),
                ]),
                const SizedBox(height: 8), Text('Next month: ${BudgetEngine.ruleLabel(row.rollover)}'),
              ])))],
          );
        }
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth), child: DataTable(
            columnSpacing: 20, horizontalMargin: 12, dataRowMinHeight: 62, dataRowMaxHeight: 96,
            columns: const [DataColumn(label: Text('Category')), DataColumn(label: Text('Allocated'), numeric: true),
              DataColumn(label: Text('Carried in'), numeric: true), DataColumn(label: Text('Spent'), numeric: true),
              DataColumn(label: Text('Remaining'), numeric: true), DataColumn(label: Text('Edit'))],
            rows: [for (final row in summary.categories) DataRow(cells: [
              DataCell(SizedBox(width: 195, child: Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextButton(onPressed: () => _details(row), child: Text(row.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  Text(BudgetEngine.ruleLabel(row.rollover), style: Theme.of(context).textTheme.bodySmall),
                ]))),
              DataCell(Text(row.hasAllocation ? money(row.allocated) : 'Not set')),
              DataCell(Text(money(row.carried))),
              DataCell(Text(money(row.spent)), onTap: () => _details(row)),
              DataCell(_remaining(context, row)),
              DataCell(IconButton(tooltip: 'Edit ${row.name} budget', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined))),
            ])],
          )));
      }),
      const SizedBox(height: 14),
      const Text('Rollover applies to the next month. Months without an allocation use \$0 and inherit the last rollover rule. '
        'Removing an allocation stops its outgoing rollover. Unbudgeted expenses are included in totals.'),
      const SizedBox(height: 28),
    ]);
  }
  Widget _remaining(BuildContext context, CategoryBudget row) => Text(
    '${money(row.remaining)}${row.remaining < 0 ? ' over' : ''}',
    style: TextStyle(fontWeight: FontWeight.w600,
      color: row.remaining < 0 ? Theme.of(context).colorScheme.error : null));
}

class BudgetEditorDialog extends StatefulWidget {
  const BudgetEditorDialog({required this.row, required this.month, required this.requiresUpgrade,
    required this.onSave, required this.onRemove, super.key});
  final CategoryBudget row;
  final String month;
  final bool requiresUpgrade;
  final Future<void> Function(Json) onSave;
  final Future<void> Function(Json) onRemove;
  @override
  State<BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}
class _BudgetEditorDialogState extends State<BudgetEditorDialog> {
  late final _amount = TextEditingController(text: decimalAmount(widget.row.allocated));
  late String _rollover = widget.row.rollover;
  bool _busy = false;
  bool _upgrade = false;
  String? _error;
  @override
  void dispose() { _amount.dispose(); super.dispose(); }
  Future<void> _save({bool remove = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.requiresUpgrade && !_upgrade) throw const FormatException('Confirm the workspace format upgrade first.');
      final input = <String, dynamic>{'operationId': const Uuid().v4(), 'month': widget.month,
        'categoryId': widget.row.id, 'expectedVersion': widget.row.plan?['version'] ?? 0,
        'confirmSchemaUpgrade': _upgrade};
      if (remove) {
        await widget.onRemove(input);
      } else {
        input.addAll({'amountMinor': parseMinor(_amount.text), 'rollover': _rollover});
        await widget.onSave(input);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _busy = false; _error = error.toString(); }); }
  }
  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Remove this allocation?'),
      content: const Text('This clears the allocation and stops its outgoing rollover for this month. '
        'Transactions, incoming rollover and previous months are not deleted.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove allocation'))]));
    if (confirmed == true && mounted) await _save(remove: true);
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: Text('${widget.row.name} budget'),
    content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(BudgetEngine.label(widget.month)), const SizedBox(height: 16),
        TextField(key: const ValueKey('budget-amount'), controller: _amount, enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monthly allocation (USD)', border: OutlineInputBorder(),
            helperText: 'Zero is allowed. This does not change your account balance.')),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(initialValue: _rollover, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Rollover to next month', border: OutlineInputBorder()),
          items: [for (final mode in LocalLedger.rolloverModes)
            DropdownMenuItem(value: mode, child: Text(BudgetEngine.ruleLabel(mode)))],
          onChanged: _busy ? null : (value) => setState(() => _rollover = value!)),
        const SizedBox(height: 12),
        Text('Carried in: ${money(widget.row.carried)}. Spent: ${money(widget.row.spent)}.'),
        if (widget.requiresUpgrade) _UpgradeNotice(value: _upgrade,
          onChanged: _busy ? null : (v) => setState(() => _upgrade = v ?? false)),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ]))),
    actions: [if (widget.row.hasAllocation) TextButton(onPressed: _busy ? null : _remove, child: const Text('Remove allocation')),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('Save budget'))],
  ));
}

class CopyBudgetsDialog extends StatefulWidget {
  const CopyBudgetsDialog({required this.month, required this.revision, required this.requiresUpgrade,
    required this.onCopy, super.key});
  final String month;
  final int revision;
  final bool requiresUpgrade;
  final Future<void> Function(Json) onCopy;
  @override
  State<CopyBudgetsDialog> createState() => _CopyBudgetsDialogState();
}
class _CopyBudgetsDialogState extends State<CopyBudgetsDialog> {
  bool _replace = false;
  bool _upgrade = false;
  bool _busy = false;
  String? _error;
  Future<void> _copy() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.requiresUpgrade && !_upgrade) throw const FormatException('Confirm the workspace format upgrade first.');
      await widget.onCopy({'operationId': const Uuid().v4(), 'month': widget.month,
        'expectedRevision': widget.revision, 'replaceExisting': _replace, 'confirmSchemaUpgrade': _upgrade});
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _busy = false; _error = error.toString(); }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: const Text('Copy previous month'),
    content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Copy allocations and rollover rules from ${BudgetEngine.label(LocalLedger.shiftMonth(widget.month, -1))} '
        'to ${BudgetEngine.label(widget.month)}. Transactions and spending are not copied; rollover is recalculated.'),
      CheckboxListTile(value: _replace, onChanged: _busy ? null : (v) => setState(() => _replace = v ?? false),
        title: const Text('Replace allocations already set for this month'), controlAffinity: ListTileControlAffinity.leading),
      if (widget.requiresUpgrade) _UpgradeNotice(value: _upgrade,
        onChanged: _busy ? null : (v) => setState(() => _upgrade = v ?? false)),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]))),
    actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _copy, child: const Text('Copy allocations'))],
  ));
}

class _UpgradeNotice extends StatelessWidget {
  const _UpgradeNotice({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool?>? onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
    const SizedBox(height: 12),
    const Text('First budget: export a backup before saving. The budgeting format preserves your records and security setting, '
      'but older Budgetism builds cannot open it. Use your pre-upgrade backup for recovery.'),
    CheckboxListTile(value: value, onChanged: onChanged, controlAffinity: ListTileControlAffinity.leading,
      title: const Text('I understand this workspace will require dev.4 or newer')),
  ]);
}
