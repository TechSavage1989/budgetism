import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../money.dart';
import 'bank_provider.dart';
import 'ledger.dart';
import 'local_api.dart';

const bankReasonLabels = <String, String>{
  'category_needed': 'Choose a category',
  'potential_duplicate': 'Possible existing entry',
  'pending_ambiguity': 'Uncertain pending replacement',
  'possible_transfer': 'Possible transfer or card payment',
  'scheduled_match': 'Possible scheduled payment',
  'bank_correction': 'Bank correction',
  'bank_removal': 'Bank removed this entry',
  'reconciliation_conflict': 'Reconciled entry is protected',
  'recorded_entry_voided': 'Recorded entry was voided',
  'connection_problem': 'Refresh needs attention',
};

String _stamp(Object? value) => value == null ? 'Never' : DateTime.parse(value as String).toLocal().toString();

class BankConnectionsPanel extends StatefulWidget {
  const BankConnectionsPanel({super.key, required this.api, required this.onChanged, required this.onReview});
  final LocalFinanceApi api;
  final Future<void> Function() onChanged;
  final VoidCallback onReview;
  @override
  State<BankConnectionsPanel> createState() => _BankConnectionsPanelState();
}

class _BankConnectionsPanelState extends State<BankConnectionsPanel> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        await widget.onChanged();
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _setup() => _run(() async {
    await widget.api.snapshot();
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => BankMappingDialog(snapshot: widget.api.vault.ledger.snapshot(), onSave: widget.api.connectSimulation),
    );
  });
  Future<void> _state(Json c) => _run(() async {
    final connected = c['connected'] != true;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(connected ? 'Reconnect simulation?' : 'Disconnect simulation?'),
            content: Text(
              connected
                  ? 'Continue the same fictional feed using the saved accounts and checkpoint.'
                  : 'Stop refreshes. All source records, account links and recorded history will remain.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(connected ? 'Reconnect' : 'Disconnect'),
              ),
            ],
          ),
    );
    if (yes == true) {
      await widget.api.setBankConnected({
        'operationId': const Uuid().v4(),
        'expectedRevision': widget.api.vault.ledger.revision,
        'connectionId': c['id'],
        'connected': connected,
        'confirmReviewed': true,
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    final data = widget.api.vault.ledger.snapshot(includeVoided: true);
    final connections = BankSync.list(data, 'bankConnections');
    final accounts = BankSync.list(data, 'accounts');
    final sources = BankSync.list(data, 'bankSources');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connections', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Fictional simulation only. No bank login or network access. Refreshing stores source records; '
          'Needs Review controls what enters your recorded balances. Pending authorizations never count as spending.',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, key: const Key('bank-error')),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (connections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: FilledButton.icon(
              key: const Key('bank-setup'),
              onPressed: _busy ? null : _setup,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Set up fictional connection'),
            ),
          ),
        for (final c in connections) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['institution'] as String, style: Theme.of(context).textTheme.titleLarge),
                  Text(c['connected'] == true ? 'Connected to local simulation' : 'Disconnected'),
                  Text('Refresh: ${_busy ? 'in progress' : c['refreshStatus']}'),
                  Text('Last successful refresh: ${_stamp(c['lastSuccessUtc'])}'),
                  Text('Feed data timestamp: ${_stamp(c['dataTimestampUtc'])}'),
                  Text('Last attempted refresh: ${_stamp(c['lastAttemptUtc'])}'),
                  if (c['refreshStatus'] == 'error')
                    const Text(
                      'Refresh failed. Previous source records and checkpoint are retained. Retry when ready.',
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const Key('bank-refresh'),
                        onPressed:
                            _busy || c['connected'] != true
                                ? null
                                : () => _run(() => widget.api.bankRefresh.refresh(c['id'])),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh fictional feed'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : widget.onReview,
                        child: Text('Needs Review (${BankSync.inbox(data).length})'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _state(c),
                        child: Text(c['connected'] == true ? 'Disconnect' : 'Reconnect'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    r'Refresh 1 loads authorizations and posted examples. Refresh 2 posts the $25 → $28 cafe and $100 → $54.32 fuel charges, '
                    r'corrects a merchant, removes an order, and adds a refund. Refresh 3 changes the bookshop amount to $13.50. Later refreshes are unchanged.',
                  ),
                  ExpansionTile(
                    title: const Text('Test refresh recovery'),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            key: const Key('bank-repeat'),
                            onPressed:
                                _busy || c['connected'] != true || c['lastSuccessUtc'] == null
                                    ? null
                                    : () => _run(() => widget.api.bankRefresh.refresh(c['id'], repeatLast: true)),
                            child: const Text('Repeat last feed'),
                          ),
                          OutlinedButton(
                            key: const Key('bank-interrupt'),
                            onPressed:
                                _busy || c['connected'] != true
                                    ? null
                                    : () => _run(
                                      () => widget.api.bankRefresh.refresh(c['id'], interruptAfterFirstPage: true),
                                    ),
                            child: const Text('Interrupt next refresh'),
                          ),
                        ],
                      ),
                      const Text(
                        'An interrupted refresh saves no partial source batch. Use Refresh fictional feed to retry.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final link in BankSync.list(data, 'bankAccounts').where((a) => a['connectionId'] == c['id']))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(link['name'], style: Theme.of(context).textTheme.titleMedium),
                    Text('Mapped to ${accounts.firstWhere((a) => a['id'] == link['accountId'])['name']}'),
                    Text(
                      'Recorded balance (all recorded dates): ${money(accounts.firstWhere((a) => a['id'] == link['accountId'])['balanceMinor'])}',
                    ),
                    Text(
                      'Bank-reported balance: ${link['reportedBalanceMinor'] == null ? 'Not retrieved' : money(link['reportedBalanceMinor'])}',
                    ),
                    Text(
                      'Available balance: ${link['availableBalanceMinor'] == null ? 'Not supplied' : money(link['availableBalanceMinor'])}',
                    ),
                    Text(
                      'Bank values as of ${_stamp(link['dataTimestampUtc'])}. Available already includes pending activity where supplied.',
                    ),
                    Text(
                      'History begins ${link['historyFrom']}. Fictional opening baseline: ${money(link['openingBalanceMinor'])}. Existing opening balances are preserved.',
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (sources.isNotEmpty)
          ExpansionTile(
            title: Text('Source records (${sources.length})'),
            subtitle: const Text(
              'Includes pending, replaced and removed records. These are separate from Transactions.',
            ),
            children: [
              for (final s in sources)
                ListTile(
                  title: Text(s['description']),
                  trailing: Text(money(s['signedMinor'])),
                  subtitle: Text(
                    '${s['date']} • ${s['state']}${s['supersededBy'] != null ? ' • replaced by posted record' : ''}'
                    '${s['transactionId'] != null ? ' • linked to recorded entry' : ''}',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class BankMappingDialog extends StatefulWidget {
  const BankMappingDialog({super.key, required this.snapshot, required this.onSave});
  final Json snapshot;
  final Future<void> Function(Json) onSave;
  @override
  State<BankMappingDialog> createState() => _BankMappingDialogState();
}

class _BankMappingDialogState extends State<BankMappingDialog> {
  final _mapping = <String, String>{};
  bool _fictional = false, _upgrade = false, _busy = false;
  String? _error;
  Json? _request;
  void _change(VoidCallback change) => setState(() {
    change();
    _request = null;
  });
  Future<void> _save() async {
    if (_busy || !_fictional || ((widget.snapshot['schema'] as int) < LocalLedger.bankSchema && !_upgrade)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _request ??= {
      'operationId': const Uuid().v4(),
      'expectedRevision': widget.snapshot['cursor'],
      'providerId': BankSync.simulatedProvider,
      'confirmReviewed': true,
      'confirmFictional': true,
      'confirmBankUpgrade': _upgrade,
      'accounts': [
        for (final a in SimulatedBankProvider.accounts)
          {...a, 'accountId': (_mapping[a['sourceAccountId']] ?? '').isEmpty ? null : _mapping[a['sourceAccountId']]},
      ],
    };
    try {
      await widget.onSave(_request!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Map fictional accounts'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use new fictional accounts or existing fictional test accounts. Do not map these examples to real accounts. '
              'New accounts start with the displayed baseline before October 1, 2026. Existing account balances are unchanged. '
              'The first refresh stages history for review and never adds that baseline again.',
            ),
            for (final a in SimulatedBankProvider.accounts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a['name']} • USD • ${a['type']}'),
                    Text('Opening baseline: ${money(a['openingBalanceMinor'])}'),
                    DropdownButtonFormField<String>(
                      key: ValueKey('mapping-${a['sourceAccountId']}'),
                      initialValue: _mapping[a['sourceAccountId']] ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Budgetism account'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Create this fictional account')),
                        for (final target in BankSync.list(
                          widget.snapshot,
                          'accounts',
                        ).where((t) => t['currency'] == 'USD' && t['type'] == a['type'] && t['archived'] != true))
                          DropdownMenuItem(
                            value: target['id'] as String,
                            child: Text(target['name'], overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged:
                          _busy
                              ? null
                              : (value) => _change(() => _mapping[a['sourceAccountId'] as String] = value ?? ''),
                    ),
                  ],
                ),
              ),
            CheckboxListTile(
              key: const Key('bank-fictional-consent'),
              value: _fictional,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'All selected accounts are for fictional testing. I reviewed the opening balances and mapping.',
              ),
              onChanged: _busy ? null : (value) => _change(() => _fictional = value == true),
            ),
            if ((widget.snapshot['schema'] as int) < LocalLedger.bankSchema)
              CheckboxListTile(
                key: const Key('bank-upgrade-consent'),
                value: _upgrade,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'I have exported a backup and approve format 8. Older Budgetism builds cannot open this workspace afterward.',
                ),
                onChanged: _busy ? null : (value) => _change(() => _upgrade = value == true),
              ),
            if (_error != null) Text(_error!, key: const Key('bank-mapping-error')),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        key: const Key('bank-mapping-save'),
        onPressed:
            _busy || !_fictional || ((widget.snapshot['schema'] as int) < LocalLedger.bankSchema && !_upgrade)
                ? null
                : _save,
        child: Text(_busy ? 'Saving…' : 'Save account mapping'),
      ),
    ],
  );
}

class NeedsReviewPanel extends StatefulWidget {
  const NeedsReviewPanel({super.key, required this.api, required this.onChanged, required this.onConnections});
  final LocalFinanceApi api;
  final Future<void> Function() onChanged;
  final VoidCallback onConnections;
  @override
  State<NeedsReviewPanel> createState() => _NeedsReviewPanelState();
}

class _NeedsReviewPanelState extends State<NeedsReviewPanel> {
  bool _busy = false;
  String? _error;
  Future<void> _review(String sourceId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.snapshot();
      if (!mounted) return;
      final snapshot = widget.api.vault.ledger.snapshot(includeVoided: true);
      final item = BankSync.inbox(snapshot).where((r) => r['id'] == sourceId).firstOrNull;
      if (item == null) return;
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BankReviewDialog(snapshot: snapshot, item: item, onSave: widget.api.reviewBankSource),
      );
      if (mounted) await widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.api.vault.ledger.snapshot(includeVoided: true);
    final items = BankSync.inbox(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Needs Review (${items.length})',
          key: const Key('review-heading'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Review source changes, possible duplicates, transfers, scheduled matches and connection problems in one place. '
          'Categories and notes stay yours. Reconciled entries stay protected.',
        ),
        if (_error != null) Text(_error!),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nothing needs review. Pending activity remains visible in Connections.'),
          ),
        for (final item in items)
          Card(
            child: ListTile(
              key: ValueKey('review-${item['id']}'),
              title: Text(
                item['source'] == null ? 'Fictional connection needs attention' : item['source']['description'],
              ),
              subtitle: Text(
                [
                  if (item['source'] != null)
                    '${item['source']['date']} • ${money(item['source']['signedMinor'])} • '
                        '${BankSync.accountLink(data, Map<String, dynamic>.from(item['source']))['name']}',
                  ...(item['reasons'] as List).map((r) => bankReasonLabels[r] ?? r.toString()),
                ].join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  _busy
                      ? null
                      : item['source'] == null
                      ? widget.onConnections
                      : () => _review(item['id']),
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class BankReviewDialog extends StatefulWidget {
  const BankReviewDialog({super.key, required this.snapshot, required this.item, required this.onSave});
  final Json snapshot, item;
  final Future<void> Function(Json) onSave;
  @override
  State<BankReviewDialog> createState() => _BankReviewDialogState();
}

class _BankReviewDialogState extends State<BankReviewDialog> {
  String _decision = '', _category = '', _transaction = '', _pair = '', _account = '', _schedule = '';
  bool _confirmed = false, _duplicate = false, _pending = false, _separate = false, _busy = false;
  final _reason = TextEditingController(), _notes = TextEditingController();
  String? _error;
  Json? _request;
  Json get _source => Map<String, dynamic>.from(widget.item['source']);
  Json? get _linked =>
      BankSync.list(widget.snapshot, 'transactions').where((t) => t['id'] == _source['transactionId']).firstOrNull;
  void _change(VoidCallback callback) => setState(() {
    callback();
    _confirmed = false;
    _request = null;
  });
  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_confirmed || _decision.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final selected =
        BankSync.list(widget.snapshot, 'transactions').where((t) => t['id'] == _transaction).firstOrNull ?? _linked;
    final pair = BankSync.transferCandidates(widget.snapshot, _source).where((s) => s['id'] == _pair).firstOrNull;
    final schedule =
        BankSync.scheduleCandidates(
          widget.snapshot,
          _source,
        ).where((s) => '${s['scheduleId']}/${s['index']}' == _schedule).firstOrNull;
    _request ??= {
      'operationId': const Uuid().v4(),
      'expectedRevision': widget.snapshot['cursor'],
      'sourceId': _source['id'],
      'expectedSourceRevision': _source['revision'],
      'decision': _decision,
      'confirmReviewed': true,
      'confirmDuplicate': _duplicate,
      'confirmPending': _pending,
      'confirmSeparate': _separate,
      if (_category.isNotEmpty) 'categoryId': _category,
      'transactionId': selected?['id'],
      'expectedTransactionVersion': selected?['version'],
      if (pair != null) ...{'otherSourceId': pair['id'], 'expectedOtherSourceRevision': pair['revision']},
      if (_account.isNotEmpty) 'otherAccountId': _account,
      if (schedule != null) ...{'scheduleId': schedule['scheduleId'], 'index': schedule['index']},
      'reason': _reason.text,
      'notes': _notes.text,
    };
    try {
      await widget.onSave(_request!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  Widget _choose(String key, String label, String value, Map<String, String> choices, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: DropdownButtonFormField<String>(
          key: ValueKey(key),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: '', child: Text('Choose…')),
            for (final c in choices.entries)
              DropdownMenuItem(value: c.key, child: Text(c.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _busy ? null : (v) => _change(() => onChanged(v ?? '')),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final source = _source, linked = _linked;
    final candidates = BankSync.duplicateCandidates(widget.snapshot, source);
    final pairs = BankSync.transferCandidates(widget.snapshot, source);
    final paired = pairs.where((p) => p['id'] == _pair).firstOrNull;
    final otherDuplicates = paired == null ? <Json>[] : BankSync.duplicateCandidates(widget.snapshot, paired);
    final schedules = BankSync.scheduleCandidates(widget.snapshot, source);
    final locked = linked != null && Reconciliation.locked(widget.snapshot, linked['id']);
    final reasons = widget.item['reasons'] as List;
    final actions = <String, String>{
      if (linked == null && source['state'] == 'posted') ...{
        'record': 'Record with a category',
        if (candidates.isNotEmpty) 'match': 'Link an existing entry',
        'transfer': 'Record one transfer / card payment',
        'ignore': 'Ignore this source revision',
      },
      if (linked != null) ...{
        'keep': 'Keep the recorded entry unchanged',
        if (!locked && linked['voided'] == false && source['reviewedRevision'] != source['revision'])
          source['state'] == 'removed' ? 'remove' : 'correct':
              source['state'] == 'removed' ? 'Void the recorded entry' : 'Apply amount / date correction',
        if (schedules.isNotEmpty) ...{
          'schedule': 'Match a scheduled payment',
          'dismiss-schedule': 'Dismiss schedule suggestions',
        },
      },
    };
    return AlertDialog(
      title: const Text('Review source activity'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(source['description'], style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${BankSync.accountLink(widget.snapshot, source)['name']} • ${source['date']} • ${money(source['signedMinor'])} • ${source['state']}',
              ),
              Text(reasons.map((r) => bankReasonLabels[r] ?? r).join('\n')),
              if (linked != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Recorded: ${linked['payee']} • ${linked['effectiveDate']} • ${money(linked['amountMinor'])}\n'
                    'Category / destination: ${[...BankSync.list(widget.snapshot, 'categories'), ...BankSync.list(widget.snapshot, 'accounts')].where((a) => a['id'] == linked['counterpartyAccountId']).firstOrNull?['name'] ?? 'Split'}\n'
                    'Notes: ${linked['notes']}\nCorrections preserve your payee, categories, splits, notes and schedule links.',
                  ),
                ),
              if (locked)
                const Text(
                  'Reopen all relevant statements in Reconcile before changing this entry. Keeping it unchanged records your decision without rewriting statement history.',
                ),
              _choose('bank-decision', 'Action', _decision, actions, (v) {
                _decision = v;
                _category = '';
                _pair = '';
                _account = '';
              }),
              if (_decision == 'record') ...[
                _choose('bank-category', 'Category', _category, {
                  for (final c in BankSync.list(
                    widget.snapshot,
                    'categories',
                  ).where((c) => c['kind'] == ((source['signedMinor'] as int) < 0 ? 'Expense' : 'Income')))
                    c['id'] as String: c['name'] as String,
                }, (v) => _category = v),
                TextField(
                  key: const Key('bank-notes'),
                  controller: _notes,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Your notes'),
                  onChanged: (_) => _change(() {}),
                ),
              ],
              if (_decision == 'match')
                _choose('bank-match', 'Existing entry (same date and account amount)', _transaction, {
                  for (final t in candidates)
                    t['id'] as String: '${t['payee']} • ${t['effectiveDate']} • ${money(t['amountMinor'])}',
                }, (v) => _transaction = v),
              if (_decision == 'transfer') ...[
                const Text(
                  'A transfer posts once between two accounts. It is never income or spending. Either select the other source side or choose a recorded account.',
                ),
                if (pairs.isNotEmpty)
                  _choose(
                    'bank-pair',
                    'Other reported side',
                    _pair,
                    {
                      for (final p in pairs)
                        p['id'] as String:
                            '${BankSync.accountLink(widget.snapshot, p)['name']} • ${money(p['signedMinor'])} • ${p['date']}',
                    },
                    (v) {
                      _pair = v;
                      _account = '';
                    },
                  ),
                if (_pair.isEmpty)
                  _choose(
                    'bank-transfer-account',
                    (source['signedMinor'] as int) < 0 ? 'Destination account' : 'Sending account',
                    _account,
                    {
                      for (final a in BankSync.list(
                        widget.snapshot,
                        'accounts',
                      ).where((a) => a['id'] != BankSync.accountLink(widget.snapshot, source)['accountId']))
                        a['id'] as String: a['name'] as String,
                    },
                    (v) => _account = v,
                  ),
              ],
              if (_decision == 'schedule')
                _choose('bank-schedule', 'Scheduled occurrence', _schedule, {
                  for (final s in schedules) '${s['scheduleId']}/${s['index']}': '${s['name']} • ${s['dueDate']}',
                }, (v) => _schedule = v),
              if (['keep', 'ignore'].contains(_decision))
                TextField(
                  key: const Key('bank-reason'),
                  controller: _reason,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Reason for this decision'),
                  onChanged: (_) => _change(() {}),
                ),
              if (['record', 'transfer'].contains(_decision)) ...[
                for (final candidate in [...candidates, if (_decision == 'transfer') ...otherDuplicates])
                  Text(
                    'Existing entry to compare: ${candidate['payee']} • ${candidate['effectiveDate']} • ${money(candidate['amountMinor'])}',
                  ),
                if (candidates.isNotEmpty || (_decision == 'transfer' && otherDuplicates.isNotEmpty))
                  CheckboxListTile(
                    value: _duplicate,
                    title: const Text(
                      'I reviewed the existing entries on each selected account and this is a separate transaction.',
                    ),
                    onChanged: _busy ? null : (v) => _change(() => _duplicate = v == true),
                  ),
                if (reasons.contains('pending_ambiguity'))
                  CheckboxListTile(
                    value: _pending,
                    title: const Text(
                      'I reviewed the uncertain pending entry. Keep its identity separate until the feed resolves it.',
                    ),
                    onChanged: _busy ? null : (v) => _change(() => _pending = v == true),
                  ),
                if (_decision == 'record' && source['transferKey'] != null)
                  CheckboxListTile(
                    value: _separate,
                    title: const Text(
                      'I reviewed the transfer hint and intentionally classify this as income or spending.',
                    ),
                    onChanged: _busy ? null : (v) => _change(() => _separate = v == true),
                  ),
              ],
              if (_decision == 'remove')
                const Text(
                  'This explicitly voids the linked transaction. Source records, import receipts, schedule relationships and audit history remain.',
                ),
              CheckboxListTile(
                key: const Key('bank-review-consent'),
                value: _confirmed,
                title: const Text('I reviewed this action and its effect on recorded balances.'),
                onChanged:
                    _busy
                        ? null
                        : (v) => setState(() {
                          _confirmed = v == true;
                          _request = null;
                        }),
              ),
              if (_error != null) Text(_error!, key: const Key('bank-review-error')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('bank-review-save'),
          onPressed: _busy || !_confirmed || _decision.isEmpty ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save review decision'),
        ),
      ],
    );
  }
}
