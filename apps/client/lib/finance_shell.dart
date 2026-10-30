part of 'main.dart';

class FinanceShell extends StatefulWidget {
  const FinanceShell({required this.api, required this.username, required this.onLogout,
      required this.onToggleTheme, required this.onCheckUpdates, this.onAppearance, super.key});
  final FinanceApi api;
  final String username;
  final VoidCallback onLogout, onToggleTheme, onCheckUpdates;
  final VoidCallback? onAppearance;
  @override
  State<FinanceShell> createState() => _FinanceShellState();
}

class _FinanceShellState extends State<FinanceShell> {
  Color get _accent => Theme.of(context).colorScheme.primary;
  int _page = 0;
  String _budgetMonth = DateTime.now().toIso8601String().substring(0, 7);
  String _query = '', _filterAccount = '';
  int _transactionLimit = 100;
  RegisterFilter _registerFilter = const RegisterFilter();
  bool get _local => widget.api is LocalFinanceApi;
  bool _loading = true, _updating = false;
  bool _entryOpen = false, _inspecting = false, _toolBusy = false;
  String? _error;
  DateTime? _lastUpdated;
  List<Map<String, dynamic>> _accounts = [], _categories = [], _transactions = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState(); _refresh();
    if (!_local) _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh(silent: true));
  }
  Future<void> _refresh({bool silent = false}) async {
    if (_updating) return;
    _updating = true;
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    try {
      final snapshot = await widget.api.snapshot();
      if (!mounted) return;
      setState(() {
        _accounts = (snapshot['accounts'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (_filterAccount.isNotEmpty && !_accounts.any((a) => a['id'] == _filterAccount)) _filterAccount = '';
        _categories = (snapshot['categories'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _transactions = (snapshot['transactions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _transactions.sort((a, b) => (a['effectiveDate'] as String).compareTo(b['effectiveDate'] as String));
        _error = null; _lastUpdated = DateTime.now();
      });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { _updating = false; if (mounted) setState(() => _loading = false); }
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _createAccount({Map<String, dynamic>? existing}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: !_local,
      builder: (_) => CreateAccountDialog(existing: existing, onSave: _local ? widget.api.createAccount : null));
    if (result == null) return;
    try { if (!_local) await widget.api.createAccount(result); await _refresh(); }
    catch (error) { _showError(error); }
  }
  Future<void> _createTransaction() async {
    if (_accounts.isEmpty) { _showError('Create an account first.'); return; }
    if (_local) { await _editLocalTransaction(); return; }
    final result = await showDialog<Map<String, dynamic>>(context: context,
      builder: (_) => CreateTransactionDialog(accounts: _accounts, categories: _categories));
    if (result == null) return;
    try { await widget.api.createTransaction(result); await _refresh(); }
    catch (error) { _showError(error); }
  }
  Future<void> _editLocalTransaction([Map<String, dynamic>? transaction]) async {
    if (_entryOpen) return;
    _entryOpen = true;
    try {
      final api = widget.api as LocalFinanceApi;
      final data = await api.snapshot();
      if (!mounted) return;
      final accounts = LocalLedger.rows(data['accounts']);
      if (accounts.isEmpty) throw const FormatException('Create an account before adding a transaction.');
      Json? current;
      if (transaction != null) {
        current = LocalLedger.rows(data['transactions']).where((t) => t['id'] == transaction['id']).firstOrNull;
        if (current == null || current['voided'] == true || Reconciliation.locked(data, current['id'] as String)) {
          throw const FormatException('This transaction is protected or unavailable. Reopen its statement before editing.');
        }
      }
      await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (_) => LocalTransactionEditor(accounts: accounts, categories: LocalLedger.rows(data['categories']),
          history: LocalLedger.rows(data['transactions']), existing: current,
          onSave: api.createTransaction, onVoid: api.voidTransaction));
      if (mounted) await _refresh();
    } catch (error) { _showError(error); }
    finally { _entryOpen = false; }
  }
  Future<void> _inspectHome(String id) async {
    if (_inspecting) return;
    _inspecting = true;
    try { await showHomeTransaction(context, widget.api as LocalFinanceApi, id, _editLocalTransaction); }
    catch (error) { _showError(error); }
    finally { _inspecting = false; }
  }
  Future<void> _localOptions(String value) async {
    if (value == 'connections' || value == 'review') {
      if (_local) setState(() => _page = value == 'connections' ? 9 : 10);
      return;
    }
    if (value == 'theme') { (widget.onAppearance ?? widget.onToggleTheme)(); return; }
    if (value == 'updates') { widget.onCheckUpdates(); return; }
    if (!_local || _toolBusy) return;
    setState(() => _toolBusy = true);
    try {
      final api = widget.api as LocalFinanceApi;
      if (value == 'security') await showWorkspaceSecurity(context, api.vault);
      if (value == 'backups' && mounted) await showLocalBackups(context, api);
      if (value == 'categories' && mounted) await manageLocalCategories(context, api);
      if (value == 'rules' && mounted) await showCategoryRules(context, api);
      if (value == 'profiles' && mounted) await showSavedImportProfiles(context, api);
      if (value == 'reconcile' && mounted) await showReconciliation(context, api);
      if (value == 'import' && mounted) await showCsvImport(context, api);
      if (mounted) await _refresh();
    } catch (error) { _showError(error); }
    finally { if (mounted) setState(() => _toolBusy = false); }
  }
  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
  }
  Future<void> _logout() async {
    try { await widget.api.logout(); }
    catch (error) { if (_local) { _showError(error); return; } widget.api.token = null; }
    if (mounted) widget.onLogout();
  }
  static const _destinations = <({String label, IconData icon})>[
    (label: 'Home', icon: Icons.home_outlined),
    (label: 'Accounts', icon: Icons.account_balance_wallet_outlined),
    (label: 'Transactions', icon: Icons.swap_horiz),
    (label: 'Budgets', icon: Icons.pie_chart_outline),
    (label: 'Scheduled', icon: Icons.event_repeat_outlined),
    (label: 'Calendar', icon: Icons.calendar_month_outlined),
    (label: 'Forecasts', icon: Icons.show_chart_outlined),
    (label: 'Reports', icon: Icons.assessment_outlined),
    (label: 'Settings', icon: Icons.settings_outlined),
    (label: 'Connections', icon: Icons.account_balance_outlined),
    (label: 'Needs Review', icon: Icons.inbox_outlined),
  ];
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      drawer: isWide ? null : NavigationDrawer(selectedIndex: _page,
        onDestinationSelected: (index) { Navigator.pop(context); setState(() => _page = index); },
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(28, 20, 20, 12), child: Text('Budgetism navigation')),
          for (final item in _destinations) NavigationDrawerDestination(icon: Icon(item.icon), label: Text(item.label)),
        ]),
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_wallet_outlined, color: _accent), const SizedBox(width: 10),
          Flexible(child: Text(isWide ? 'Budgetism' : _destinations[_page].label, maxLines: 1,
            overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        actions: [
          if (widget.api.isDemo) Tooltip(message: 'Demo data exists only in memory', child: Icon(Icons.science_outlined, color: _accent))
          else if (_local) Tooltip(message: 'Encrypted local workspace. Not synchronized.', child: Icon(Icons.lock_outline, color: _accent))
          else if (_error != null) Tooltip(message: 'Server unavailable; offline edits not yet implemented', child: Icon(Icons.cloud_off_outlined, color: _accent))
          else Tooltip(message: 'Connected to private server', child: Icon(Icons.cloud_done_outlined, color: Theme.of(context).colorScheme.tertiary)),
          IconButton(tooltip: 'Refresh', onPressed: () => _refresh(), icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Toggle light/dark mode', onPressed: widget.onToggleTheme, icon: const Icon(Icons.brightness_6_outlined)),
          PopupMenuButton<String>(tooltip: 'User options', onSelected: (v) {
            if (v == 'logout') _logout();
            if (v == 'updates') widget.onCheckUpdates();
            if (v == 'settings') setState(() => _page = 8);
            if (v == 'backups' || v == 'categories' || v == 'security' || v == 'import' || v == 'reconcile') _localOptions(v);
          }, itemBuilder: (_) => [
            const PopupMenuItem(value: 'settings', child: Text('Settings and tools')),
            if (_local) const PopupMenuItem(value: 'reconcile', child: Text('Reconcile statements')),
            if (_local) const PopupMenuItem(value: 'import', child: Text('Import CSV statement')),
            if (_local) const PopupMenuItem(value: 'security', child: Text('Workspace security')),
            if (_local) const PopupMenuItem(value: 'categories', child: Text('Manage categories')),
            if (_local) const PopupMenuItem(value: 'backups', child: Text('Backups and storage')),
            const PopupMenuItem(value: 'updates', child: Text('Check for updates')),
            PopupMenuItem(value: 'logout', child: Text(_local
              ? ((widget.api as LocalFinanceApi).vault.passwordRequired ? 'Lock workspace' : 'Close workspace')
              : 'Sign out (${widget.username})'))], icon: const Icon(Icons.account_circle_outlined)),
        ],
      ),
      body: Column(children: [
        if (_local) const MaterialBanner(
          content: Text('LOCAL PREVIEW: saved on this device only. No cross-device sync yet. Keep separate backups; not production-ready.'), actions: [SizedBox.shrink()]),
        if (widget.api.isDemo) const MaterialBanner(
          content: Text('DEMO MODE: fictitious finances. Changes are in memory and disappear when you close the app.'), actions: [SizedBox.shrink()]),
        Expanded(child: Row(children: [
          if (isWide) NavigationRail(scrollable: true, extended: MediaQuery.sizeOf(context).width >= 1100,
            selectedIndex: _page, onDestinationSelected: (i) => setState(() => _page = i),
            destinations: _destinations.map((d) => NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label))).toList()),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
            onRefresh: _refresh, child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_error != null) Card(color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(padding: const EdgeInsets.all(14), child: Text(_local ? 'Local workspace issue: $_error' :
                      'Connection issue: $_error\nData shown may be out of date. Offline edits are not supported in this build.'))),
                  if (_page == 0 && _local) DailyHomePanel(snapshot: (widget.api as LocalFinanceApi).vault.ledger.snapshot(),
                    onNavigate: (index) => setState(() {
                      _page = index;
                      if (index == 3) _budgetMonth = DateTime.now().toIso8601String().substring(0, 7);
                    }), onAdd: _createTransaction,
                    onAddAccount: _createAccount, onInspect: _inspectHome),
                  if (_page == 0 && !_local) _dashboard(),
                  if (_page == 9 && _local) BankConnectionsPanel(api: widget.api as LocalFinanceApi,
                    onChanged: () => _refresh(silent: true), onReview: () => setState(() => _page = 10)),
                  if (_page == 10 && _local) NeedsReviewPanel(api: widget.api as LocalFinanceApi,
                    onChanged: () => _refresh(silent: true), onConnections: () => setState(() => _page = 9)),
                  if (_page == 9 && !_local && !widget.api.isDemo) ServerSandboxPanel(api: widget.api,
                    key: const ValueKey('server-sandbox-panel')),
                  if (_page == 9 && !_local && !widget.api.isDemo) ServerBankLauncher(api: widget.api,
                    onChanged: () => _refresh(silent: true)),
                  if (_page == 9 && widget.api.isDemo) _futureFeature('Fictional bank simulation', Icons.science_outlined,
                    'Open a saved local workspace to set up fictional accounts and review simulated activity.'),
                  if (_page == 10 && !_local && !widget.api.isDemo) ServerBankPanel(api: widget.api,
                    onChanged: () => _refresh(silent: true)),
                  if (_page == 10 && widget.api.isDemo) _futureFeature('Bank review', Icons.inbox_outlined,
                    'Open a saved local workspace or sign in to your private Sandbox server to review fictional activity.'),
                  if (_page == 8) WorkspaceToolsPanel(local: _local, busy: _toolBusy,
                    passwordRequired: _local && (widget.api as LocalFinanceApi).vault.passwordRequired, onAction: _localOptions),
                  if (_page == 1) _accountsView(),
                  if (_page == 2 && _local) TransactionRegisterPanel(
                    readSnapshot: () => (widget.api as LocalFinanceApi).vault.ledger.snapshot(includeVoided: true),
                    initialFilter: _registerFilter, onFilterChanged: (value) => _registerFilter = value,
                    onEdit: _editLocalTransaction, onImport: () => _localOptions('import')),
                  if (_page == 2 && !_local) _transactionsView(),
                  if (_page == 3 && _local) BudgetPanel(api: widget.api as LocalFinanceApi,
                    month: _budgetMonth, onMonthChanged: (value) => setState(() => _budgetMonth = value),
                    onChanged: () => _refresh(silent: true), onOpenTransaction: _editLocalTransaction),
                  if (_page == 3 && !_local) _futureFeature('Budgets', Icons.pie_chart_outline,
                    'Monthly budgets are available in a saved local workspace. Demo and server budgets are not implemented.'),
                  if (_page == 4 && _local) SchedulePanel(api: widget.api as LocalFinanceApi,
                    onChanged: () => _refresh(silent: true), onOpenTransaction: _editLocalTransaction),
                  if (_page == 4 && !_local) _futureFeature('Scheduled', Icons.event_repeat_outlined,
                    'Recurring bills and income are available in the saved local workspace.'),
                  if ((_page == 5 || _page == 6) && _local) PlanningPanel(key: ValueKey('planning:$_page'),
                    api: widget.api as LocalFinanceApi, calendar: _page == 5, onOpenTransaction: _editLocalTransaction,
                    onOpenScheduled: () => setState(() => _page = 4)),
                  if (_page == 7 && _local) ReportPanel(readSnapshot: () => (widget.api as LocalFinanceApi).vault.ledger.snapshot(includeVoided: true)),
                  if (_page == 7 && !_local) _futureFeature('Reports', Icons.assessment_outlined,
                    'Open your saved local workspace to report on recorded financial activity.'),
                  if ((_page == 5 || _page == 6) && !_local) _futureFeature('Calendar and forecasts', Icons.show_chart_outlined,
                    'Open your saved local workspace to view its calendar and scheduled cash flow.'),
                ])))),
            ]))),
        ])),
      ]),
      floatingActionButton: (_page <= 2 || (_local && _page < 8)) ? FloatingActionButton.extended(
        onPressed: _page == 1 ? _createAccount : _createTransaction, icon: const Icon(Icons.add),
        label: Text(_page == 1 ? 'Add account' : 'Add transaction')) : null,
      bottomNavigationBar: isWide ? null : Builder(builder: (scaffoldContext) => NavigationBar(
        height: 70, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, selectedIndex: _page < 4 ? _page : 4,
        onDestinationSelected: (index) {
          if (index == 4) { Scaffold.of(scaffoldContext).openDrawer(); }
          else { setState(() => _page = index); }
        }, destinations: [
          for (final item in _destinations.take(4)) NavigationDestination(icon: Icon(item.icon), label: item.label),
          const NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      )),
    );
  }

  Widget _title(String title, String subtitle, {VoidCallback? onAction, String? action}) =>
    Padding(padding: const EdgeInsets.only(bottom: 18), child: Wrap(alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 12, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5), Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
        if (onAction != null) OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.add), label: Text(action ?? 'Add')),
      ]));
  Widget _stat(String label, String amount, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 24, color: _accent), const SizedBox(height: 20),
      Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 6),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(amount, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
    ])));
  Widget _dashboard() {
    final assets = _accounts.where((a) => !['credit_card', 'loan', 'liability'].contains(a['type']))
      .fold<int>(0, (total, a) => total + (a['balanceMinor'] as num).toInt());
    final worth = _accounts.fold<int>(0, (total, a) => total + (a['balanceMinor'] as num).toInt());
    final prefix = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final spent = _transactions.where((x) => x['kind'] == 'expense' && (x['effectiveDate'] as String).startsWith(prefix))
      .fold<int>(0, (total, x) => total + (x['amountMinor'] as num).toInt());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Financial overview', 'Your actual balances and posted activity'),
      LayoutBuilder(builder: (context, c) => GridView.count(crossAxisCount: c.maxWidth > 700 ? 3 : 1,
        childAspectRatio: c.maxWidth > 700 ? 1.8 : 2.5, mainAxisSpacing: 10, crossAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, children: [
          _stat('Assets and cash', money(assets), Icons.account_balance_wallet_outlined),
          _stat('Net worth', money(worth), Icons.stacked_line_chart),
          _stat('Spent this month', money(spent), Icons.receipt_long_outlined),
        ])),
      const SizedBox(height: 24),
      if (_local) BudgetOverview(snapshot: (widget.api as LocalFinanceApi).vault.ledger.snapshot(),
        onOpen: () => setState(() { _page = 3; _budgetMonth = DateTime.now().toIso8601String().substring(0, 7); })),
      if (_local) ScheduleOverview(snapshot: (widget.api as LocalFinanceApi).vault.ledger.snapshot(), onOpen: () => setState(() => _page = 4)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Recent transactions', style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: () => setState(() => _page = 2), child: const Text('View all')),
      ]),
      _transactionList(_transactions.reversed.take(8).toList(), compact: true),
      if (_lastUpdated != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(widget.api.isDemo ? 'Demo data refreshed' :
        _local ? 'Saved locally on this device' : 'Last server refresh: ${_lastUpdated!.toLocal()}', style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
  Widget _accountsView() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_local) OutlinedButton.icon(onPressed: () => _localOptions('reconcile'), icon: const Icon(Icons.fact_check_outlined), label: const Text('Reconcile statements')),
    _title('Accounts', widget.api.isDemo ? '${_accounts.length} sample accounts' : _local ? '${_accounts.length} saved local accounts. Select an account to edit.' : '${_accounts.length} accounts on your private server',
      onAction: _createAccount, action: 'Add account'),
    if (_accounts.isEmpty) const _EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No accounts yet', details: 'Create checking, savings, cash, or credit accounts to begin.'),
    ..._accounts.map((a) => Card(child: ListTile(onTap: _local ? () => _createAccount(existing: a) : null,
      leading: CircleAvatar(backgroundColor: _accent.withValues(alpha: .15), child: Icon(a['type'] == 'credit_card' ? Icons.credit_card : Icons.account_balance_outlined, color: _accent)),
      title: Text(a['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${a['type']} | ${a['currency']}'),
      trailing: Text(money(a['balanceMinor']), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    ))),
  ]);
  Widget _transactionsView() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_local) Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: () => _localOptions('import'), icon: const Icon(Icons.file_upload_outlined), label: const Text('Import CSV'))),
    _title('Transactions', 'Journal-backed transactions, including account transfers', onAction: _createTransaction, action: 'Add transaction'),
    TextField(decoration: const InputDecoration(labelText: 'Search payee, notes, account, or category', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
      onChanged: (v) => setState(() { _query = v; _transactionLimit = 100; })),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(key: ValueKey('account-filter:$_filterAccount'), initialValue: _filterAccount,
      decoration: const InputDecoration(labelText: 'Account filter', border: OutlineInputBorder()),
      items: [const DropdownMenuItem(value: '', child: Text('All accounts')), ..._accounts.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text(a['name'] as String)))],
      onChanged: (v) => setState(() { _filterAccount = v ?? ''; _transactionLimit = 100; })),
    const SizedBox(height: 12), Text('${_filteredTransactions.length} matching transactions${_local ? '. Select one to edit.' : ''}'),
    const SizedBox(height: 8), _transactionList(_filteredTransactions, compact: false),
    if (_filteredTransactions.length > _transactionLimit) TextButton(onPressed: () => setState(() => _transactionLimit += 100), child: const Text('Show 100 more')),
    const SizedBox(height: 80),
  ]);
  List<Map<String, dynamic>> get _filteredTransactions {
    final names = {for (final r in [..._accounts, ..._categories]) r['id']: r['name']};
    final query = _query.trim().toLowerCase();
    return _transactions.reversed.where((t) {
      if (_filterAccount.isNotEmpty && t['accountId'] != _filterAccount && !(t['kind'] == 'transfer' && t['counterpartyAccountId'] == _filterAccount)) return false;
      final parts = t['splits'] as List? ?? [];
      final text = '${t['payee']} ${t['notes']} ${names[t['accountId']]} ${names[t['counterpartyAccountId']]} '
        '${parts.map((p) => names[p['categoryId']]).join(' ')}'.toLowerCase();
      return query.isEmpty || text.contains(query);
    }).toList();
  }
  Widget _transactionList(List<Map<String, dynamic>> entries, {required bool compact}) {
    if (entries.isEmpty) return const _EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions', details: 'Record an expense, income, or transfer to get started.');
    final shown = compact ? entries : entries.take(_transactionLimit).toList();
    final accountNames = {for (final a in _accounts) a['id']: a['name']};
    final categoryNames = {for (final c in _categories) c['id']: c['name']};
    return Card(child: Column(children: [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18),
        ListTile(onTap: _local ? () => _editLocalTransaction(shown[i]) : null,
          leading: CircleAvatar(backgroundColor: _accent.withValues(alpha: .12), child: Icon(switch (shown[i]['kind']) {
            'income' => Icons.south_west, 'transfer' => Icons.swap_horiz, 'opening' => Icons.account_balance, _ => Icons.north_east,
          }, color: _accent)),
          title: Text((shown[i]['payee'] as String).isEmpty ? shown[i]['kind'] as String : shown[i]['payee'] as String),
          subtitle: Text('${shown[i]['effectiveDate']} | ${accountNames[shown[i]['accountId']] ?? 'Account'}'
            ' | ${(shown[i]['splits'] as List? ?? []).isNotEmpty ? 'Split categories' : categoryNames[shown[i]['counterpartyAccountId']] ?? accountNames[shown[i]['counterpartyAccountId']] ?? shown[i]['kind']}'),
          trailing: Text('${shown[i]['kind'] == 'income' || shown[i]['kind'] == 'expense' && (shown[i]['amountMinor'] as int) < 0 ? '+' : shown[i]['kind'] == 'expense' ? '-' : ''}${money((shown[i]['amountMinor'] as int).abs())}', style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    ]));
  }
  Widget _futureFeature(String title, IconData icon, String description) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _title(title, 'Planned for a later development milestone'),
    _EmptyState(icon: icon, title: '$title is not implemented yet', details: description),
  ]);
}
