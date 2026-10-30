import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'finance_api.dart';
import 'money.dart';
import 'date_controls.dart';
import 'local/recurrence.dart';
import 'server_planning.dart';
import 'local/ledger.dart';
import 'local/budget_widgets.dart';
import 'local/schedule_widgets.dart';
import 'local/planning_widgets.dart';
import 'local/report_widgets.dart';

class ServerWorkspacePanel extends StatefulWidget {
  const ServerWorkspacePanel({
    super.key,
    required this.api,
    required this.page,
    required this.onChanged,
    required this.onNavigate,
  });
  final FinanceApi api;
  final int page;
  final Future<void> Function() onChanged;
  final ValueChanged<int> onNavigate;
  @override
  State<ServerWorkspacePanel> createState() => _ServerWorkspacePanelState();
}

class _ServerWorkspacePanelState extends State<ServerWorkspacePanel> {
  late ServerPlanningApi _api;
  bool _loading = true;
  String? _error;
  String _month = DateTime.now().toIso8601String().substring(0, 7);
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _api = ServerPlanningApi(widget.api);
    _reload();
  }

  @override
  void didUpdateWidget(covariant ServerWorkspacePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      _api = ServerPlanningApi(widget.api);
      _reload();
    }
  }

  Future<void> _reload() async {
    if (_api.busy) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.refresh();
    } catch (_) {
      if (mounted && generation == _generation) {
        _error =
            'Server planning could not be loaded. Check the connection or verified storage upgrade. No records were changed.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changed() async {
    if (mounted) setState(() {});
    await widget.onChanged();
  }

  Future<void> _inspect(Json t) async {
    await showDialog<void>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(
              t['payee'] == '' ? 'Recorded entry' : t['payee'] as String,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t['effectiveDate']} · ${t['kind']} · ${money(t['amountMinor'])}',
                  ),
                  Text(t['notes'] as String),
                  const SizedBox(height: 12),
                  const Text('Signed account/category postings:'),
                  for (final p in LocalLedger.rows(t['postings']))
                    Text('${p['ledgerId']}: ${money(p['amountMinor'])}'),
                  if (t['scheduleId'] != null)
                    const Text(
                      'Linked to a scheduled occurrence. It will not be generated again.',
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Private server workspace · USD'),
          TextButton.icon(
            key: const Key('server-workspace-reload'),
            onPressed: _loading || _api.busy ? null : _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload saved workspace'),
          ),
        ],
      ),
      const Text(
        'Shared server records. Local workspaces stay separate. Plans do not move money until an occurrence is explicitly recorded.',
      ),
      const SizedBox(height: 12),
      if (_loading) const Center(child: CircularProgressIndicator()),
      if (_error != null) Text(_error!),
      if (!_loading && _error == null) ...[
        if (widget.page == 2)
          ServerActivityPanel(
            api: _api,
            onChanged: _changed,
            onInspect: _inspect,
          ),
        if (widget.page == 3)
          const Text(
            'Budget spending covers the entire selected month, including future-dated recorded expenses. Home remains through today.',
          ),
        if (widget.page == 3)
          BudgetPanel(
            api: _api,
            month: _month,
            onMonthChanged: (v) => setState(() => _month = v),
            onChanged: _changed,
            onOpenTransaction: _inspect,
          ),
        if (widget.page == 4)
          SchedulePanel(
            api: _api,
            onChanged: _changed,
            onOpenTransaction: _inspect,
          ),
        if (widget.page == 5 || widget.page == 6)
          PlanningPanel(
            key: ValueKey(widget.page),
            api: _api,
            calendar: widget.page == 5,
            onOpenTransaction: _inspect,
            onOpenScheduled: () => widget.onNavigate(4),
          ),
        if (widget.page == 7)
          ReportPanel(readSnapshot: () => _api.planningSnapshot),
      ],
    ],
  );
}

