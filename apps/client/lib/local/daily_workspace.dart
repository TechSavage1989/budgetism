import 'package:flutter/material.dart';
import '../date_controls.dart';
import '../money.dart';
import 'ledger.dart';
import 'local_api.dart';
import 'reports.dart';
import 'budget_widgets.dart';
import 'schedule_widgets.dart';
import 'import_profile_widgets.dart';
import 'transaction_register.dart';
import 'transaction_register_widgets.dart';

/// Uses the existing historical report engine, not stored or projected balances.
class DailyHomeSummary {
  DailyHomeSummary(Json snapshot, DateTime now) {
    today = FinanceDates.format(now);
    report = ReportEngine.calculate(snapshot, from: '${today.substring(0, 7)}-01', through: today, today: today);
    assets = report.balances.where((a) => !['credit_card', 'loan', 'liability'].contains(a.type))
      .fold<int>(0, (sum, a) => ReportEngine.add(sum, a.closing));
    final entries = LocalLedger.rows(snapshot['transactions']).where((t) => t['voided'] != true).toList();
    futureCount = entries.where((t) => (t['effectiveDate'] as String).compareTo(today) > 0).length;
    final recent = entries.where((t) => (t['effectiveDate'] as String).compareTo(today) <= 0).toList()
      ..sort((a, b) {
        final date = (b['effectiveDate'] as String).compareTo(a['effectiveDate'] as String);
        return date != 0 ? date : (a['id'] as String).compareTo(b['id'] as String);
      });
    transactions = List.unmodifiable(recent.take(6).map(LocalLedger.clone));
  }
  late final String today;
  late final FinanceReport report;
  late final int assets, futureCount;
  late final List<Json> transactions;
}

class DailyHomePanel extends StatelessWidget {
  const DailyHomePanel({super.key, required this.snapshot, required this.onNavigate,
    required this.onAdd, required this.onAddAccount, required this.onInspect, this.now});
  final Json snapshot;
  final ValueChanged<int> onNavigate;
  final VoidCallback onAdd, onAddAccount;
  final ValueChanged<String> onInspect;
  final DateTime? now;
  Widget _metric(BuildContext context, String label, int amount) => Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [Text(label), const SizedBox(height: 8),
        Text(money(amount), style: Theme.of(context).textTheme.headlineSmall)])));
  @override
  Widget build(BuildContext context) {
    DailyHomeSummary summary;
    try { summary = DailyHomeSummary(snapshot, now ?? DateTime.now()); }
    catch (e) { return Text('Home summary unavailable: $e. Your saved records have not been changed.'); }
    final accounts = LocalLedger.rows(snapshot['accounts']);
    final names = {for (final a in accounts) a['id']: a['name'] as String};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Home', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Recorded balances through ${summary.today}. Not bank-reported or forecast balances.'),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(key: const Key('home-add'), onPressed: accounts.isEmpty ? onAddAccount : onAdd,
          icon: const Icon(Icons.add), label: Text(accounts.isEmpty ? 'Add your first account' : 'Add transaction')),
        OutlinedButton.icon(onPressed: () => onNavigate(4), icon: const Icon(Icons.event_repeat_outlined), label: const Text('Bills and income')),
        OutlinedButton.icon(onPressed: () => onNavigate(7), icon: const Icon(Icons.assessment_outlined), label: const Text('View reports')),
        OutlinedButton.icon(onPressed: () => onNavigate(8), icon: const Icon(Icons.settings_outlined), label: const Text('Settings and tools')),
      ]),
      const SizedBox(height: 12),
      if (accounts.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(
        'Start with a manual account. Then add transactions or import a statement. Live bank connections are not enabled yet.')),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth >= 720 ? (constraints.maxWidth - 20) / 3 : constraints.maxWidth;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: width, child: _metric(context, 'Assets and cash', summary.assets)),
          SizedBox(width: width, child: _metric(context, 'Net recorded balance', summary.report.closing)),
          SizedBox(width: width, child: _metric(context, 'Spent month to date', summary.report.expense)),
        ]);
      }),
      if (summary.futureCount > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(
        '${summary.futureCount} future-dated recorded ${summary.futureCount == 1 ? 'entry is' : 'entries are'} excluded above. '
        'Accounts and Transactions still include all recorded dates.')),
      const SizedBox(height: 12),
      BudgetOverview(snapshot: snapshot, onOpen: () => onNavigate(3)),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(
        'Budget totals cover the whole selected month, including any future-dated recorded expenses.')),
      ScheduleOverview(snapshot: snapshot, onOpen: () => onNavigate(4)),
      Card(child: ListTile(key: const Key('home-needs-review'), leading: const Icon(Icons.inbox_outlined),
        title: Text('Needs Review (${BankSync.inbox(snapshot).length})'),
        subtitle: const Text('Fictional bank activity, corrections, matches and connection issues.'),
        onTap: () => onNavigate(10))),
      TextButton.icon(onPressed: () => onNavigate(9), icon: const Icon(Icons.account_balance_outlined),
        label: const Text('Open Connections')),
      const SizedBox(height: 12),
      Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Recent recorded activity', style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: () => onNavigate(2), child: const Text('View all transactions')),
      ]),
      if (summary.transactions.isEmpty) const Padding(padding: EdgeInsets.all(16),
        child: Text('No activity recorded through today. Use Add transaction when you are ready.')),
      for (final t in summary.transactions) Card(child: ListTile(key: ValueKey('home-entry-${t['id']}'),
        title: Text((t['payee'] as String).isEmpty ? t['kind'] as String : t['payee'] as String),
        subtitle: Text('${t['effectiveDate']} | ${names[t['accountId']]} | ${t['kind']}'),
        trailing: Text('${t['kind'] == 'income' ? '+' : t['kind'] == 'expense' ? '-' : ''}${money(t['amountMinor'])}'),
        onTap: () => onInspect(t['id'] as String))),
      const SizedBox(height: 88),
    ]);
  }
}

