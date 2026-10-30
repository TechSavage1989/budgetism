import 'package:flutter/material.dart';
import 'finance_api.dart';
import 'money.dart';
import 'server_dashboard.dart';

class ServerDashboardPanel extends StatefulWidget {
  const ServerDashboardPanel({
    super.key,
    required this.api,
    required this.revision,
    required this.onNavigate,
    this.now,
  });
  final FinanceApi api;
  final Object? revision;
  final ValueChanged<int> onNavigate;
  final DateTime? now;
  @override
  State<ServerDashboardPanel> createState() => _ServerDashboardPanelState();
}

class _ServerDashboardPanelState extends State<ServerDashboardPanel> {
  ServerDashboard? _view;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  DateTime? _loadedAt;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ServerDashboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.revision != widget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final api = widget.api, session = widget.api.token;
    setState(() {
      _loading = true;
      _view = null;
      _error = null;
    });
    try {
      final through = (widget.now ?? DateTime.now())
          .toIso8601String()
          .substring(0, 10);
      final view = await api.dashboard(through);
      if (!mounted ||
          generation != _generation ||
          api != widget.api ||
          session != api.token) {
        return;
      }
      setState(() {
        _view = view;
        _loadedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(
        () =>
            _error =
                'Dashboard unavailable. Retry or use Accounts, Transactions and Needs Review. Saved records are unchanged.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _metric(BuildContext context, String label, int amount) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Text(money(amount), style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final d = _view?.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server overview',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Recorded money and saved fictional bank activity. Refresh reads saved data; it does not contact Plaid.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('dashboard-refresh'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh overview'),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(1),
              child: const Text('Accounts'),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(2),
              child: const Text('Transactions'),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(10),
              child: const Text('Needs Review'),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(9),
              child: const Text('Connections'),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!),
            ),
          ),
        if (d != null) ...[
          Text(
            'Recorded through ${d['through']} · USD. Archived accounts are included. These are not market valuations.',
          ),
          LayoutBuilder(
            builder: (context, c) {
              final width =
                  c.maxWidth >= 720 ? (c.maxWidth - 20) / 3 : c.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _metric(
                      context,
                      'Assets and cash',
                      d['assetsMinor'] as int,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _metric(
                      context,
                      'Net recorded balance',
                      d['netBalanceMinor'] as int,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _metric(
                      context,
                      'Spent month to date',
                      d['expenseMinor'] as int,
                    ),
                  ),
                ],
              );
            },
          ),
          Text(
            'Month to date: income ${money(d['incomeMinor'])} · net income ${money(d['netIncomeMinor'])}. '
            'Transfers, card payments and opening balances are excluded. Refunds reduce spending.',
          ),
          if ((d['futureCount'] as int) > 0)
            Text(
              '${d['futureCount']} future-dated recorded entries are excluded. Accounts and Transactions include all dates.',
            ),
          const SizedBox(height: 16),
          Text(
            'Recorded accounts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if ((d['accounts'] as List).isEmpty)
            const Text(
              'No recorded accounts yet. Add a manual account or map a dedicated fictional account in Connections.',
            ),
          for (final a in d['accounts'] as List)
            Card(
              child: ListTile(
                title: Text(
                  '${a['name']}${a['archived'] == true ? ' (archived)' : ''}',
                ),
                subtitle: Text(
                  '${a['type']} · recorded through ${d['through']}',
                ),
                trailing: Text(money(a['balanceMinor'])),
              ),
            ),
          const SizedBox(height: 16),
          _bank(context, Map<String, dynamic>.from(d['bank'] as Map)),
          const SizedBox(height: 16),
          Text(
            'Spending by category · month to date',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if ((d['spendingCategories'] as List).isEmpty)
            const Text(
              'No recorded expenses this month. Saved bank sources enter spending only after explicit recording.',
            ),
          if ((d['spendingCategoryCount'] as int) > 6)
            Text(
              'Top 6 of ${d['spendingCategoryCount']} categories by net spending. Summary totals include every category.',
            ),
          for (final c in d['spendingCategories'] as List)
            Card(
              child: ListTile(
                title: Text(c['name'] as String),
                subtitle: Text('${c['entryCount']} recorded entries'),
                trailing: Text(money(c['amountMinor'])),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Recent recorded activity',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Latest ${(d['recent'] as List).length} of ${d['recordedCount']} entries through ${d['through']}.',
          ),
          if ((d['recent'] as List).isEmpty)
            const Text(
              'No recorded activity through this day. Unreviewed and pending bank activity is separate below Connections.',
            ),
          for (final e in d['recent'] as List)
            Card(
              child: ListTile(
                title: Text(
                  (e['payee'] as String).isEmpty
                      ? e['kind'] as String
                      : e['payee'] as String,
                ),
                subtitle: Text(
                  '${e['date']} · ${e['accountName']} · ${e['kind']}${e['kind'] == 'transfer' ? ' → ${e['counterpartyName']}' : ''}',
                ),
                trailing: Text(
                  '${e['kind'] == 'transfer' || e['kind'] == 'opening'
                      ? ''
                      : (e['kind'] == 'expense' ? -(e['amountMinor'] as int) : e['amountMinor'] as int) >= 0
                      ? '+'
                      : '-'}'
                  '${money(e['kind'] == 'transfer' || e['kind'] == 'opening' ? e['amountMinor'] : (e['amountMinor'] as int).abs())}',
                ),
              ),
            ),
          if (_loadedAt != null)
            Text(
              'Overview loaded: ${_loadedAt!.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 88),
        ],
      ],
    );
  }

  Widget _bank(BuildContext context, Map<String, dynamic> bank) {
    final ready = bank['status'] == 'ready';
    final connection = bank['connection'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved fictional bank activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (!ready)
          Text(
            bank['status'] == 'disabled'
                ? 'Sandbox review is disabled. Review count is unavailable.'
                : 'Sandbox storage needs a verified upgrade. Review count is unavailable.',
          ),
        if (ready && connection == null)
          const Text(
            'No fictional connection. Open Connections to discover the configured Sandbox fixture.',
          ),
        if (ready && connection != null) ...[
          Card(
            child: ListTile(
              key: const Key('dashboard-review'),
              leading: const Icon(Icons.inbox_outlined),
              title: Text('Needs Review (${bank['needsReviewCount']})'),
              subtitle: Text(
                '${bank['totalSources']} saved sources · ${connection['active'] == true ? 'connected' : 'disconnected; history retained'}',
              ),
              onTap: () => widget.onNavigate(10),
            ),
          ),
          Text(
            'Last source refresh: ${connection['lastSuccessUtc'] ?? 'never'}. Overview refresh does not fetch new bank data.',
          ),
          if (connection['lastErrorCode'] != null)
            const Text(
              'The last source refresh had an issue. Open Connections or Needs Review for explicit retry.',
            ),
        ],
        for (final a in bank['accounts'] as List)
          Card(
            child: ListTile(
              title: Text(a['name'] as String),
              subtitle: Text(
                '${a['ledgerAccountId'] == null ? 'not mapped' : 'mapped'} · ${a['currency']} · observed ${a['observedUtc']}\n'
                'Cached provider reference; excluded from recorded totals.${a['balanceIssue'] == true || a['available'] != true ? ' Balance unavailable or needs attention.' : ''}',
              ),
              trailing: Text(
                a['currency'] == 'USD' &&
                        a['available'] == true &&
                        a['balanceIssue'] != true &&
                        a['reportedBalanceMinor'] != null
                    ? money(a['reportedBalanceMinor'])
                    : 'Unavailable',
              ),
            ),
          ),
      ],
    );
  }
}
