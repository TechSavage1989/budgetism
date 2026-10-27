import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'finance_api.dart';
import 'demo_finance_api.dart';
import 'release_feed.dart';
import 'release_download.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BudgetismApp());
}

const _accent = Color(0xFFC97367);
const _darkSurface = Color(0xFF16191E);
const _darkBackground = Color(0xFF101216);

class BudgetismApp extends StatefulWidget {
  const BudgetismApp({super.key});
  @override
  State<BudgetismApp> createState() => _BudgetismAppState();
}

class _BudgetismAppState extends State<BudgetismApp> with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  ReleaseFeed? _releaseFeed;
  ReleaseCheckResult? _releaseResult;
  Timer? _releaseTimer;
  bool _active = true;
  bool _downloading = false;
  double _downloadProgress = 0;
  String? _downloadPath;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startReleaseChecks();
  }

  Future<void> _startReleaseChecks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _releaseFeed = ReleaseFeed(prefs: prefs);
      _checkUpdates();
      _releaseTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (_active) _checkUpdates();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _releaseResult = const ReleaseCheckResult(
          ReleaseCheckStatus.error, 'Unable to initialize the update checker.'));
      }
    }
  }

  Future<void> _checkUpdates({bool manual = false, bool focusReturn = false}) async {
    final feed = _releaseFeed;
    if (feed == null) {
      if (manual) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Update checker is initializing. Try again.')));
      }
      return;
    }
    final result = await feed.check(manual: manual, focusReturn: focusReturn);
    if (!mounted) return;
    setState(() => _releaseResult = result);
    if (manual) {
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _checkUpdates(focusReturn: true);
  }

  Future<void> _downloadRelease(ReleaseInfo release) async {
    if (_downloading) return;
    setState(() { _downloading = true; _downloadProgress = 0; _downloadError = null; });
    try {
      final path = await downloadVerifiedRelease(release, onProgress: (fraction) {
        if (mounted) setState(() => _downloadProgress = fraction);
      });
      if (mounted) setState(() => _downloadPath = path);
    } catch (error) {
      if (mounted) setState(() => _downloadError = error.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _releaseFeed?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _updateBanner(BuildContext themedContext) {
    final result = _releaseResult;
    if (result?.status != ReleaseCheckStatus.updateAvailable || result?.latest == null) {
      return const SizedBox.shrink();
    }
    final release = result!.latest!;
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return Material(
      color: Theme.of(themedContext).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6,
            children: [
              const Icon(Icons.system_update_alt, size: 19),
              Text('Budgetism ${release.version} available (installed $budgetismVersion)',
                style: const TextStyle(fontWeight: FontWeight.w700)),
              if (_downloadPath == null && release.hasVerifiedArchive && isWindows)
                OutlinedButton(onPressed: _downloading ? null : () => _downloadRelease(release),
                  child: const Text('Download')),
              if (_downloadPath != null)
                const Tooltip(message: 'Installation stays disabled until native Windows validation.',
                  child: OutlinedButton(onPressed: null, child: Text('Install and restart'))),
              if (release.hasMoreNotes)
                TextButton(onPressed: () => launchUrl(Uri.parse(release.url), mode: LaunchMode.externalApplication),
                  child: const Text('Read more')),
            ]),
          if (release.whatsNew.isNotEmpty)
            Text(release.whatsNew.take(3).join('  |  '), maxLines: 2,
              overflow: TextOverflow.ellipsis, style: Theme.of(themedContext).textTheme.bodySmall),
          if (!release.hasVerifiedArchive)
            Text('No verified Windows ZIP is available for this release.',
              style: Theme.of(themedContext).textTheme.bodySmall),
          if (_downloading) LinearProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null),
          if (_downloadPath != null)
            SelectableText('Verified download: $_downloadPath. Installation is not enabled in this development build.',
              style: Theme.of(themedContext).textTheme.bodySmall),
          if (_downloadError != null)
            Text('Download error: $_downloadError', style: TextStyle(color: Theme.of(themedContext).colorScheme.error)),
        ]),
      ),
    );
  }

  FinanceApi? _api;
  String _username = '';
  ThemeMode _theme = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(
      useMaterial3: true, colorSchemeSeed: _accent,
      scaffoldBackgroundColor: const Color(0xFFF5F5F4),
    );
    final dark = ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: _accent, brightness: Brightness.dark),
      scaffoldBackgroundColor: _darkBackground,
      cardTheme: const CardThemeData(color: _darkSurface, elevation: 0),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      title: 'Budgetism',
      builder: (context, child) => Column(children: [
        _updateBanner(context),
        Expanded(child: child ?? const SizedBox.shrink()),
      ]),
      theme: light, darkTheme: dark, themeMode: _theme,
      home: _api == null
          ? ConnectionScreen(onCheckUpdates: () => _checkUpdates(manual: true),
              onSignedIn: (api, username) {
              setState(() { _api = api; _username = username; });
            })
          : FinanceShell(
              api: _api!, username: _username,
              onCheckUpdates: () => _checkUpdates(manual: true),
              onLogout: () => setState(() { _api = null; _username = ''; }),
              onToggleTheme: () => setState(() {
                _theme = _theme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              }),
            ),
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({required this.onSignedIn, required this.onCheckUpdates, super.key});
  final void Function(FinanceApi, String) onSignedIn;
  final VoidCallback onCheckUpdates;
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  static const _configuredServer = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final _server = TextEditingController(text: _configuredServer.isNotEmpty
      ? _configuredServer : (kIsWeb ? '' : 'http://localhost:8088'));
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _bootstrap = TextEditingController();
  bool? _initialized;
  bool _busy = false;
  String? _error;
  FinanceApi? _api;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && _configuredServer.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    }
  }

  Future<void> _connect() async {
    setState(() { _busy = true; _error = null; });
    final api = FinanceApi(_server.text);
    try {
      final initialized = await api.isInitialized();
      if (mounted) setState(() { _api = api; _initialized = initialized; });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDemo() => widget.onSignedIn(DemoFinanceApi(), 'Demo');

  Future<void> _submit() async {
    final api = _api;
    if (api == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_initialized == false) {
        await api.initialize(_username.text.trim(), _password.text, _bootstrap.text.trim());
      }
      final username = await api.login(_username.text.trim(), _password.text);
      if (mounted) widget.onSignedIn(api, username);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _server.dispose(); _username.dispose(); _password.dispose(); _bootstrap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: _accent, size: 44),
                  const SizedBox(height: 16),
                  Text('Budgetism', textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Your finances. Your server.', textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  TextField(controller: _server, decoration: const InputDecoration(
                    labelText: 'Private server URL', hintText: 'https://finance.private.example',
                    prefixIcon: Icon(Icons.dns_outlined), border: OutlineInputBorder(),
                    helperText: 'Use VPN and HTTPS for access outside your device.',
                  ), onChanged: (_) { if (_initialized != null) setState(() { _initialized = null; _api = null; }); }),
                  const SizedBox(height: 14),
                  if (_initialized == null)
                    FilledButton.icon(onPressed: _busy ? null : _connect,
                        icon: const Icon(Icons.link), label: const Text('Connect to server')),
                  if (_initialized != null) ...[
                    if (_initialized == false) ...[
                      const Text('First-time owner setup', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextField(controller: _bootstrap, obscureText: true,
                        decoration: const InputDecoration(labelText: 'Server bootstrap token',
                          border: OutlineInputBorder(), prefixIcon: Icon(Icons.key_outlined))),
                      const SizedBox(height: 12),
                    ],
                    TextField(controller: _username, autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Username',
                        border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: _password, obscureText: true,
                      onSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(labelText: 'Password',
                        helperText: _initialized == false ? 'At least 14 characters' : null,
                        border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline))),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _busy ? null : _submit,
                      child: Text(_initialized == false ? 'Create private workspace' : 'Sign in')),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _busy ? null : () => setState(() { _initialized = null; _api = null; }),
                      child: const Text('Change server')),
                  ],
                  if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator()),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFEA8B84)))),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openDemo,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Explore with sample data'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: widget.onCheckUpdates,
                    child: const Text('Check for updates')),
                  const SizedBox(height: 6),
                  const Text('Demo changes are temporary and contain no personal data.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 20),
                  const Text('Development build 0.1.0-dev.1', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String money(Object? raw) {
  final number = raw is num ? raw.toInt() : 0;
  final negative = number < 0;
  final integer = (number.abs() ~/ 100).toString();
  final grouped = integer.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final cents = (number.abs() % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}\$$grouped.$cents';
}

int parseMinor(String input, {bool allowNegative = false}) {
  final value = input.trim().replaceAll(',', '');
  final pattern = allowNegative ? RegExp(r'^-?\d{1,12}(\.\d{1,2})?$')
                                : RegExp(r'^\d{1,12}(\.\d{1,2})?$');
  if (!pattern.hasMatch(value)) throw const FormatException('Enter a valid USD amount with up to two decimal places.');
  final parts = value.split('.');
  final negative = value.startsWith('-');
  final units = int.parse(parts[0].replaceFirst('-', ''));
  final cents = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return (negative ? -1 : 1) * (units * 100 + cents);
}

class FinanceShell extends StatefulWidget {
  const FinanceShell({required this.api, required this.username, required this.onLogout,
      required this.onToggleTheme, required this.onCheckUpdates, super.key});
  final FinanceApi api;
  final String username;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final VoidCallback onCheckUpdates;
  @override
  State<FinanceShell> createState() => _FinanceShellState();
}

class _FinanceShellState extends State<FinanceShell> {
  int _page = 0;
  bool _loading = true;
  bool _updating = false;
  String? _error;
  DateTime? _lastUpdated;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _transactions = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh(silent: true));
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
        _categories = (snapshot['categories'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _transactions = (snapshot['transactions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _error = null; _lastUpdated = DateTime.now();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _updating = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _createAccount() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => const CreateAccountDialog());
    if (result == null) return;
    try { await widget.api.createAccount(result); await _refresh(); }
    catch (error) { _showError(error); }
  }

  Future<void> _createTransaction() async {
    if (_accounts.isEmpty) { _showError('Create an account first.'); return; }
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => CreateTransactionDialog(
        accounts: _accounts, categories: _categories));
    if (result == null) return;
    try { await widget.api.createTransaction(result); await _refresh(); }
    catch (error) { _showError(error); }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _logout() async {
    try { await widget.api.logout(); } catch (_) { widget.api.token = null; }
    if (mounted) widget.onLogout();
  }

  static const _destinations = <({String label, IconData icon})>[
    (label: 'Dashboard', icon: Icons.dashboard_outlined),
    (label: 'Accounts', icon: Icons.account_balance_wallet_outlined),
    (label: 'Transactions', icon: Icons.swap_horiz),
    (label: 'Budgets', icon: Icons.pie_chart_outline),
    (label: 'Forecasts', icon: Icons.show_chart_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.account_balance_wallet_outlined, color: _accent),
          const SizedBox(width: 10),
          Text(isWide ? 'Budgetism' : _destinations[_page].label,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          if (widget.api.isDemo) const Tooltip(message: 'Demo data exists only in memory',
            child: Icon(Icons.science_outlined, color: _accent))
          else if (_error != null) Tooltip(message: 'Server unavailable; offline edits not yet implemented',
            child: const Icon(Icons.cloud_off_outlined, color: _accent))
          else const Tooltip(message: 'Connected to private server',
            child: Icon(Icons.cloud_done_outlined, color: Colors.greenAccent)),
          IconButton(tooltip: 'Refresh', onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Toggle light/dark mode', onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6_outlined)),
          PopupMenuButton<String>(tooltip: 'User options',
            onSelected: (v) {
              if (v == 'logout') _logout();
              if (v == 'updates') widget.onCheckUpdates();
            },
            itemBuilder: (_) => [const PopupMenuItem(value: 'updates', child: Text('Check for updates')),
              PopupMenuItem(value: 'logout',
              child: Text('Sign out (${widget.username})'))],
            icon: const Icon(Icons.account_circle_outlined)),
        ],
      ),
      body: Column(children: [
        if (widget.api.isDemo) const MaterialBanner(
          content: Text('DEMO MODE: fictitious finances. Changes are in memory and disappear when you close the app.'),
          actions: [SizedBox.shrink()],
        ),
        Expanded(child: Row(children: [
        if (isWide) NavigationRail(
          extended: MediaQuery.sizeOf(context).width >= 1100,
          selectedIndex: _page,
          onDestinationSelected: (i) => setState(() => _page = i),
          destinations: _destinations.map((d) => NavigationRailDestination(
            icon: Icon(d.icon), label: Text(d.label))).toList(),
        ),
        if (isWide) const VerticalDivider(width: 1),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                  Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(padding: const EdgeInsets.all(22),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_error != null) Card(color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(padding: const EdgeInsets.all(14),
                            child: Text('Connection issue: $_error\nData shown may be out of date. Offline edits are not supported in this build.'))),
                        if (_page == 0) _dashboard(),
                        if (_page == 1) _accountsView(),
                        if (_page == 2) _transactionsView(),
                        if (_page == 3) _futureFeature('Budgets', Icons.pie_chart_outline,
                            'Category budgets, rollover balances, and spending targets are next.'),
                        if (_page == 4) _futureFeature('Forecasts', Icons.show_chart_outlined,
                            'Daily cash flow forecasting and scheduled bills are planned after budgeting.'),
                      ])),
                  )),
                ]),
              )),
      ])),
      ]),
      floatingActionButton: (_page <= 2)
          ? FloatingActionButton.extended(
              onPressed: _page == 1 ? _createAccount : _createTransaction,
              icon: const Icon(Icons.add),
              label: Text(_page == 1 ? 'Add account' : 'Add transaction'))
          : null,
      bottomNavigationBar: isWide ? null : NavigationBar(
        height: 70,
        selectedIndex: _page,
        onDestinationSelected: (i) => setState(() => _page = i),
        destinations: _destinations.map((d) => NavigationDestination(
          icon: Icon(d.icon), label: d.label)).toList(),
      ),
    );
  }

  Widget _title(String title, String subtitle, {VoidCallback? onAction, String? action}) =>
      Padding(padding: const EdgeInsets.only(bottom: 18),
        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16, runSpacing: 12, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5), Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ]),
            if (onAction != null) OutlinedButton.icon(onPressed: onAction,
              icon: const Icon(Icons.add), label: Text(action ?? 'Add')),
          ]));

  Widget _stat(String label, String amount, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 24, color: _accent), const SizedBox(height: 20),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(amount, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
      ])));

  Widget _dashboard() {
    final assets = _accounts.where((a) => !['credit_card', 'loan', 'liability'].contains(a['type']))
        .fold<int>(0, (total, a) => total + (a['balanceMinor'] as num).toInt());
    final worth = _accounts.fold<int>(0, (total, a) => total + (a['balanceMinor'] as num).toInt());
    final prefix = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final spent = _transactions.where((x) => x['kind'] == 'expense' &&
        (x['effectiveDate'] as String).startsWith(prefix))
      .fold<int>(0, (total, x) => total + (x['amountMinor'] as num).toInt());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Financial overview', 'Your actual balances and posted activity'),
      LayoutBuilder(builder: (context, c) => GridView.count(
        crossAxisCount: c.maxWidth > 700 ? 3 : 1,
        childAspectRatio: c.maxWidth > 700 ? 1.8 : 2.5,
        mainAxisSpacing: 10, crossAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
        children: [
          _stat('Assets and cash', money(assets), Icons.account_balance_wallet_outlined),
          _stat('Net worth', money(worth), Icons.stacked_line_chart),
          _stat('Spent this month', money(spent), Icons.receipt_long_outlined),
        ],
      )),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Recent transactions', style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: () => setState(() => _page = 2), child: const Text('View all')),
      ]),
      _transactionList(_transactions.reversed.take(8).toList(), compact: true),
      if (_lastUpdated != null) Padding(padding: const EdgeInsets.only(top: 12),
        child: Text(widget.api.isDemo ? 'Demo data refreshed' : 'Last server refresh: ${_lastUpdated!.toLocal()}',
          style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }

  Widget _accountsView() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _title('Accounts', widget.api.isDemo ? '${_accounts.length} sample accounts' : '${_accounts.length} accounts on your private server',
      onAction: _createAccount, action: 'Add account'),
    if (_accounts.isEmpty) const _EmptyState(icon: Icons.account_balance_wallet_outlined,
      title: 'No accounts yet', details: 'Create checking, savings, cash, or credit accounts to begin.'),
    ..._accounts.map((a) => Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: _accent.withValues(alpha: .15),
        child: Icon(a['type'] == 'credit_card' ? Icons.credit_card : Icons.account_balance_outlined,
          color: _accent)),
      title: Text(a['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${a['type']} | ${a['currency']}'),
      trailing: Text(money(a['balanceMinor']), style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold)),
    ))),
  ]);

  Widget _transactionsView() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _title('Transactions', 'Journal-backed transactions, including account transfers',
      onAction: _createTransaction, action: 'Add transaction'),
    _transactionList(_transactions.reversed.toList(), compact: false),
  ]);

  Widget _transactionList(List<Map<String, dynamic>> entries, {required bool compact}) {
    if (entries.isEmpty) {
      return const _EmptyState(icon: Icons.receipt_long_outlined,
        title: 'No transactions', details: 'Record an expense, income, or transfer to get started.');
    }
    final shown = compact ? entries : entries.take(500).toList();
    final accountNames = {for (final a in _accounts) a['id']: a['name']};
    final categoryNames = {for (final c in _categories) c['id']: c['name']};
    return Card(child: Column(children: [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18),
        ListTile(
          leading: CircleAvatar(backgroundColor: _accent.withValues(alpha: .12),
            child: Icon(switch (shown[i]['kind']) {
              'income' => Icons.south_west,
              'transfer' => Icons.swap_horiz,
              'opening' => Icons.account_balance,
              _ => Icons.north_east,
            }, color: _accent)),
          title: Text((shown[i]['payee'] as String).isEmpty
            ? (shown[i]['kind'] as String) : (shown[i]['payee'] as String)),
          subtitle: Text('${shown[i]['effectiveDate']} | ${accountNames[shown[i]['accountId']] ?? 'Account'}'
            ' | ${categoryNames[shown[i]['counterpartyAccountId']] ?? accountNames[shown[i]['counterpartyAccountId']] ?? shown[i]['kind']}'),
          trailing: Text('${shown[i]['kind'] == 'income' ? '+' : shown[i]['kind'] == 'expense' ? '-' : ''}'
            '${money(shown[i]['amountMinor'])}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]
    ]));
  }

  Widget _futureFeature(String title, IconData icon, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(title, 'Planned for a later development milestone'),
      _EmptyState(icon: icon, title: '$title is not implemented yet', details: description),
    ]);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.details});
  final IconData icon;
  final String title;
  final String details;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 20),
    child: Center(child: Column(children: [
      Icon(icon, size: 45, color: _accent), const SizedBox(height: 15),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6), Text(details, textAlign: TextAlign.center),
    ])),
  ));
}

