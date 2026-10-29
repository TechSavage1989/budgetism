import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'ledger.dart';

class ImportProfileEditor extends StatefulWidget {
  const ImportProfileEditor({super.key, required this.data, required this.settings,
    required this.onSave, this.existing});
  final Json data, settings;
  final Json? existing;
  final Future<void> Function(Json) onSave;
  @override
  State<ImportProfileEditor> createState() => _ImportProfileEditorState();
}

class _ImportProfileEditorState extends State<ImportProfileEditor> {
  late final _name = TextEditingController(text: widget.existing?['name'] as String? ?? '');
  bool _busy = false, _upgrade = false;
  String? _error;
  String _operation = const Uuid().v4();
  @override
  void dispose() { _name.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onSave({'operationId': _operation, 'expectedRevision': widget.data['cursor'],
        if (widget.existing != null) ...{'id': widget.existing!['id'], 'expectedVersion': widget.existing!['version']},
        'name': _name.text.trim(), 'settings': widget.settings, 'confirmProfileUpgrade': _upgrade});
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final columns = Map<String, dynamic>.from(s['columns'] as Map);
    return PopScope(canPop: !_busy, child: AlertDialog(
      title: Text(widget.existing == null ? 'Save import profile' : 'Update import profile'),
      content: SizedBox(width: 530, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Stores mapping settings and default categories inside your encrypted workspace. '
            'No statement rows, file paths or duplicate decisions are saved. The destination account is not part of the profile.'),
          const SizedBox(height: 12),
          TextField(key: const Key('profile-name'), controller: _name, enabled: !_busy, maxLength: 80,
            decoration: const InputDecoration(labelText: 'Profile name', border: OutlineInputBorder()),
            onChanged: (_) => setState(() { _error = null; _operation = const Uuid().v4(); })),
          const SizedBox(height: 12),
          Text('Date format: ${s['dateFormat']} | Amounts: ${s['amountMode']}'),
          if (s['reverseSign'] == true) const Text('Amount signs will be reversed. Review the preview before importing.'),
          for (final field in ImportProfiles.columnFields)
            if (columns[field] != null) Text('$field: ${columns[field]}'),
          if ((widget.data['schema'] as int) < LocalLedger.importProfileSchema) ...[
            const SizedBox(height: 12),
            CheckboxListTile(key: const Key('profile-upgrade'), contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading, value: _upgrade,
              onChanged: _busy ? null : (v) => setState(() { _upgrade = v == true; _operation = const Uuid().v4(); }),
              title: const Text('I exported a backup and approve the import-profile format upgrade. '
                'Dev.13 and older cannot open this workspace afterward.')),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!,
            key: const Key('profile-save-error'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ))),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(key: const Key('profile-save'), onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving...' : widget.existing == null ? 'Save profile' : 'Update profile'))],
    ));
  }
}

class ImportProfilesManager extends StatefulWidget {
  const ImportProfilesManager({super.key, required this.snapshot, required this.onSave,
    required this.onState, required this.onRefresh});
  final Json Function() snapshot;
  final Future<void> Function(Json) onSave, onState;
  final Future<void> Function() onRefresh;
  @override
  State<ImportProfilesManager> createState() => _ImportProfilesManagerState();
}

class _ImportProfilesManagerState extends State<ImportProfilesManager> {
  late Json _data = widget.snapshot();
  bool _busy = false;
  String? _error;
  Json? _pendingState;
  Future<void> _refresh() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onRefresh();
      if (mounted) setState(() { _data = widget.snapshot(); _pendingState = null; });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _rename(Json profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => ImportProfileEditor(
        data: _data, settings: profile['settings'] as Json, existing: profile, onSave: widget.onSave));
      if (mounted) setState(() => _data = widget.snapshot());
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _state(Json profile) async {
    if (_busy) return;
    final archive = profile['archived'] == false;
    final label = archive ? 'Archive' : 'Restore';
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('$label ${profile['name']}?'),
      content: Text(archive ? 'Hides this profile from import selection. Its saved settings and all financial records remain. You can restore it later.'
        : 'Makes this saved profile available again. No transaction or import receipt will change.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(label))]));
    if (confirmed != true || !mounted) return;
    final prior = _pendingState;
    final operation = prior != null && prior['id'] == profile['id'] && prior['archived'] == archive &&
        prior['expectedVersion'] == profile['version'] && prior['expectedRevision'] == _data['cursor']
        ? prior['operationId'] : const Uuid().v4();
    final request = <String, dynamic>{'operationId': operation, 'id': profile['id'],
      'expectedVersion': profile['version'], 'expectedRevision': _data['cursor'],
      'archived': archive, 'confirmReviewed': true};
    _pendingState = request;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onState(request);
      if (mounted) setState(() { _data = widget.snapshot(); _pendingState = null; });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final profiles = ImportProfiles.list(_data, includeArchived: true);
    return PopScope(canPop: !_busy, child: Dialog.fullscreen(child: Scaffold(
      appBar: AppBar(title: const Text('Manage import profiles'), automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Refresh profiles', onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Close profiles', onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Rename, archive or restore saved profiles. To update column mappings, load a file, adjust its mapping and choose Update selected profile.'),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (profiles.isEmpty) const Padding(padding: EdgeInsets.only(top: 16), child: Text('No saved profiles yet.')),
        for (final p in profiles) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name'] as String, style: Theme.of(context).textTheme.titleMedium),
            Text(p['archived'] == true ? 'Archived' : 'Active'),
            Wrap(spacing: 12, children: [
              if (p['archived'] == false) TextButton(onPressed: _busy ? null : () => _rename(p), child: const Text('Rename')),
              TextButton(onPressed: _busy ? null : () => _state(p), child: Text(p['archived'] == true ? 'Restore' : 'Archive')),
            ]),
          ],
        ))),
      ]),
    )));
  }
}
