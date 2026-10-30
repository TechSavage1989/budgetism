import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'finance_api.dart';
import 'server_sandbox_widgets.dart';
import 'server_bank_widgets.dart';
import 'server_address.dart';
import 'appearance.dart';
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

class BudgetismApp extends StatefulWidget {
  const BudgetismApp({super.key});
  @override
  State<BudgetismApp> createState() => _BudgetismAppState();
}

class _BudgetismAppState extends State<BudgetismApp> with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appearancePreferences = AppearancePreferences();
  AppAppearance _appearance = const AppAppearance();
  int _appearanceRevision = 0;
  bool _appearanceOpen = false;
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
    final appearanceRevision = _appearanceRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (appearanceRevision == _appearanceRevision) setState(() => _appearance = AppAppearance.read(prefs));
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
    final dark = _appearance.mode == ThemeMode.dark || _appearance.mode == ThemeMode.system &&
      WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    await _applyAppearance(_appearance.copyWith(mode: dark ? ThemeMode.light : ThemeMode.dark));
  }

  Future<void> _applyAppearance(AppAppearance value) async {
    final revision = ++_appearanceRevision;
    setState(() => _appearance = value);
    try { await _appearancePreferences.save(value); }
    catch (_) { if (mounted && revision == _appearanceRevision) {
      _messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Appearance applied for this session, but could not be saved.')));
    } }
  }

  Future<void> _openAppearance() async {
    final overlay = _navigatorKey.currentState?.overlay;
    if (_appearanceOpen || overlay == null) return;
    _appearanceOpen = true;
    try {
      final value = await showDialog<AppAppearance>(context: overlay.context,
        builder: (_) => AppearanceDialog(initial: _appearance));
      if (mounted && value != null) await _applyAppearance(value);
    } finally { _appearanceOpen = false; }
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      title: 'Budgetism',
      builder: (context, child) => Column(children: [
        _updateBanner(context),
        Expanded(child: child ?? const SizedBox.shrink()),
      ]),
      theme: _appearance.theme(Brightness.light), darkTheme: _appearance.theme(Brightness.dark), themeMode: _appearance.mode,
      home: _api == null
          ? ConnectionScreen(onCheckUpdates: () => _checkUpdates(manual: true), onAppearance: _openAppearance,
              onSignedIn: (api, username) {
              setState(() { _api = api; _username = username; });
            })
          : FinanceShell(
              api: _api!, username: _username,
              onCheckUpdates: () => _checkUpdates(manual: true),
              onLogout: () => setState(() { _api = null; _username = ''; }),
              onToggleTheme: _toggleTheme,
              onAppearance: _openAppearance,
            ),
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({required this.onSignedIn, required this.onCheckUpdates,
    this.addressPreferences, this.apiFactory, this.onAppearance, super.key});
  final void Function(FinanceApi, String) onSignedIn;
  final VoidCallback onCheckUpdates;
  final VoidCallback? onAppearance;
  final ServerAddressPreferences? addressPreferences;
  final FinanceApi Function(String)? apiFactory;
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  static const _configuredServer = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final _server = TextEditingController(text: _configuredServer);
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _bootstrap = TextEditingController();
  bool? _initialized;
  bool _busy = false;
  String? _error;
  FinanceApi? _api;
  late final ServerAddressPreferences _addresses;
  bool _loadingAddress = true, _rememberAddress = false, _authenticating = false, _openingLocal = false;
  String? _savedAddress, _notice;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _addresses = widget.addressPreferences ?? ServerAddressPreferences();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final generation = _generation;
    try {
      final address = await _addresses.read();
      if (!mounted) return;
      setState(() {
        _savedAddress = address;
        if (generation == _generation && address != null) {
          if (_configuredServer.isEmpty) _server.text = address;
          _rememberAddress = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _notice = 'Saved address unavailable. Enter your trusted HTTPS address.');
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
    if (mounted && generation == _generation && kIsWeb && _configuredServer.isNotEmpty) _connect(persistAddress: false);
  }

  void _destinationChanged() {
    _generation++;
    _username.clear(); _password.clear(); _bootstrap.clear();
    setState(() { _initialized = null; _api = null; _busy = false; _error = null; _notice = null; });
  }

  Future<void> _forgetAddress() async {
    try {
      await _addresses.save(null);
      if (mounted) setState(() { _savedAddress = null; _rememberAddress = false; _notice = 'Saved address forgotten.'; });
    } catch (_) {
      if (mounted) setState(() => _notice = 'The saved address could not be removed. Try again.');
    }
  }

  Future<void> _connect({bool persistAddress = true}) async {
    if (_busy || _loadingAddress) return;
    final generation = ++_generation;
    setState(() { _busy = true; _error = null; });
    try {
      final address = ServerAddressPreferences.canonical(_server.text);
      if (address == null) throw FinanceApiException('Use a trusted private HTTPS server URL.', 0);
      final api = widget.apiFactory?.call(address) ?? FinanceApi(address);
      api.requireHttpsServer();
      final initialized = await api.isInitialized();
      if (!mounted || generation != _generation) return;
      if (persistAddress && (_rememberAddress || _savedAddress != null)) {
      try {
        final saved = _rememberAddress ? address : null;
        await _addresses.save(saved);
        if (mounted) setState(() => _savedAddress = saved);
      } catch (_) {
        if (mounted && generation == _generation) setState(() => _notice = 'Connected, but the address preference could not be saved.');
      }
      }
      if (mounted && generation == _generation) {
        setState(() {
        _server.text = address; _api = api; _initialized = initialized;
      });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error =
        error is FinanceApiException && error.message == 'Use a trusted private HTTPS server URL.'
          ? error.message : 'Could not confirm this server. Check its HTTPS address, certificate trust and connection.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _openLocal() async {
    if (_busy) return;
    _generation++;
    setState(() { _busy = true; _openingLocal = true; _error = null; });
    try {
      final api = await openLocalWorkspace(context);
      if (api != null && mounted) widget.onSignedIn(api, 'Local workspace');
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() { _busy = false; _openingLocal = false; }); }
  }

  void _openDemo() { _generation++; widget.onSignedIn(DemoFinanceApi(), 'Demo'); }

  Future<void> _submit() async {
    if (_busy) return;
    final api = _api;
    if (api == null) return;
    final generation = ++_generation;
    setState(() { _busy = true; _authenticating = true; _error = null; });
    try {
      if (_initialized == false) {
        await api.initialize(_username.text.trim(), _password.text, _bootstrap.text.trim());
      }
      final username = await api.login(_username.text.trim(), _password.text);
      if (mounted && generation == _generation && identical(_api, api)) widget.onSignedIn(api, username);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error is FinanceApiException &&
        (error.statusCode == 401 || error.statusCode == 403) ? 'Sign-in failed. Check your owner login.' :
        error is FinanceApiException && error.statusCode == 429 ? 'Too many sign-in attempts. Wait before trying again.' :
        'Sign-in did not finish. Check your connection and try again.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() { _busy = false; _authenticating = false; });
    }
  }

  @override
  void dispose() {
    _generation++;
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
                  Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary, size: 44),
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
                  TextField(controller: _server, enabled: !_authenticating && !_openingLocal, decoration: const InputDecoration(
                    labelText: 'Private server URL', hintText: 'https://finance.private.example',
                    prefixIcon: Icon(Icons.dns_outlined), border: OutlineInputBorder(),
                    helperText: 'Use your trusted private HTTPS address.',
                  ), onChanged: (_) => _destinationChanged()),
                  CheckboxListTile(value: _rememberAddress, contentPadding: EdgeInsets.zero,
                    onChanged: _busy || _loadingAddress ? null : (value) {
                      setState(() => _rememberAddress = value ?? false);
                      if (value != true && _savedAddress != null) _forgetAddress();
                    },
                    title: const Text('Remember server address on this device'),
                    subtitle: const Text('Address only, stored without encryption. Your password is not saved.')),
                  if (_savedAddress != null) TextButton(onPressed: _busy ? null : _forgetAddress,
                    child: const Text('Forget saved address')),
                  const SizedBox(height: 14),
                  if (_initialized == null)
                    FilledButton.icon(onPressed: _busy || _loadingAddress ? null : _connect,
                        icon: const Icon(Icons.link), label: const Text('Connect to server')),
                  if (_initialized != null) ...[
                    if (_initialized == false) ...[
                      const Text('First-time owner setup', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextField(controller: _bootstrap, obscureText: true, enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Server bootstrap token',
                          border: OutlineInputBorder(), prefixIcon: Icon(Icons.key_outlined))),
                      const SizedBox(height: 12),
                    ],
                    TextField(controller: _username, autocorrect: false, enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'Username',
                        border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: _password, obscureText: true, enabled: !_busy,
                      onSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(labelText: 'Password',
                        helperText: _initialized == false ? 'At least 14 characters' : null,
                        border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline))),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _busy ? null : _submit,
                      child: Text(_initialized == false ? 'Create private workspace' : 'Sign in')),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _busy ? null : _destinationChanged,
                      child: const Text('Change server')),
                  ],
                  if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator()),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  if (_notice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_notice!)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openDemo,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Explore with sample data'),
                  ),
                  const SizedBox(height: 12),
                  if (widget.onAppearance != null) TextButton.icon(onPressed: widget.onAppearance,
                    icon: const Icon(Icons.palette_outlined), label: const Text('Appearance and themes')),
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
      Icon(icon, size: 45, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 15),
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
