import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'ledger.dart';
import 'local_api.dart';
import 'storage.dart';
import 'vault.dart';
import 'device_keys.dart';
import 'security_dialogs.dart';
import 'category_rule_widgets.dart';

Future<LocalFinanceApi?> openLocalWorkspace(BuildContext context) async {
  final storage = await openVaultStorage();
  try {
    final saved = await storage.read();
    final creating = saved == null;
    if (saved != null && !LocalVault.requiresPassword(LocalVault.header(saved))) {
      final vault = await LocalVault.open(storage, '', create: false, deviceKeys: const SecureDeviceKeys());
      if (!context.mounted) { await vault.close(); return null; }
      return LocalFinanceApi(vault);
    }
    if (!context.mounted) { await storage.close(); return null; }
    final api = await showDialog<LocalFinanceApi>(context: context, barrierDismissible: false,
      builder: (_) => LocalWorkspaceAccessDialog(storage: storage, creating: creating));
    if (api == null) await storage.close();
    return api;
  } catch (_) { await storage.close(); rethrow; }
}

class LocalWorkspaceAccessDialog extends StatefulWidget {
  const LocalWorkspaceAccessDialog({required this.storage, required this.creating, this.deviceKeys = const SecureDeviceKeys(), super.key});
  final VaultStorage storage;
  final bool creating;
  final DeviceKeyStore deviceKeys;
  @override
  State<LocalWorkspaceAccessDialog> createState() => LocalWorkspaceAccessDialogState();
}
class LocalWorkspaceAccessDialogState extends State<LocalWorkspaceAccessDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  late bool _requirePassword = !widget.creating;
  String? _error;
  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }
  Future<void> _open() async {
    if (_busy) return;
    if (widget.creating && _requirePassword && _password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final vault = await LocalVault.open(widget.storage, _password.text, create: widget.creating,
        requirePassword: _requirePassword, deviceKeys: widget.deviceKeys);
      if (!mounted) { await vault.close(); return; }
      Navigator.pop(context, LocalFinanceApi(vault));
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = error.toString(); });
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: Text(widget.creating ? 'Create local workspace' : 'Unlock local workspace'),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Records stay on this device. They are not synchronized with a server or other devices in this build.'),
      const SizedBox(height: 14),
      if (widget.creating) ...[
        SwitchListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Require a password to open this workspace'),
          value: _requirePassword, onChanged: _busy ? null : (value) => setState(() => _requirePassword = value)),
        if (!_requirePassword) const Text('No Budgetism password is needed. Records remain encrypted using an OS-protected device key. Anyone using this OS account can open the workspace. Export a backup for recovery if this OS profile is lost.'),
        const SizedBox(height: 12),
      ],
      if (_requirePassword) TextField(controller: _password, obscureText: true, enableSuggestions: false, autocorrect: false,
        autofocus: true, enabled: !_busy, onSubmitted: (_) { if (!widget.creating) _open(); },
        decoration: InputDecoration(labelText: 'Workspace password', border: const OutlineInputBorder(),
          helperText: widget.creating ? 'At least 14 characters. Use a memorable, unique password.' : null)),
      if (widget.creating && _requirePassword) ...[
        const SizedBox(height: 12),
        TextField(controller: _confirm, obscureText: true, enableSuggestions: false, autocorrect: false,
          enabled: !_busy, onSubmitted: (_) => _open(),
          decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('There is no password recovery. Exported backups use the separate password chosen at export. This preview is not ready for your only copy of real financial records.'),
      ],
      if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]))),
    actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _open, child: Text(widget.creating ? 'Create workspace' : 'Unlock'))],
  ));
}

Future<void> showLocalBackups(BuildContext context, LocalFinanceApi api) =>
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _BackupDialog(api));

