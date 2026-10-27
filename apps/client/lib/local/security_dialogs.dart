import 'package:flutter/material.dart';
import 'vault.dart';

Future<void> showWorkspaceSecurity(BuildContext context, LocalVault vault) =>
    showDialog<void>(context: context, barrierDismissible: false,
      builder: (_) => WorkspaceSecurityDialog(vault: vault));

class WorkspaceSecurityDialog extends StatefulWidget {
  const WorkspaceSecurityDialog({required this.vault, super.key});
  final LocalVault vault;
  @override
  State<WorkspaceSecurityDialog> createState() => _WorkspaceSecurityDialogState();
}

class _WorkspaceSecurityDialogState extends State<WorkspaceSecurityDialog> {
  late bool _required = widget.vault.passwordRequired;
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _status;
  bool get _changed => _required != widget.vault.passwordRequired;
  @override
  void dispose() { _current.dispose(); _password.dispose(); _confirm.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy || !_changed) return;
    if (_required && _password.text != _confirm.text) {
      setState(() => _status = 'Passwords do not match.'); return;
    }
    setState(() { _busy = true; _status = null; });
    try {
      final warning = await widget.vault.setPasswordRequired(_required,
        currentPassword: _current.text, newPassword: _password.text);
      if (!mounted) return;
      _current.clear(); _password.clear(); _confirm.clear();
      setState(() => _status = warning ?? (_required
          ? 'Saved. A password is required next time you open this workspace.'
          : 'Saved. This OS user can open the workspace without a password. Your records are unchanged.'));
    } catch (error) { if (mounted) setState(() => _status = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy,
    child: AlertDialog(title: const Text('Workspace security'),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Require a password to open this workspace'),
          value: _required, onChanged: _busy ? null : (value) => setState(() { _required = value; _status = null; })),
        const SizedBox(height: 10),
        Text(_required
          ? 'A workspace password will be required when opening it. Lost passwords cannot be recovered.'
          : 'No Budgetism password prompt. The encryption key is protected by this OS user account. Anyone able to use that account can open your financial records.'),
        const SizedBox(height: 12),
        const Text('Financial records stay encrypted in both modes. Changing this setting does not remove accounts or transactions. Export a backup before changing security.'),
        if (_changed && !_required) ...[
          const SizedBox(height: 16),
          TextField(controller: _current, enabled: !_busy, obscureText: true,
            autocorrect: false, enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Current workspace password', border: OutlineInputBorder(),
              helperText: 'Confirm once to turn password protection off.')),
        ],
        if (_changed && _required) ...[
          const SizedBox(height: 16),
          TextField(controller: _password, enabled: !_busy, obscureText: true,
            autocorrect: false, enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'New workspace password', border: OutlineInputBorder(),
              helperText: 'At least 14 characters.')),
          const SizedBox(height: 12),
          TextField(controller: _confirm, enabled: !_busy, obscureText: true,
            autocorrect: false, enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Confirm new password', border: OutlineInputBorder())),
        ],
        const SizedBox(height: 12),
        const Text('Device-unlocked data depends on the original OS key store. Backups use their own password and are the portable recovery method. Previously exported copies are not changed by this setting.'),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!)),
      ]))),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(onPressed: _busy || !_changed ? null : _save, child: const Text('Save'))],
    ));
}

Future<String?> requestBackupPassword(BuildContext context) => showDialog<String>(
    context: context, builder: (_) => const BackupPasswordDialog());

class BackupPasswordDialog extends StatefulWidget {
  const BackupPasswordDialog({super.key});
  @override
  State<BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}
class _BackupPasswordDialogState extends State<BackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }
  void _submit() {
    if (_password.text.length < 14) {
      setState(() => _error = 'Use a backup password with at least 14 characters.'); return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.'); return;
    }
    Navigator.pop(context, _password.text);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Protect exported backup'),
    content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('This password protects only the exported file. It does not turn on the local workspace password. Keep it separately; there is no recovery.'),
      const SizedBox(height: 16),
      TextField(controller: _password, obscureText: true, autocorrect: false, enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'Backup password', helperText: 'At least 14 characters.', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _confirm, obscureText: true, autocorrect: false, enableSuggestions: false,
        onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Confirm backup password', border: OutlineInputBorder())),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: const Text('Continue'))]);
}