class ServerActivityPanel extends StatefulWidget {
  const ServerActivityPanel({
    super.key,
    required this.api,
    required this.onChanged,
    required this.onInspect,
  });
  final ServerPlanningApi api;
  final Future<void> Function() onChanged;
  final Future<void> Function(Json) onInspect;
  @override
  State<ServerActivityPanel> createState() => _ServerActivityPanelState();
}

class _ServerActivityPanelState extends State<ServerActivityPanel> {
  final _query = TextEditingController(),
      _from = TextEditingController(),
      _through = TextEditingController();
  String _account = '', _kind = '', _label = '';
  int _limit = 100;
  bool _busy = false;
  @override
  void dispose() {
    _query.dispose();
    _from.dispose();
    _through.dispose();
    super.dispose();
  }

  Future<String?> _name(String title, {String initial = ''}) =>
      showDialog<String>(
        context: context,
        builder: (_) => _ServerNameDialog(title: title, initial: initial),
      );

  Future<void> _categories() async {
    final snapshot = widget.api.planningSnapshot;
    final choice = await showDialog<Json>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Server categories'),
            content: SizedBox(
              width: 520,
              height: 360,
              child: ListView(
                children: [
                  const Text(
                    'Rename or archive categories without changing recorded money or historical postings.',
                  ),
                  for (final category in LocalLedger.rows(
                    snapshot['categories'],
                  ))
                    ListTile(
                      title: Text(category['name'] as String),
                      subtitle: Text(
                        '${category['kind']}${category['archived'] == true ? ' · archived' : ''}',
                      ),
                      onTap:
                          () => Navigator.pop(c, {...category, 'rename': true}),
                      trailing: IconButton(
                        tooltip:
                            category['archived'] == true
                                ? 'Restore category'
                                : 'Archive category',
                        onPressed:
                            () =>
                                Navigator.pop(c, {...category, 'toggle': true}),
                        icon: Icon(
                          category['archived'] == true
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, {'kind': 'Expense'}),
                child: const Text('Add expense category'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, {'kind': 'Income'}),
                child: const Text('Add income category'),
              ),
            ],
          ),
    );
    if (choice == null || !mounted) return;
    var name = choice['name'] as String?;
    if (choice['toggle'] == true) {
      final yes = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text(
                choice['archived'] == true
                    ? 'Restore category?'
                    : 'Archive category?',
              ),
              content: const Text(
                'History and past budgets remain. An archived category cannot be used for new recording or schedules until restored.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Apply'),
                ),
              ],
            ),
      );
      if (yes != true || !mounted) return;
    } else {
      name = await _name(
        choice['id'] == null ? 'New server category' : 'Rename server category',
        initial: name ?? '',
      );
    }
    if (name != null && mounted) {
      await _run('category', {
        'expectedRevision': snapshot['cursor'],
        if (choice['id'] != null) 'id': choice['id'],
        'name': name,
        'kind': choice['kind'],
        'archived':
            choice['toggle'] == true
                ? choice['archived'] != true
                : choice['archived'] == true,
      });
    }
  }

  Future<void> _run(String action, Json data) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.command(action, {
        'operationId': const Uuid().v4(),
        ...data,
      });
      if (mounted) await widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveView() async {
    final name = await _name('Save this server search?');
    if (name == null || !mounted) return;
    await _run('view', {
      'expectedVersion': 0,
      'name': name,
      'query': _query.text.trim(),
      'accountId': _account.isEmpty ? null : _account,
      'kind': _kind,
      'labelId': _label,
      'from': _from.text.trim(),
      'through': _through.text.trim(),
    });
  }

  Future<void> _addLabel() async {
    final name = await _name('Create server label');
    if (name == null || !mounted) return;
    await _run('label', {'expectedVersion': 0, 'name': name});
  }

  Future<void> _assign(Json t) async {
    final snapshot = widget.api.planningSnapshot;
    final labels = LocalLedger.rows(snapshot['labels']);
    final before =
        LocalLedger.rows(
          snapshot['annotations'],
        ).where((x) => x['transactionId'] == t['id']).firstOrNull;
    final selected = Set<String>.from(before?['labelIds'] as List? ?? []);
    final chosen = await showDialog<Set<String>>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, update) => AlertDialog(
                  title: const Text('Labels for this recorded entry'),
                  content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Labels are metadata. They do not change money, categories or postings.',
                          ),
                          for (final label in labels)
                            CheckboxListTile(
                              title: Text(label['name'] as String),
                              value: selected.contains(label['id']),
                              onChanged:
                                  (yes) => update(() {
                                    if (yes == true) {
                                      selected.add(label['id'] as String);
                                    } else {
                                      selected.remove(label['id']);
                                    }
                                  }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, selected),
                      child: const Text('Apply labels'),
                    ),
                  ],
                ),
          ),
    );
    if (chosen != null && mounted) {
      await _run('annotate', {
        'transactionId': t['id'],
        'expectedRevision': snapshot['cursor'],
        'labelIds': chosen.toList()..sort(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.api.planningSnapshot;
    final accounts = LocalLedger.rows(snapshot['accounts']);
    final names = {for (final a in accounts) a['id']: a['name']};
    final labels = LocalLedger.rows(snapshot['labels']);
    final annotations = {
      for (final a in LocalLedger.rows(snapshot['annotations']))
        a['transactionId']: Set<String>.from(a['labelIds'] as List),
    };
    var invalidDates = false;
    try {
      if (_from.text.trim().isNotEmpty) Recurrence.parse(_from.text.trim());
      if (_through.text.trim().isNotEmpty) {
        Recurrence.parse(_through.text.trim());
      }
      if (_from.text.trim().isNotEmpty &&
          _through.text.trim().isNotEmpty &&
          _from.text.trim().compareTo(_through.text.trim()) > 0) {
        invalidDates = true;
      }
    } catch (_) {
      invalidDates = true;
    }
    final entries =
        LocalLedger.rows(snapshot['transactions'])
            .where(
              (t) =>
                  !invalidDates &&
                  (_account == '' ||
                      t['accountId'] == _account ||
                      t['kind'] == 'transfer' &&
                          t['counterpartyAccountId'] == _account) &&
                  (_kind == '' || t['kind'] == _kind) &&
                  (_label == '' ||
                      (annotations[t['id']] ?? {}).contains(_label)) &&
                  (_from.text.trim() == '' ||
                      (t['effectiveDate'] as String).compareTo(
                            _from.text.trim(),
                          ) >=
                          0) &&
                  (_through.text.trim() == '' ||
                      (t['effectiveDate'] as String).compareTo(
                            _through.text.trim(),
                          ) <=
                          0) &&
                  _query.text
                      .toLowerCase()
                      .split(RegExp(r'\s+'))
                      .where((w) => w.isNotEmpty)
                      .every(
                        (w) =>
                            '${t['payee']} ${t['notes']} ${names[t['accountId']]}'
                                .toLowerCase()
                                .contains(w),
                      ),
            )
            .toList()
          ..sort((a, b) {
            final date = (b['effectiveDate'] as String).compareTo(
              a['effectiveDate'] as String,
            );
            return date != 0
                ? date
                : (a['id'] as String).compareTo(b['id'] as String);
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recorded server activity',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'Search is session-only until you explicitly save it to this server. Saved searches and labels use protected server storage.',
        ),
        TextField(
          key: const Key('server-activity-search'),
          controller: _query,
          decoration: const InputDecoration(
            labelText: 'Search payee, notes and account',
          ),
          onChanged: (_) => setState(() => _limit = 100),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                key: ValueKey('account:$_account'),
                initialValue: _account,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All accounts'),
                  ),
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a['id'] as String,
                      child: Text(a['name'] as String),
                    ),
                ],
                onChanged: (v) => setState(() => _account = v!),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                key: ValueKey('kind:$_kind'),
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final k in [
                    '',
                    'income',
                    'expense',
                    'transfer',
                    'opening',
                  ])
                    DropdownMenuItem(
                      value: k,
                      child: Text(k == '' ? 'All types' : k),
                    ),
                ],
                onChanged: (v) => setState(() => _kind = v!),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                key: ValueKey('label:$_label'),
                initialValue: _label,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Label'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All labels')),
                  for (final l in labels)
                    DropdownMenuItem(
                      value: l['id'] as String,
                      child: Text(l['name'] as String),
                    ),
                ],
                onChanged: (v) => setState(() => _label = v!),
              ),
            ),
            SizedBox(
              width: 180,
              child: FinanceDateField(
                controller: _from,
                label: 'From',
                allowEmpty: true,
                showToday: false,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 180,
              child: FinanceDateField(
                controller: _through,
                label: 'Through',
                allowEmpty: true,
                showToday: false,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          children: [
            TextButton(
              onPressed: _busy || invalidDates ? null : _saveView,
              child: const Text('Save this search'),
            ),
            TextButton(
              onPressed: _busy ? null : _addLabel,
              child: const Text('Create label'),
            ),
            TextButton(
              onPressed: _busy ? null : _categories,
              child: const Text('Manage server categories'),
            ),
            TextButton(
              onPressed:
                  () => setState(() {
                    _query.clear();
                    _from.clear();
                    _through.clear();
                    _account = _kind = _label = '';
                    _limit = 100;
                  }),
              child: const Text('Reset filters'),
            ),
          ],
        ),
        if (LocalLedger.rows(snapshot['savedViews']).isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (final view in LocalLedger.rows(snapshot['savedViews']))
                InputChip(
                  label: Text(view['name'] as String),
                  onPressed:
                      () => setState(() {
                        _query.text = view['query'] as String;
                        _account = view['accountId'] as String? ?? '';
                        _kind = view['kind'] as String? ?? '';
                        _label = view['labelId'] as String? ?? '';
                        _from.text = view['from'] as String? ?? '';
                        _through.text = view['through'] as String? ?? '';
                        _limit = 100;
                      }),
                  onDeleted:
                      _busy
                          ? null
                          : () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder:
                                  (c) => AlertDialog(
                                    title: const Text('Remove saved search?'),
                                    content: const Text(
                                      'Recorded entries and labels remain unchanged.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                            );
                            if (yes == true) {
                              await _run('view-remove', {
                                'id': view['id'],
                                'expectedVersion': view['version'],
                              });
                            }
                          },
                ),
            ],
          ),
        Text(
          invalidDates
              ? 'Choose valid ordered calendar dates. No partial search is shown.'
              : '${entries.length} matches · ${entries.length < _limit ? entries.length : _limit} shown · ${LocalLedger.rows(snapshot['transactions']).length} saved entries. Amounts are signed movement on the primary account. Open Reports for exact totals and trends.',
        ),
        for (final t in entries.take(_limit))
          Card(
            child: ListTile(
              title: Text(
                t['payee'] == '' ? t['kind'] as String : t['payee'] as String,
              ),
              subtitle: Text(
                '${t['effectiveDate']} · ${names[t['accountId']]} · ${t['kind']}\n${labels.where((l) => (annotations[t['id']] ?? {}).contains(l['id'])).map((l) => l['name']).join(', ')}',
              ),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    money(
                      LocalLedger.rows(t['postings'])
                          .where((p) => p['ledgerId'] == t['accountId'])
                          .fold<int>(
                            0,
                            (sum, p) => sum + (p['amountMinor'] as int),
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit labels',
                    onPressed: _busy ? null : () => _assign(t),
                    icon: const Icon(Icons.label_outline),
                  ),
                ],
              ),
              onTap: () => widget.onInspect(t),
            ),
          ),
        if (entries.length > _limit)
          TextButton(
            onPressed: () => setState(() => _limit += 100),
            child: const Text('Show more recorded entries'),
          ),
        const SizedBox(height: 88),
      ],
    );
  }
}

class _ServerNameDialog extends StatefulWidget {
  const _ServerNameDialog({required this.title, this.initial = ''});
  final String title;
  final String initial;
  @override
  State<_ServerNameDialog> createState() => _ServerNameDialogState();
}

class _ServerNameDialogState extends State<_ServerNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_controller.text.trim().isNotEmpty) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
