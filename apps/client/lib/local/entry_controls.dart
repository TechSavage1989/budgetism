import 'package:flutter/material.dart';
import 'ledger.dart';

/// Search is kept in the dialog only. Selecting an ID never writes a record.
class SearchableFinanceChoice extends StatefulWidget {
  const SearchableFinanceChoice({super.key, required this.label, required this.options,
    required this.value, required this.onChanged, this.enabled = true});
  final String label;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  State<SearchableFinanceChoice> createState() => _SearchableFinanceChoiceState();
}

class _SearchableFinanceChoiceState extends State<SearchableFinanceChoice> {
  bool _opening = false;
  Future<void> _choose() async {
    if (_opening || !widget.enabled || widget.options.isEmpty) return;
    final prior = widget.value;
    setState(() => _opening = true);
    try {
      final result = await showDialog<String>(context: context, builder: (_) => _ChoiceDialog(
        label: widget.label, options: Map.of(widget.options), selected: prior));
      if (mounted && widget.enabled && widget.value == prior && result != null &&
          widget.options.containsKey(result) && result != prior) {
        widget.onChanged(result);
      }
    } finally { if (mounted) setState(() => _opening = false); }
  }
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: !widget.enabled || _opening || widget.options.isEmpty ? null : _choose,
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
    child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(widget.options[widget.value] ?? (widget.value == null ? 'Choose an option' : 'Unavailable selection'),
          style: Theme.of(context).textTheme.bodyLarge),
      ])), const SizedBox(width: 8), const Icon(Icons.search, size: 20)]));
}

class _ChoiceDialog extends StatefulWidget {
  const _ChoiceDialog({required this.label, required this.options, required this.selected});
  final String label;
  final Map<String, String> options;
  final String? selected;
  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  final _search = TextEditingController();
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final entries = widget.options.entries.where((e) => e.value.toLowerCase().contains(query)).toList()
      ..sort((a, b) {
        final order = a.value.toLowerCase().compareTo(b.value.toLowerCase());
        return order != 0 ? order : a.key.compareTo(b.key);
      });
    return AlertDialog(title: Text('Choose ${widget.label.toLowerCase()}'),
      content: SizedBox(width: 520, height: 350, child: Column(children: [
        TextField(key: const Key('choice-query'), controller: _search, autofocus: true,
          autocorrect: false, enableSuggestions: false,
          decoration: InputDecoration(labelText: 'Search ${widget.label.toLowerCase()}',
            prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        if (entries.isEmpty) const Expanded(child: Center(child: Text('No matches. Change the search.')))
        else Expanded(child: ListView.builder(itemCount: entries.length, itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(key: ValueKey('choice-${entry.key}'), selected: entry.key == widget.selected,
            title: Text(entry.value), trailing: entry.key == widget.selected ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, entry.key));
        })),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))]);
  }
}

/// Local history only. Completing text does not copy an amount or category.
class PayeeSuggestions {
  static List<String> find(List<Json> history, String query, String kind) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty || !['expense', 'income'].contains(kind)) return const [];
    final entries = history.where((t) => t['voided'] != true && t['kind'] == kind &&
      (t['payee'] as String? ?? '').trim().isNotEmpty).toList()
      ..sort((a, b) {
        final date = (b['effectiveDate'] as String).compareTo(a['effectiveDate'] as String);
        return date != 0 ? date : (a['id'] as String).compareTo(b['id'] as String);
      });
    final seen = <String>{}, starts = <String>[], contains = <String>[];
    for (final t in entries) {
      final name = (t['payee'] as String).trim(), lower = (t['payee'] as String).trim().toLowerCase();
      if (!lower.contains(text) || !seen.add(lower)) continue;
      (lower.startsWith(text) ? starts : contains).add(name);
    }
    return [...starts, ...contains].take(8).toList();
  }
}

class PayeeField extends StatelessWidget {
  const PayeeField({super.key, required this.controller, required this.focusNode,
    required this.history, required this.kind, this.enabled = true});
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Json> history;
  final String kind;
  final bool enabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) => RawAutocomplete<String>(
    textEditingController: controller, focusNode: focusNode,
    optionsBuilder: (value) => enabled ? PayeeSuggestions.find(history, value.text, kind) : const <String>[],
    fieldViewBuilder: (context, text, focus, onSubmitted) => TextField(
      key: const Key('entry-payee'), controller: text, focusNode: focus, enabled: enabled,
      maxLength: 150, enableSuggestions: false, autocorrect: false,
      decoration: InputDecoration(labelText: kind == 'transfer' ? 'Description' : 'Payee',
        helperText: kind == 'transfer' ? null : 'Suggestions use only payees already in this workspace.',
        helperMaxLines: 2, border: const OutlineInputBorder()),
      onSubmitted: (_) => onSubmitted()),
    optionsViewBuilder: (context, onSelected, options) {
      final list = options.toList();
      return Align(alignment: Alignment.topLeft, child: Material(elevation: 4,
        child: SizedBox(width: constraints.maxWidth, child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 192), child: ListView.builder(
            padding: EdgeInsets.zero, shrinkWrap: true, itemCount: list.length,
            itemBuilder: (context, index) => ListTile(key: ValueKey('payee-option-$index'),
              selected: AutocompleteHighlightedOption.of(context) == index,
              title: Text(list[index], maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onSelected(list[index])),
          )))));
    },
  ));
}