class CreateAccountDialog extends StatefulWidget {
  const CreateAccountDialog({super.key});
  @override
  State<CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<CreateAccountDialog> {
  final _name = TextEditingController();
  final _opening = TextEditingController(text: '0.00');
  String _type = 'checking';
  String? _error;
  @override
  void dispose() { _name.dispose(); _opening.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create account'),
    content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, autofocus: true, maxLength: 100,
          decoration: const InputDecoration(labelText: 'Account name', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: _type,
          decoration: const InputDecoration(labelText: 'Account type', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'checking', child: Text('Checking')),
            DropdownMenuItem(value: 'savings', child: Text('Savings')),
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'credit_card', child: Text('Credit card')),
            DropdownMenuItem(value: 'loan', child: Text('Loan')),
            DropdownMenuItem(value: 'asset', child: Text('Other asset')),
            DropdownMenuItem(value: 'liability', child: Text('Other liability')),
          ], onChanged: (v) => setState(() => _type = v ?? _type)),
        const SizedBox(height: 14),
        TextField(controller: _opening,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Opening balance (USD)',
            border: OutlineInputBorder(), helperText: 'For debt, use a negative amount.')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        try {
          final amount = parseMinor(_opening.text, allowNegative: true);
          if (_name.text.trim().isEmpty) throw const FormatException('Name is required.');
          Navigator.pop(context, {
            'operationId': const Uuid().v4(), 'name': _name.text.trim(),
            'type': _type, 'currency': 'USD', 'openingBalanceMinor': amount,
          });
        } catch (error) { setState(() => _error = error.toString()); }
      }, child: const Text('Create')),
    ],
  );
}