class _BackupDialog extends StatefulWidget {
  const _BackupDialog(this.api);
  final LocalFinanceApi api;
  @override
  State<_BackupDialog> createState() => _BackupDialogState();
}
class _BackupDialogState extends State<_BackupDialog> {
  bool _busy = false;
  String? _status;
  static const _types = [XTypeGroup(label: 'Budgetism encrypted backup', extensions: ['budgetism'],
    uniformTypeIdentifiers: ['public.data'])];
  Future<void> _export() async {
    setState(() { _busy = true; _status = null; });
    try {
      final password = await requestBackupPassword(context);
      if (password == null || !mounted) return;
      final where = await getSaveLocation(suggestedName: 'Budgetism-${DateTime.now().toIso8601String().substring(0, 10)}.budgetism', acceptedTypeGroups: _types);
      if (where == null) return;
      final data = await widget.api.vault.exportBackup(password: password);
      await XFile.fromData(Uint8List.fromList(utf8.encode(data)), mimeType: 'application/octet-stream').saveTo(where.path);
      if (mounted) setState(() => _status = 'Encrypted backup saved. Keep the backup password separately.');
    } catch (error) { if (mounted) setState(() => _status = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _restore() async {
    setState(() { _busy = true; _status = null; });
    try {
      final selected = await openFile(acceptedTypeGroups: _types);
      if (selected == null) return;
      if (await selected.length() > maxVaultBytes) throw const FormatException('Backup is too large.');
      final encoded = await selected.readAsString();
      LocalVault.header(encoded);
      if (!mounted) return;
      final password = await showDialog<String>(context: context, builder: (_) => const _RestoreConfirmation());
      if (password == null) return;
      await widget.api.vault.restoreBackup(encoded, password);
      if (mounted) setState(() => _status = 'Backup restored. Your current workspace security setting is unchanged.');
    } catch (error) { if (mounted) setState(() => _status = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final desktop = [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(defaultTargetPlatform);
    return PopScope(canPop: !_busy, child: AlertDialog(title: const Text('Backups and storage'),
      content: SizedBox(width: 510, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Financial payloads are encrypted in a local SQLite file. Password mode derives the key when you open the workspace; password-free mode uses an OS-protected random key. Database headers and revision numbers are not encrypted.'),
        const SizedBox(height: 12), SelectableText(widget.api.vault.location),
        const SizedBox(height: 14),
        const Text('Export a backup before testing changes. Restore replaces the entire local workspace, not just selected transactions. New backups use the separate password you choose during export. Older backups still require their original workspace password.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _busy || !desktop ? null : _export,
            icon: const Icon(Icons.save_alt), label: const Text('Export encrypted backup')),
          OutlinedButton.icon(onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore), label: const Text('Restore backup')),
        ]),
        if (!desktop) const Text('Backup export is currently available in the desktop app.'),
        if (_busy) const LinearProgressIndicator(),
        if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!)),
      ]))), actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Close'))]));
  }
}
class _RestoreConfirmation extends StatefulWidget {
  const _RestoreConfirmation();
  @override
  State<_RestoreConfirmation> createState() => _RestoreConfirmationState();
}
class _RestoreConfirmationState extends State<_RestoreConfirmation> {
  final _password = TextEditingController();
  bool _confirmed = false;
  @override
  void dispose() { _password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Replace local workspace?'),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('This replaces every current account, category, and transaction. Export your current workspace first. An incorrect password or invalid backup will not change it.'),
      const SizedBox(height: 16), TextField(controller: _password, obscureText: true, autocorrect: false,
        enableSuggestions: false, decoration: const InputDecoration(labelText: 'Backup password', border: OutlineInputBorder())),
      CheckboxListTile(value: _confirmed, onChanged: (v) => setState(() => _confirmed = v ?? false),
        title: const Text('Replace my current local workspace'), controlAffinity: ListTileControlAffinity.leading),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: !_confirmed ? null : () => Navigator.pop(context, _password.text), child: const Text('Restore'))]);
}

Future<void> manageLocalCategories(BuildContext context, LocalFinanceApi api) async {
  var categories = LocalLedger.rows((await api.snapshot())['categories']);
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
    title: const Text('Categories'), content: SizedBox(width: 450, height: 400,
      child: ListView(children: categories.map((c) => ListTile(title: Text(c['name'] as String), subtitle: Text(c['kind'] as String),
        trailing: const Icon(Icons.edit_outlined), onTap: () async {
          final result = await showDialog<Json>(context: context, builder: (_) => _CategoryDialog(existing: c));
          if (result == null) return;
          try {
            await api.saveCategory(result); categories = LocalLedger.rows((await api.snapshot())['categories']);
            if (context.mounted) setState(() {});
          } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
        })).toList())),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
      TextButton(onPressed: () async {
        try {
          await showCategoryRules(context, api);
          categories = LocalLedger.rows((await api.snapshot())['categories']);
          if (context.mounted) setState(() {});
        } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
      }, child: const Text('Categorization rules')),
      FilledButton(onPressed: () async {
        final result = await showDialog<Json>(context: context, builder: (_) => const _CategoryDialog());
        if (result == null) return;
        try {
          await api.saveCategory(result); categories = LocalLedger.rows((await api.snapshot())['categories']);
          if (context.mounted) setState(() {});
        } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
      }, child: const Text('Add category'))],
  )));
}
class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.existing});
  final Json? existing;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}
class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.existing?['name'] as String? ?? '');
  late String _kind = widget.existing?['kind'] as String? ?? 'Expense';
  @override
  void dispose() { _name.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.existing == null ? 'Add category' : 'Rename category'),
    content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _name, autofocus: true, maxLength: 80, decoration: const InputDecoration(labelText: 'Category name')),
      if (widget.existing == null) DropdownButtonFormField<String>(initialValue: _kind,
        items: const [DropdownMenuItem(value: 'Expense', child: Text('Expense')), DropdownMenuItem(value: 'Income', child: Text('Income'))],
        onChanged: (v) => setState(() => _kind = v ?? _kind)),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, {'operationId': const Uuid().v4(),
        if (widget.existing != null) 'id': widget.existing!['id'], 'name': _name.text.trim(), 'kind': _kind}), child: const Text('Save'))]);
}