Future<void> showHomeTransaction(BuildContext context, LocalFinanceApi api, String id,
    Future<void> Function(Json) onEdit) async {
  RegisterEntry? latest() {
    final data = api.vault.ledger.snapshot(includeVoided: true);
    final rows = LocalLedger.rows(data['transactions']).where((t) => t['id'] == id).toList();
    return TransactionRegister.calculate({...data, 'transactions': rows}, const RegisterFilter(status: 'all')).entries.firstOrNull;
  }
  await api.snapshot();
  if (!context.mounted) return;
  final entry = latest();
  if (entry == null) throw const FormatException('This transaction is no longer available. Refresh the workspace.');
  final edit = await showDialog<bool>(context: context, builder: (_) => RegisterDetails(
    entry: entry, selectedAccount: '', allowEdit: true));
  if (edit != true || !context.mounted) return;
  await api.snapshot();
  if (!context.mounted) return;
  final current = latest();
  if (current == null || !current.canEdit) {
    throw const FormatException('This transaction is now protected or unavailable. Refresh before editing.');
  }
  await onEdit(current.transaction);
}

Future<void> showSavedImportProfiles(BuildContext context, LocalFinanceApi api) async {
  await api.snapshot();
  if (!context.mounted) return;
  await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => ImportProfilesManager(
    snapshot: () => api.vault.ledger.snapshot(), onSave: api.saveImportProfile,
    onState: api.archiveImportProfile, onRefresh: () async { await api.snapshot(); }));
}

class WorkspaceToolsPanel extends StatelessWidget {
  const WorkspaceToolsPanel({super.key, required this.local, required this.onAction,
    required this.passwordRequired, this.busy = false});
  final bool local, passwordRequired, busy;
  final ValueChanged<String> onAction;
  Widget _action(String id, String title, String detail, IconData icon, {bool localOnly = true}) => Card(
    child: ListTile(key: ValueKey('tool-$id'), enabled: !busy && (!localOnly || local),
      leading: Icon(icon), title: Text(title), subtitle: Text(localOnly && !local ? 'Open a saved local workspace to use this tool.' : detail),
      trailing: const Icon(Icons.chevron_right), onTap: busy || (localOnly && !local) ? null : () => onAction(id)));
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Settings and tools', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 8), const Text('Common workspace tools in one place. Opening a tool does not change financial records.'),
    const SizedBox(height: 16), Text('Organize', style: Theme.of(context).textTheme.titleLarge),
    _action('categories', 'Categories', 'Add or rename spending and income categories.', Icons.category_outlined),
    _action('rules', 'Categorization rules', 'Manage rules, preview changes and open category history.', Icons.rule_outlined),
    _action('profiles', 'Saved import profiles', 'Review, rename, archive or restore your saved CSV mappings.', Icons.table_view_outlined),
    _action('connections', 'Connections', 'Map fictional accounts and refresh the local simulated feed.', Icons.account_balance_outlined),
    _action('review', 'Needs Review', 'Review posted activity, duplicates, corrections and scheduled matches.', Icons.inbox_outlined),
    const SizedBox(height: 12), Text('Statements', style: Theme.of(context).textTheme.titleLarge),
    _action('import', 'Import CSV statement', 'Preview your statement before importing or matching transactions.', Icons.file_upload_outlined),
    _action('reconcile', 'Reconcile statements', 'Compare recorded activity with a statement and review history.', Icons.fact_check_outlined),
    const SizedBox(height: 12), Text('Privacy and recovery', style: Theme.of(context).textTheme.titleLarge),
    _action('security', 'Workspace security', passwordRequired ? 'A password is required to open this workspace.' :
      'Password prompting is off. Records remain encrypted for this OS account.', Icons.lock_outline),
    _action('backups', 'Backups and storage', 'Export an encrypted backup or restore a separately saved copy.', Icons.backup_outlined),
    const SizedBox(height: 12), Text('Application', style: Theme.of(context).textTheme.titleLarge),
    _action('theme', 'Appearance and themes', 'Presets, custom accent, light/dark mode, contrast and spacing.', Icons.palette_outlined, localOnly: false),
    _action('updates', 'Check for updates', 'Check published release information. In-app installation is not enabled.', Icons.system_update_alt, localOnly: false),
    const SizedBox(height: 12), Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bank connections and device sync', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6), const Text('Fictional bank simulation is available in Connections. No real bank is connected, '
          'and local records are not synchronized between devices.'),
      ]))), const SizedBox(height: 24),
  ]);
}
