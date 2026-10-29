import 'package:flutter/material.dart';
import '../money.dart';
import 'csv_rule_suggestions.dart';

class CsvRuleSuggestionsDialog extends StatefulWidget {
  const CsvRuleSuggestionsDialog({super.key, required this.review, required this.onAccept});
  final CsvRuleReview review;
  final Future<void> Function(List<int>) onAccept;
  @override
  State<CsvRuleSuggestionsDialog> createState() => _CsvRuleSuggestionsDialogState();
}

class _CsvRuleSuggestionsDialogState extends State<CsvRuleSuggestionsDialog> {
  final _selected = <int>{};
  bool _busy = false, _confirmed = false;
  int _visible = 100;
  String? _error;

  void _select(int row, bool selected) {
    setState(() {
      _confirmed = false; _error = null;
      if (selected && _selected.length >= CsvRuleSuggestions.maxSelection) {
        _error = 'Use at most 500 suggestions at a time.';
      } else if (selected) { _selected.add(row); } else { _selected.remove(row); }
    });
  }
  Future<void> _accept() async {
    if (_busy || !_confirmed || _selected.isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      final rows = _selected.toList()..sort();
      await widget.onAccept(rows);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final suggestions = widget.review.suggestions;
    return PopScope(canPop: !_busy, child: Dialog.fullscreen(child: Scaffold(
      appBar: AppBar(title: const Text('Category suggestions'), automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Close suggestions', onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close))]),
      body: ListView(key: const Key('csv-rules-scroll'), padding: const EdgeInsets.all(20), children: [
        Text('${suggestions.length} suggestions | ${_selected.length} selected', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Choose categories for this import preview. Nothing is saved until you confirm the CSV import.'),
        const SizedBox(height: 8),
        const Text('Manual choices, previously accepted suggestions, matches, transfers, and skipped or handled rows are excluded.'),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!,
          key: const Key('csv-rules-error'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (suggestions.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No category changes are suggested by the enabled rules.')),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 10, children: [
            TextButton(onPressed: _busy ? null : () => setState(() {
              _confirmed = false; _error = null;
              for (final p in suggestions.take(_visible)) {
                if (_selected.length < CsvRuleSuggestions.maxSelection) _selected.add(p.rowNumber);
              }
            }), child: const Text('Select displayed')),
            TextButton(onPressed: _busy ? null : () => setState(() {
              _selected.clear(); _confirmed = false; _error = null;
            }), child: const Text('Clear selection')),
          ]),
          for (final p in suggestions.take(_visible)) Card(child: CheckboxListTile(
            key: ValueKey('csv-rule-row-${p.rowNumber}'), value: _selected.contains(p.rowNumber),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _busy ? null : (v) => _select(p.rowNumber, v == true),
            title: Text('Row ${p.rowNumber}: ${p.payee}'),
            subtitle: Text('${p.date} | ${money(p.signedMinor)}\n'
              '${p.currentCategory} to ${p.categoryName}\nRule: ${p.ruleName} (priority ${p.priority})'),
          )),
          if (suggestions.length > _visible) TextButton(
            onPressed: _busy ? null : () => setState(() => _visible += 100), child: const Text('Show 100 more')),
          CheckboxListTile(key: const Key('csv-rules-reviewed'), value: _confirmed,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _busy ? null : (v) => setState(() => _confirmed = v == true),
            title: const Text('I reviewed the selected category suggestions.')),
          Align(alignment: Alignment.centerLeft, child: FilledButton(key: const Key('csv-rules-accept'),
            onPressed: _busy || !_confirmed || _selected.isEmpty ? null : _accept,
            child: Text(_busy ? 'Checking...' : 'Use ${_selected.length} selected suggestions'))),
        ],
      ]),
    )));
  }
}
