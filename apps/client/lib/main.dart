import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'finance_api.dart';
import 'money.dart';
import 'local/local_api.dart';
import 'local/bank_widgets.dart';
import 'local/ledger.dart';
import 'local/daily_workspace.dart';
import 'local/category_rule_widgets.dart';
import 'local/reconciliation_widgets.dart';
import 'local/csv_import_widgets.dart';
import 'local/budget_widgets.dart';
import 'local/schedule_widgets.dart';
import 'local/planning_widgets.dart';
import 'local/report_widgets.dart';
import 'local/transaction_register.dart';
import 'local/transaction_register_widgets.dart';
import 'local/storage.dart';
import 'local/workspace_dialogs.dart';
import 'local/security_dialogs.dart';
import 'local/transaction_editor.dart';
import 'demo_finance_api.dart';
import 'release_feed.dart';
import 'release_download.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

export 'money.dart';

part 'finance_shell.dart';

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
  SharedPreferences? _preferences;
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
      _preferences = prefs;
      setState(() => _theme = prefs.getString('appearance.theme') == 'light' ? ThemeMode.light : ThemeMode.dark);
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

  Future<void> _toggleTheme() async {
    setState(() => _theme = _theme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
    try { await _preferences?.setString('appearance.theme', _theme == ThemeMode.light ? 'light' : 'dark'); }
    catch (_) { _messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Theme changed, but the preference could not be saved.'))); }
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
              onToggleTheme: _toggleTheme,
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

  Future<void> _openLocal() async {
    setState(() { _busy = true; _error = null; });
    try {
      final api = await openLocalWorkspace(context);
      if (api != null && mounted) widget.onSignedIn(api, 'Local workspace');
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
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
                  Text('Your finances. Your control.', textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 22),
                  if (localStorageSupported) ...[
                    FilledButton.icon(onPressed: _busy ? null : _openLocal,
                      icon: const Icon(Icons.lock_outline), label: const Text('Open local workspace')),
                    const SizedBox(height: 8),
                    const Text('Encrypted, saved on this device. No server required.', textAlign: TextAlign.center),
                    const SizedBox(height: 22),
                  ],
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
                  const Text('Development build $budgetismVersion', textAlign: TextAlign.center,
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
  const CreateAccountDialog({this.existing, this.onSave, super.key});
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>)? onSave;
  @override
  State<CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<CreateAccountDialog> {
  final _name = TextEditingController();
  final _opening = TextEditingController(text: '0.00');
  String _type = 'checking';
  bool _saving = false;
  final _operation = const Uuid().v4();
  String? _error;
  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) { _name.text = a['name'] as String; _type = a['type'] as String;
      _opening.text = decimalAmount(a['openingBalanceMinor'] as int); }
  }
  @override
  void dispose() { _name.dispose(); _opening.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_saving, child: AlertDialog(
    title: Text(widget.existing == null ? 'Create account' : 'Edit account'),
    content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, enabled: !_saving, autofocus: true, maxLength: 100,
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
          ], onChanged: _saving ? null : (v) => setState(() => _type = v ?? _type)),
        const SizedBox(height: 14),
        TextField(controller: _opening, enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Opening balance (USD)',
            border: OutlineInputBorder(), helperText: 'For debt, use a negative amount. This changes the opening balance, not a transaction.')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      ]))),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _saving ? null : () async {
        try {
          final amount = parseMinor(_opening.text, allowNegative: true);
          if (_name.text.trim().isEmpty) throw const FormatException('Name is required.');
          final result = <String, dynamic>{
            'operationId': _operation, 'name': _name.text.trim(),
            'type': _type, 'currency': 'USD', 'openingBalanceMinor': amount,
            if (widget.existing != null) ...{'id': widget.existing!['id'], 'expectedVersion': widget.existing!['version']},
          };
          if (widget.onSave != null) {
            setState(() { _saving = true; _error = null; });
            await widget.onSave!(result);
          }
          if (context.mounted) Navigator.pop(context, result);
        } catch (error) { if (mounted) setState(() { _saving = false; _error = error.toString(); }); }
      }, child: Text(_saving ? 'Saving...' : widget.existing == null ? 'Create' : 'Save account')),
    ],
  ));
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