class CreateTransactionDialog extends StatefulWidget {
  const CreateTransactionDialog({required this.accounts, required this.categories, super.key});
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  @override
  State<CreateTransactionDialog> createState() => _CreateTransactionDialogState();
}

class _CreateTransactionDialogState extends State<CreateTransactionDialog> {
  final _payee = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String _kind = 'expense';
  String? _account;
  String? _counterparty;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() { super.initState(); _account = widget.accounts.first['id'] as String; }
  @override
  void dispose() { _payee.dispose(); _amount.dispose(); _notes.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _counterparties {
    if (_kind == 'transfer') return widget.accounts.where((a) => a['id'] != _account).toList();
    final kind = _kind == 'expense' ? 'Expense' : 'Income';
    return widget.categories.where((a) => a['kind'] == kind).toList();
  }

  @override
  Widget build(BuildContext context) {
    final counterparts = _counterparties;
    final counter = counterparts.any((x) => x['id'] == _counterparty)
        ? _counterparty : (counterparts.isNotEmpty ? counterparts.first['id'] as String : null);
    return AlertDialog(
      title: const Text('New transaction'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Transaction type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'expense', child: Text('Expense')),
              DropdownMenuItem(value: 'income', child: Text('Income')),
              DropdownMenuItem(value: 'transfer', child: Text('Transfer / card payment')),
            ], onChanged: (v) => setState(() { _kind = v ?? 'expense'; _counterparty = null; })),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: _account,
            decoration: const InputDecoration(labelText: 'From / primary account', border: OutlineInputBorder()),
            items: widget.accounts.map((a) => DropdownMenuItem<String>(
              value: a['id'] as String, child: Text(a['name'] as String))).toList(),
            onChanged: (v) => setState(() { _account = v; _counterparty = null; })),
          const SizedBox(height: 12),
          if (counterparts.isNotEmpty) DropdownButtonFormField<String>(
            key: ValueKey('$_kind|$_account'), initialValue: counter,
            decoration: InputDecoration(labelText: _kind == 'transfer' ? 'To account' : 'Category',
              border: const OutlineInputBorder()),
            items: counterparts.map((a) => DropdownMenuItem<String>(
              value: a['id'] as String, child: Text(a['name'] as String))).toList(),
            onChanged: (v) => setState(() => _counterparty = v)),
          const SizedBox(height: 12),
          TextField(controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(labelText: 'Amount (USD)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _payee, maxLength: 150,
            decoration: InputDecoration(labelText: _kind == 'transfer' ? 'Description' : 'Payee',
              border: const OutlineInputBorder())),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: () async {
            final chosen = await showDatePicker(context: context, initialDate: _date,
              firstDate: DateTime(1900), lastDate: DateTime(DateTime.now().year + 20));
            if (chosen != null) setState(() => _date = chosen);
          }, icon: const Icon(Icons.calendar_today_outlined),
             label: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}')),
          const SizedBox(height: 12),
          TextField(controller: _notes, maxLength: 500, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          try {
            final amount = parseMinor(_amount.text);
            if (amount <= 0) throw const FormatException('Amount must be greater than zero.');
            if (_account == null || counter == null) throw const FormatException('Select accounts and a category.');
            final date = '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
            Navigator.pop(context, {
              'operationId': const Uuid().v4(), 'kind': _kind,
              'accountId': _account, 'counterpartyAccountId': counter,
              'amountMinor': amount, 'currency': 'USD', 'effectiveDate': date,
              'payee': _payee.text.trim(), 'notes': _notes.text.trim(),
            });
          } catch (error) { setState(() => _error = error.toString()); }
        }, child: const Text('Save transaction')),
      ],
    );
  }
}
