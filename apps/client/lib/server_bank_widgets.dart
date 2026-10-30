import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'finance_api.dart';
import 'money.dart';
import 'server_bank.dart';
import 'review_filter.dart';
import 'batch_decision_dialog.dart';

class ServerBankLauncher extends StatefulWidget {
  const ServerBankLauncher({
    required this.api,
    required this.onChanged,
    super.key,
  });
  final FinanceApi api;
  final VoidCallback onChanged;
  @override
  State<ServerBankLauncher> createState() => _ServerBankLauncherState();
}

class _ServerBankLauncherState extends State<ServerBankLauncher> {
  bool _open = false;
  @override
  Widget build(BuildContext context) =>
      _open
          ? ServerBankPanel(api: widget.api, onChanged: widget.onChanged)
          : Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _open = true),
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('Open durable Sandbox review'),
            ),
          );
}

class ServerBankPanel extends StatefulWidget {
  const ServerBankPanel({
    required this.api,
    required this.onChanged,
    super.key,
  });
  final FinanceApi api;
  final VoidCallback onChanged;
  @override
  State<ServerBankPanel> createState() => _ServerBankPanelState();
}

class _ServerBankPanelState extends State<ServerBankPanel> {
  ServerBankState? _state;
  bool _busy = false;
  String? _error, _pendingRoute;
  Map<String, dynamic>? _pendingBody;
  int _generation = 0;
  ReviewFilter _filter = const ReviewFilter();
  final Set<String> _selected = {};
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ServerBankPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api)) {
      _generation++;
      _state = null;
      _pendingRoute = null;
      _pendingBody = null;
      _busy = false;
      _filter = const ReviewFilter();
      _search.clear();
      _selected.clear();
      _load();
    }
  }

  String _safeError(Object e) =>
      e is FinanceApiException
          ? e.message
          : 'The server returned invalid Sandbox data. Reload before continuing.';
  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    final generation = ++_generation, session = widget.api.token;
    final prior = _state;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.bankRequest(
        'state',
        null,
        more ? prior!.sources.length : null,
        more ? prior!.version : null,
      );
      final fresh = ServerBankState.parse(data);
      if (!mounted ||
          generation != _generation ||
          session != widget.api.token) {
        return;
      }
      setState(
        () =>
            _state =
                more
                    ? ServerBankState(
                      fresh.connection,
                      fresh.accounts,
                      [...prior!.sources, ...fresh.sources],
                      fresh.total,
                      fresh.needsReview,
                      fresh.hasMore,
                      batchSupported: fresh.batchSupported,
                    )
                    : fresh,
      );
      _selected.clear();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _state = null;
          _error = _safeError(e);
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _mutate(String route, Map<String, dynamic> input) async {
    if (_busy) return;
    final generation = ++_generation, session = widget.api.token;
    setState(() {
      _busy = true;
      _error = null;
      _pendingRoute = route;
      _pendingBody = Map.of(input);
    });
    var succeeded = false;
    try {
      final result = await widget.api.bankRequest(route, input);
      if (!mounted ||
          generation != _generation ||
          session != widget.api.token) {
        return;
      }
      succeeded = true;
      setState(() {
        _pendingRoute = null;
        _pendingBody = null;
      });
      if (result['ready'] == false) {
        setState(
          () =>
              _error =
                  'Initial Sandbox data is not ready. Its cursor was not advanced.',
        );
      }
      widget.onChanged();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = _safeError(e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
    if (mounted && succeeded) await _load();
  }

  Map<String, dynamic> _operation() => {
    'operationId': const Uuid().v4(),
    'expectedConnectionVersion': _state?.version ?? 0,
  };
  Future<bool> _confirm(String title, String explanation) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(title),
              content: SizedBox(width: 450, child: Text(explanation)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
      ) ??
      false;
  Future<void> _connect() async {
    if (await _confirm(
      'Use fictional Sandbox data?',
      'This discovers the retained fictional fixture on your private server. It connects no real bank and writes no ledger entries.',
    )) {
      await _mutate('connect', {..._operation(), 'confirmFictional': true});
    }
  }

  Future<void> _map(Map<String, dynamic> account) async {
    final controller = TextEditingController(
      text: 'Sandbox ${account['name']}',
    );
    bool fictional = false, zero = false;
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, set) => AlertDialog(
                  title: const Text('Create dedicated Sandbox account'),
                  content: SizedBox(
                    width: 490,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: controller,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Name must start with Sandbox ',
                          ),
                        ),
                        CheckboxListTile(
                          value: fictional,
                          onChanged: (v) => set(() => fictional = v ?? false),
                          title: const Text('This account is fictional.'),
                        ),
                        CheckboxListTile(
                          value: zero,
                          onChanged: (v) => set(() => zero = v ?? false),
                          title: const Text(
                            'Start recorded balance at \$0.00. Provider balances are separate reference values.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          fictional && zero
                              ? () =>
                                  Navigator.pop(context, controller.text.trim())
                              : null,
                      child: const Text('Create and map'),
                    ),
                  ],
                ),
          ),
    );
    controller.dispose();
    if (name != null && mounted) {
      await _mutate('map', {
        ..._operation(),
        'bankAccountId': account['id'],
        'name': name,
        'confirmFictional': true,
        'confirmZeroBaseline': true,
      });
    }
  }

  Future<void> _active() async {
    final active = _state!.connection!['active'] != true;
    if (await _confirm(
      active
          ? 'Resume fictional connection?'
          : 'Disconnect fictional connection?',
      'Saved source history and recorded entries are retained. Retrieval happens only when you press Refresh fictional sources.',
    )) {
      await _mutate('active', {..._operation(), 'active': active});
    }
  }

  Future<void> _review(Map<String, dynamic> source) async {
    final state = _state!;
    final session = widget.api.token;
    setState(() => _busy = true);
    Map<String, dynamic> snapshot;
    try {
      snapshot = await widget.api.snapshot();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Could not load current ledger entries and categories for duplicate review.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || !identical(state, _state) || session != widget.api.token) {
      return;
    }
    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => ServerBankReviewDialog(
            state: state,
            source: source,
            snapshot: snapshot,
          ),
    );
    if (input != null &&
        mounted &&
        session == widget.api.token &&
        identical(state, _state)) {
      await _mutate('review', {..._operation(), ...input});
    }
  }

  void _filterChanged(ReviewFilter value) => setState(() {
    _filter = value;
    _selected.clear();
  });
  Future<void> _dates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      initialDateRange:
          _filter.from == null || _filter.to == null
              ? null
              : DateTimeRange(
                start: DateTime.parse(_filter.from!),
                end: DateTime.parse(_filter.to!),
              ),
    );
    if (range != null && mounted) {
      _filterChanged(
        _filter.copyWith(
          from: range.start.toIso8601String().substring(0, 10),
          to: range.end.toIso8601String().substring(0, 10),
        ),
      );
    }
  }

  Future<void> _batch(String action) async {
    final state = _state!, session = widget.api.token;
    final selected =
        state.sources.where((s) => _selected.contains(s['id'])).toList();
    if (selected.isEmpty ||
        selected.length > 100 ||
        selected.any((s) => !ReviewFilter.batchEligible(s))) {
      return;
    }
    Map<String, dynamic>? snapshot;
    if (action == 'keep') {
      setState(() => _busy = true);
      try {
        snapshot = await widget.api.snapshot();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Could not load recorded entries for review.',
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted || !identical(state, _state) || session != widget.api.token) {
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder:
          (_) => BatchDecisionDialog(
            action: action,
            sources: selected,
            snapshot: snapshot,
          ),
    );
    if (reason == null ||
        !mounted ||
        session != widget.api.token ||
        !identical(state, _state)) {
      return;
    }
    selected.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    await _mutate('review-batch', {
      ..._operation(),
      'action': action,
      'reason': reason,
      'confirmed': true,
      'sources': [
        for (final s in selected)
          {'sourceId': s['id'], 'expectedSourceVersion': s['version']},
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state, enabled = !_busy && _pendingRoute == null;
    final names = {
      for (final a in state?.accounts ?? <Map<String, dynamic>>[])
        a['id']: a['name'],
    };
    final visible = _filter.apply(state?.sources ?? [], names);
    final eligible = visible.where(ReviewFilter.batchEligible).toList();
    final selected = visible.where((s) => _selected.contains(s['id'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server Sandbox · durable review',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Fictional data only. Refresh saves source history and a checkpoint; only an explicit review action records or links a ledger entry. Pending activity never posts. Dedicated accounts start at zero; provider balances are cached reference values, not recorded balances.',
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!),
            ),
          ),
        if (_pendingRoute != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'An action has no confirmed result. Retry uses its original operation ID and unchanged choices.',
                  ),
                  FilledButton(
                    onPressed:
                        _busy
                            ? null
                            : () => _mutate(_pendingRoute!, _pendingBody!),
                    child: const Text('Retry unchanged action'),
                  ),
                  TextButton(
                    onPressed:
                        _busy
                            ? null
                            : () async {
                              if (await _confirm(
                                'Discard retry and reload?',
                                'The previous action may already have completed. Reload and inspect the saved source decision before making another choice.',
                              )) {
                                setState(() {
                                  _pendingRoute = null;
                                  _pendingBody = null;
                                });
                                await _load();
                              }
                            },
                    child: const Text('Discard retry and reload'),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: enabled ? _load : null,
              child: const Text('Reload saved state'),
            ),
            if (state?.connection == null && state != null)
              FilledButton(
                onPressed: enabled ? _connect : null,
                child: const Text('Discover fictional fixture'),
              ),
            if (state?.connection != null) ...[
              FilledButton(
                onPressed:
                    enabled && state!.connection!['active'] == true
                        ? () => _mutate('refresh', _operation())
                        : null,
                child: const Text('Refresh fictional sources'),
              ),
              OutlinedButton(
                onPressed: enabled ? _active : null,
                child: Text(
                  state!.connection!['active'] == true
                      ? 'Disconnect'
                      : 'Resume',
                ),
              ),
            ],
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
        if (state != null) ...[
          for (final a in state.accounts)
            Card(
              child: ListTile(
                title: Text('${a['name']} · ${a['currency']} · ${a['type']}'),
                subtitle: Text(
                  'Reported: ${a['reportedBalanceMinor'] == null ? 'unavailable' : money(a['reportedBalanceMinor'])}'
                  ' · ${a['ledgerAccountId'] == null ? 'unmapped' : 'dedicated account mapped'}${a['available'] == true ? '' : ' · unavailable'}',
                ),
                trailing:
                    a['ledgerAccountId'] == null &&
                            a['supported'] == true &&
                            a['available'] == true
                        ? OutlinedButton(
                          onPressed: enabled ? () => _map(a) : null,
                          child: const Text('Map new account'),
                        )
                        : null,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Needs Review: ${state.needsReview} · Showing ${state.sources.length} of ${state.total} saved sources',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (state.connection != null)
            Text(
              'Last successful source refresh: ${state.connection!['lastSuccessUtc'] ?? 'never'}',
            ),
          if (state.connection?['lastErrorCode'] != null)
            const Text(
              'The last refresh did not complete. Earlier saved data and checkpoint were retained.',
            ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('review-search'),
            controller: _search,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Search loaded activity',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged:
                (value) => _filterChanged(_filter.copyWith(query: value)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<ReviewView>(
                  key: ValueKey('review-view-${_filter.view}'),
                  isExpanded: true,
                  initialValue: _filter.view,
                  decoration: const InputDecoration(labelText: 'Review status'),
                  items: [
                    for (final v in ReviewView.values)
                      DropdownMenuItem(
                        value: v,
                        child: Text(switch (v) {
                          ReviewView.all => 'All activity',
                          ReviewView.needsReview => 'Needs review',
                          ReviewView.pending => 'Pending',
                          ReviewView.linked => 'Linked',
                          ReviewView.unlinked => 'Unlinked',
                          ReviewView.ignored => 'Ignored',
                          ReviewView.removed => 'Removed',
                          ReviewView.superseded => 'Superseded',
                        }),
                      ),
                  ],
                  onChanged:
                      enabled
                          ? (v) => _filterChanged(_filter.copyWith(view: v))
                          : null,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('review-account-${_filter.account}'),
                  isExpanded: true,
                  initialValue: _filter.account,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All accounts'),
                    ),
                    for (final a in state.accounts)
                      DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text(
                          a['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      enabled
                          ? (v) => _filterChanged(_filter.copyWith(account: v))
                          : null,
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('review-direction-${_filter.direction}'),
                  isExpanded: true,
                  initialValue: _filter.direction,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Money in / out'),
                    ),
                    DropdownMenuItem(value: 'in', child: Text('Money in')),
                    DropdownMenuItem(value: 'out', child: Text('Money out')),
                  ],
                  onChanged:
                      enabled
                          ? (v) =>
                              _filterChanged(_filter.copyWith(direction: v))
                          : null,
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<ReviewOrder>(
                  key: ValueKey('review-order-${_filter.order}'),
                  isExpanded: true,
                  initialValue: _filter.order,
                  decoration: const InputDecoration(labelText: 'Sort'),
                  items: const [
                    DropdownMenuItem(
                      value: ReviewOrder.newest,
                      child: Text('Newest first'),
                    ),
                    DropdownMenuItem(
                      value: ReviewOrder.oldest,
                      child: Text('Oldest first'),
                    ),
                    DropdownMenuItem(
                      value: ReviewOrder.largest,
                      child: Text('Largest amount'),
                    ),
                  ],
                  onChanged:
                      enabled
                          ? (v) => _filterChanged(_filter.copyWith(order: v))
                          : null,
                ),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? _dates : null,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _filter.from == null
                      ? 'Date range'
                      : '${_filter.from} — ${_filter.to}',
                ),
              ),
              if (_filter.from != null)
                TextButton(
                  onPressed:
                      enabled
                          ? () =>
                              _filterChanged(_filter.copyWith(clearDates: true))
                          : null,
                  child: const Text('Clear dates'),
                ),
              TextButton(
                onPressed:
                    enabled
                        ? () {
                          _search.clear();
                          _filterChanged(const ReviewFilter());
                        }
                        : null,
                child: const Text('Reset filters'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '${visible.length} shown · ${state.sources.length} loaded · ${state.total} saved sources. Filters do not change balances.',
            ),
          ),
          if (state.batchSupported)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed:
                      enabled && eligible.isNotEmpty && eligible.length <= 100
                          ? () => setState(
                            () => _selected.addAll(
                              eligible.map((s) => s['id'] as String),
                            ),
                          )
                          : null,
                  child: const Text('Select visible eligible'),
                ),
                TextButton(
                  onPressed:
                      enabled && _selected.isNotEmpty
                          ? () => setState(_selected.clear)
                          : null,
                  child: const Text('Clear selection'),
                ),
                Text('${_selected.length} selected'),
                FilledButton(
                  onPressed:
                      enabled &&
                              selected.isNotEmpty &&
                              selected.every(
                                (s) =>
                                    s['linkedJournalEntryId'] == null &&
                                    s['needsReview'] == true,
                              )
                          ? () => _batch('ignore')
                          : null,
                  child: const Text('Ignore selected'),
                ),
                OutlinedButton(
                  onPressed:
                      enabled &&
                              selected.isNotEmpty &&
                              selected.every(
                                (s) =>
                                    s['linkedJournalEntryId'] != null &&
                                    s['needsReview'] == true,
                              )
                          ? () => _batch('keep')
                          : null,
                  child: const Text('Keep recorded unchanged'),
                ),
                OutlinedButton(
                  onPressed:
                      enabled &&
                              selected.isNotEmpty &&
                              selected.every(ReviewFilter.reopenEligible)
                          ? () => _batch('reopen')
                          : null,
                  child: const Text('Reopen decisions'),
                ),
              ],
            ),
          if (eligible.length > 100)
            const Text(
              'Narrow the filter to at most 100 eligible sources for Select visible.',
            ),
          if (selected
                  .map(
                    (s) =>
                        ReviewFilter.reopenEligible(s)
                            ? 'reopen'
                            : s['linkedJournalEntryId'] == null
                            ? 'ignore'
                            : 'keep',
                  )
                  .toSet()
                  .length >
              1)
            const Text(
              'Choose one decision group: unreviewed sources, linked conflicts, or previously ignored/kept decisions. Use the status filter to narrow this selection.',
            ),
          if (!state.batchSupported && state.connection != null)
            const Text(
              'Batch decisions require the updated server. Individual review remains available.',
            ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No loaded activity matches these filters.'),
            ),
          for (final s in visible)
            Card(
              child: ListTile(
                leading:
                    !state.batchSupported
                        ? null
                        : Checkbox(
                          value: _selected.contains(s['id']),
                          onChanged:
                              enabled &&
                                      ReviewFilter.batchEligible(s) &&
                                      (_selected.length < 100 ||
                                          _selected.contains(s['id']))
                                  ? (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(s['id'] as String);
                                    } else {
                                      _selected.remove(s['id']);
                                    }
                                  })
                                  : null,
                        ),
                title: Text(s['description'] as String? ?? 'Removed source'),
                subtitle: Text(
                  '${names[s['bankAccountId']]} · ${s['date'] ?? 'undated tombstone'} · ${s['status']}'
                  '${s['superseded'] == true ? ' · superseded' : ''} · ${s['decision'] ?? 'unreviewed'}',
                ),
                trailing: Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      s['amountMinor'] == null ? '—' : money(s['amountMinor']),
                    ),
                    if (s['needsReview'] == true)
                      OutlinedButton(
                        onPressed: enabled ? () => _review(s) : null,
                        child: const Text('Review'),
                      ),
                  ],
                ),
              ),
            ),
          if (state.hasMore)
            OutlinedButton(
              onPressed: enabled ? () => _load(more: true) : null,
              child: const Text('Load next 100 sources'),
            ),
        ],
      ],
    );
  }
}

