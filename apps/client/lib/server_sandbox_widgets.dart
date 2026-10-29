import 'package:flutter/material.dart';
import 'finance_api.dart';
import 'money.dart';
import 'server_sandbox.dart';

class ServerSandboxPanel extends StatefulWidget {
  const ServerSandboxPanel({required this.api, super.key});
  final FinanceApi api;
  @override
  State<ServerSandboxPanel> createState() => _ServerSandboxPanelState();
}

class _ServerSandboxPanelState extends State<ServerSandboxPanel> {
  SandboxPreview? _preview;
  String? _error;
  DateTime? _received;
  bool _busy = false;
  int _generation = 0;
  int _limit = 50;

  @override
  void didUpdateWidget(covariant ServerSandboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api)) {
      _generation++;
      _preview = null;
      _error = null;
      _received = null;
      _busy = false;
      _limit = 50;
    }
  }

  Future<void> _load() async {
    if (_busy) return;
    final generation = ++_generation;
    final session = widget.api.token;
    setState(() {
      _busy = true;
      _preview = null;
      _error = null;
      _received = null;
      _limit = 50;
    });
    try {
      final preview = await widget.api.sandboxPreview();
      if (!mounted || generation != _generation || session != widget.api.token) {
        return;
      }
      setState(() {
        _preview = preview;
        _received = DateTime.now();
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(
        () =>
            _error =
                'Preview unavailable. Check your server session, Sandbox setup, HTTPS trust and connection, then try again.',
      );
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final groups = <String, List<SandboxActivity>>{};
    for (final row in (preview?.activity ?? <SandboxActivity>[]).take(_limit)) {
      groups.putIfAbsent(row.accountId, () => []).add(row);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sandbox bank preview',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        const Text(
          'Fictional Plaid data from your private server. Preview only: nothing is imported or recorded.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Your saved local workspace remains separate. Provider credentials stay on the server. Retrieval runs only when you choose it.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('sandbox-load'),
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.science_outlined),
          label: Text(
            _busy ? 'Retrieving preview…' : 'Retrieve fictional activity',
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              key: const ValueKey('sandbox-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (preview != null && !preview.ready)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Sandbox data is not ready yet. Try again shortly. No transactions have been recorded.',
            ),
          ),
        if (preview != null && preview.ready) ...[
          const SizedBox(height: 16),
          Text(
            '${preview.activity.length} fictional changes · USD · Received ${TimeOfDay.fromDateTime(_received!).format(context)}',
          ),
          const Text(
            'Amounts show money in or out of each account, not balances or spending totals. Pending activity has not posted.',
          ),
          if (preview.activity.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No fictional changes were returned.'),
            ),
          for (final (index, group) in groups.values.indexed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fictional account ${index + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final row in group)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.description ?? 'Removed source record',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              row.kind == 'removed'
                                  ? 'Removed at provider · nothing recorded'
                                  : '${row.date} · ${row.pending! ? 'Pending' : 'Posted'} · ${row.kind == 'modified' ? 'Modified' : 'Added'}',
                            ),
                            if (row.amountMinor != null)
                              Text(money(row.amountMinor)),
                            if (row.pendingSourceId != null)
                              const Text(
                                'Linked to an earlier pending authorization.',
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (preview.activity.length > _limit)
            TextButton(
              onPressed: () => setState(() => _limit += 50),
              child: const Text('Show 50 more changes'),
            ),
        ],
      ],
    );
  }
}
