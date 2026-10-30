import 'package:flutter/material.dart';
import 'money.dart';

class BatchDecisionDialog extends StatefulWidget {
  const BatchDecisionDialog({
    required this.action,
    required this.sources,
    this.snapshot,
    super.key,
  });
  final String action;
  final List<Map<String, dynamic>> sources;
  final Map<String, dynamic>? snapshot;
  @override
  State<BatchDecisionDialog> createState() => _BatchDecisionDialogState();
}

class _BatchDecisionDialogState extends State<BatchDecisionDialog> {
  final _reason = TextEditingController();
  bool _confirmed = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keep = widget.action == 'keep';
    final entries = {
      for (final t
          in (widget.snapshot?['transactions'] as List? ?? []).cast<Map>())
        t['id']: t,
    };
    final missing =
        keep &&
        widget.sources.any(
          (s) => !entries.containsKey(s['linkedJournalEntryId']),
        );
    return AlertDialog(
      title: Text(
        '${keep
            ? 'Keep recorded entries unchanged'
            : widget.action == 'reopen'
            ? 'Reopen source decisions'
            : 'Ignore sources'} (${widget.sources.length})',
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'These source decisions leave recorded balances unchanged. All selected decisions apply together, or none do.',
              ),
              const SizedBox(height: 10),
              for (final s in widget.sources)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['description']} · ${s['date'] ?? 'undated'}'),
                        Text(
                          'Source amount: ${s['amountMinor'] == null ? 'unavailable' : money(s['amountMinor'])} · ${s['status']}',
                        ),
                        if (entries[s['linkedJournalEntryId']]
                            case final Map entry when keep)
                          Text(
                            'Recorded entry: ${entry['payee']} · ${entry['effectiveDate']} · ${money(entry['amountMinor'])}',
                          ),
                      ],
                    ),
                  ),
                ),
              if (missing)
                const Text(
                  'A recorded entry could not be loaded. Reload the saved state before keeping these entries.',
                ),
              TextField(
                controller: _reason,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for all selected decisions',
                ),
                onChanged: (_) => setState(() => _confirmed = false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: const Text(
                  'I reviewed this selection and want to apply this reason to every selected source.',
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
          key: const Key('batch-apply'),
          onPressed:
              !_confirmed || _reason.text.trim().isEmpty || missing
                  ? null
                  : () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Apply selected decisions'),
        ),
      ],
    );
  }
}