class ServerBankReviewDialog extends StatefulWidget {
  const ServerBankReviewDialog({
    required this.state,
    required this.source,
    required this.snapshot,
    super.key,
  });
  final ServerBankState state;
  final Map<String, dynamic> source, snapshot;
  @override
  State<ServerBankReviewDialog> createState() => _ServerBankReviewDialogState();
}

class _ServerBankReviewDialogState extends State<ServerBankReviewDialog> {
  String _action = 'ignore', _kind = 'expense';
  String? _category, _entry, _other;
  bool _duplicates = false, _transfers = false, _confirmed = false;
  final _reason = TextEditingController(),
      _payee = TextEditingController(),
      _notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.source['linkedJournalEntryId'] != null) _action = 'keep';
    _kind =
        (widget.source['amountMinor'] as int? ?? 0) < 0 ? 'expense' : 'income';
    final description = widget.source['description'] as String? ?? '';
    _payee.text = description.substring(
      0,
      description.length > 150 ? 150 : description.length,
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    _payee.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source, linked = s['linkedJournalEntryId'] != null;
    final account = widget.state.accounts.singleWhere(
      (a) => a['id'] == s['bankAccountId'],
    );
    final categories =
        (widget.snapshot['categories'] as List)
            .cast<Map>()
            .where(
              (c) => c['kind'] == (_kind == 'income' ? 'Income' : 'Expense'),
            )
            .toList();
    final transactions =
        (widget.snapshot['transactions'] as List).cast<Map>().where((t) {
          if (t['kind'] == 'opening' || t['effectiveDate'] != s['date']) {
            return false;
          }
          final amount = t['amountMinor'] as int;
          final effect =
              t['accountId'] == account['ledgerAccountId']
                  ? (t['kind'] == 'income' ? amount : -amount)
                  : t['kind'] == 'transfer' &&
                      t['counterpartyAccountId'] == account['ledgerAccountId']
                  ? amount
                  : null;
          return effect == s['amountMinor'];
        }).toList();
    final pairs =
        widget.state.sources
            .where(
              (r) =>
                  r['id'] != s['id'] &&
                  r['bankAccountId'] != s['bankAccountId'] &&
                  r['status'] == 'posted' &&
                  r['linkedJournalEntryId'] == null &&
                  r['superseded'] == false &&
                  r['date'] == s['date'] &&
                  r['amountMinor'] == -(s['amountMinor'] as int? ?? 0) &&
                  widget.state.accounts.any(
                    (a) =>
                        a['id'] == r['bankAccountId'] &&
                        a['ledgerAccountId'] != null,
                  ),
            )
            .toList();
    final needsPosting = {'record', 'match', 'pair'}.contains(_action);
    final ready =
        _confirmed &&
        (!needsPosting || _duplicates && _transfers) &&
        (needsPosting || _reason.text.trim().isNotEmpty) &&
        (_action != 'record' || _category != null) &&
        (_action != 'match' || _entry != null) &&
        (_action != 'pair' || _other != null);
    Widget select(
      String label,
      String? value,
      List<DropdownMenuItem<String>> items,
      ValueChanged<String?> changed,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: changed,
      ),
    );
    return AlertDialog(
      title: const Text('Review fictional source'),
      content: SizedBox(
        width: 590,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s['description']} · ${s['date']} · ${money(s['amountMinor'] ?? 0)}',
              ),
              if (linked)
                const Text(
                  'This source is already linked. Changes and removals never rewrite the saved entry. Keep unchanged records a reason; server correction and void tools are not available yet.',
                ),
              select(
                'Action',
                _action,
                [
                  for (final action
                      in linked
                          ? ['keep']
                          : ['ignore', 'record', 'match', 'pair'])
                    DropdownMenuItem(
                      value: action,
                      child: Text(switch (action) {
                        'keep' => 'Keep recorded entry unchanged',
                        'ignore' => 'Ignore source',
                        'record' => 'Record new entry',
                        'match' => 'Match existing entry',
                        _ => 'Pair transfer sides',
                      }),
                    ),
                ],
                (v) => setState(() {
                  _action = v!;
                  _confirmed = false;
                }),
              ),
              if (_action == 'record') ...[
                select(
                  'Record as',
                  _kind,
                  [
                    for (final kind
                        in (s['amountMinor'] as int) < 0
                            ? ['expense']
                            : ['income', 'refund'])
                      DropdownMenuItem(value: kind, child: Text(kind)),
                  ],
                  (v) => setState(() {
                    _kind = v!;
                    _category = null;
                    _confirmed = false;
                  }),
                ),
                select(
                  'Category',
                  _category,
                  [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ),
                  ],
                  (v) => setState(() {
                    _category = v;
                    _confirmed = false;
                  }),
                ),
              ],
              if (_action == 'match')
                select(
                  'Exact date and amount candidates',
                  _entry,
                  [
                    for (final t in transactions)
                      DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(
                          '${t['payee']} · ${t['effectiveDate']} · ${money(t['amountMinor'])}',
                        ),
                      ),
                  ],
                  (v) => setState(() {
                    _entry = v;
                    _confirmed = false;
                  }),
                ),
              if (_action == 'pair') ...[
                const Text(
                  'Candidates are limited to loaded sources. Load additional pages first if the other side is missing. A pair records one transfer, with no expense or income entry.',
                ),
                select(
                  'Opposite transfer side',
                  _other,
                  [
                    for (final r in pairs)
                      DropdownMenuItem(
                        value: r['id'] as String,
                        child: Text(
                          '${r['description']} · ${money(r['amountMinor'])}',
                        ),
                      ),
                  ],
                  (v) => setState(() {
                    _other = v;
                    _confirmed = false;
                  }),
                ),
              ],
              if (_action == 'record' || _action == 'pair') ...[
                TextField(
                  controller: _payee,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Payee'),
                  onChanged: (_) => setState(() => _confirmed = false),
                ),
                TextField(
                  controller: _notes,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onChanged: (_) => setState(() => _confirmed = false),
                ),
              ],
              if (!needsPosting)
                TextField(
                  controller: _reason,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Required reason',
                  ),
                  onChanged: (_) => setState(() => _confirmed = false),
                ),
              if (needsPosting) ...[
                Text(
                  'Existing exact date/amount candidates: ${transactions.length}. Inspect the register before creating a duplicate.',
                ),
                CheckboxListTile(
                  value: _duplicates,
                  onChanged:
                      (v) => setState(() {
                        _duplicates = v ?? false;
                        _confirmed = false;
                      }),
                  title: const Text(
                    'I reviewed existing entries for duplicates.',
                  ),
                ),
                CheckboxListTile(
                  value: _transfers,
                  onChanged:
                      (v) => setState(() {
                        _transfers = v ?? false;
                        _confirmed = false;
                      }),
                  title: const Text(
                    'I reviewed transfers and card payments; this choice will not double-count them.',
                  ),
                ),
              ],
              CheckboxListTile(
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: const Text(
                  'Apply this explicit choice to the server’s fictional records.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              !ready
                  ? null
                  : () => Navigator.pop(context, <String, dynamic>{
                    'sourceId': s['id'],
                    'expectedSourceVersion': s['version'],
                    'action': _action,
                    'kind': _kind,
                    'categoryId': _category,
                    'existingJournalId': _entry,
                    'otherSourceId': _other,
                    'otherSourceVersion':
                        _other == null
                            ? null
                            : pairs.singleWhere(
                              (r) => r['id'] == _other,
                            )['version'],
                    'payee': _payee.text,
                    'notes': _notes.text,
                    'reason': _reason.text.trim(),
                    'confirmed': true,
                    'reviewedDuplicates': _duplicates,
                    'reviewedTransfers': _transfers,
                  }),
          child: const Text('Apply reviewed choice'),
        ),
      ],
    );
  }
}
