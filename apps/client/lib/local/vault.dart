import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'ledger.dart';

abstract class VaultStorage {
  String get location;
  Future<String?> read();
  Future<void> write(String envelope, {required int expectedRevision});
  Future<void> close();
}

/// Implementations must use OS-protected storage, never preferences or plain files.
abstract class DeviceKeyStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

const vaultIterations = 600000;
const maxVaultBytes = 24 * 1024 * 1024;
const _format = 'Budgetism.encrypted-workspace';

Future<List<int>> _derive(Map<String, dynamic> args) async {
  final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: vaultIterations, bits: 256)
      .deriveKeyFromPassword(password: args['password'] as String, nonce: (args['salt'] as List).cast<int>());
  return key.extractBytes();
}

/// Reads existing format-1 password workspaces without changing them. Format 2
/// authenticates the chosen access mode. Financial records remain encrypted in
/// both modes; device mode stores only its random key in OS-protected storage.
class LocalVault {
  LocalVault._(this.storage, this._ledger, this._salt, this._key,
      this._version, this._passwordRequired, this._deviceKeys);
  final VaultStorage storage;
  final DeviceKeyStore? _deviceKeys;
  LocalLedger _ledger;
  List<int> _salt;
  Uint8List _key;
  int _version;
  bool _passwordRequired;
  bool _busy = false;
  bool _closed = false;
  bool get passwordRequired => _passwordRequired;
  LocalLedger get ledger {
    if (_closed) throw StateError('Workspace is closed.');
    return LocalLedger(_ledger.data);
  }
  String get location => storage.location;

  static List<int> _random(int size) {
    final random = Random.secure();
    return List<int>.generate(size, (_) => random.nextInt(256));
  }
  static bool requiresPassword(Json h) => h['version'] == 1 || h['unlock'] == 'password';
  static String _keyName(List<int> salt) => 'Budgetism.local-key.${base64UrlEncode(salt).replaceAll('=', '')}';
  static Json header(String encoded) {
    if (utf8.encode(encoded).length > maxVaultBytes) throw const FormatException('Backup exceeds the supported size.');
    final value = jsonDecode(encoded);
    if (value is! Map) throw const FormatException('Invalid encrypted workspace.');
    final h = Map<String, dynamic>.from(value);
    final version = h['version'];
    if (h['format'] != _format || (version != 1 && version != 2) ||
        h['revision'] is! int || (h['revision'] as int) < 0 ||
        (version == 2 && !['password', 'device'].contains(h['unlock']))) {
      throw const FormatException('Unsupported encrypted workspace format. Nothing was reset.');
    }
    final password = requiresPassword(h);
    if (h['kdf'] != (password ? 'PBKDF2-SHA256' : 'OS-KEYSTORE') ||
        h['iterations'] != (password ? vaultIterations : 0)) {
      throw const FormatException('Unsupported workspace key protection.');
    }
    for (final field in ['salt', 'nonce', 'tag', 'data']) {
      if (h[field] is! String) throw const FormatException('Invalid encryption metadata.');
    }
    if (base64Decode(h['salt'] as String).length != 16 ||
        base64Decode(h['nonce'] as String).length != 12 ||
        base64Decode(h['tag'] as String).length != 16) {
      throw const FormatException('Invalid encryption metadata.');
    }
    return h;
  }
  static List<int> _aad(Json h) => utf8.encode(h['version'] == 1
      ? '$_format|1|$vaultIterations|${h['revision']}'
      : '$_format|2|${h['kdf']}|${h['iterations']}|${h['revision']}|${h['unlock']}|${h['salt']}');
  static Future<LocalLedger> _decrypt(Json h, List<int> key) async {
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(h['data'] as String), nonce: base64Decode(h['nonce'] as String),
          mac: Mac(base64Decode(h['tag'] as String))),
        secretKey: SecretKey(key), aad: _aad(h));
      try {
        final ledger = LocalLedger(Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map));
        if (ledger.revision != h['revision']) throw const FormatException('Invalid workspace revision.');
        return ledger;
      } finally { plain.fillRange(0, plain.length, 0); }
    } on SecretBoxAuthenticationError {
      throw const FormatException('The password or device key is incorrect, or the workspace has been damaged. Nothing was changed.');
    }
  }
  static Future<void> _saveDeviceKey(DeviceKeyStore? store, List<int> salt, List<int> key) async {
    if (store == null) throw StateError('OS-protected storage is unavailable. No workspace settings were changed.');
    final name = _keyName(salt);
    final value = base64Encode(key);
    await store.write(name, value);
    if (await store.read(name) != value) {
      throw StateError('The device key could not be verified. Nothing was changed.');
    }
  }
  // Prefer an orphaned encrypted OS entry to deleting a key after an uncertain
  // commit. Never delete a credential that the currently saved envelope uses.
  static Future<void> _discardUncommittedKey(VaultStorage storage, DeviceKeyStore? store, List<int> salt) async {
    try {
      final current = await storage.read();
      if (current != null && header(current)['salt'] == base64Encode(salt)) return;
      await store?.delete(_keyName(salt));
    } catch (_) { /* Retain the recovery key if commit status cannot be checked. */ }
  }

  static Future<LocalVault> open(VaultStorage storage, String password,
      {required bool create, bool requirePassword = true, DeviceKeyStore? deviceKeys}) async {
    Uint8List? key;
    List<int>? attemptedSalt;
    try {
      final existing = await storage.read();
      if (create && existing != null) throw StateError('A workspace already exists. Open it instead.');
      if (!create && existing == null) throw StateError('No saved workspace exists.');
      final h = existing == null ? null : header(existing);
      final protected = h == null ? requirePassword : requiresPassword(h);
      if (create && protected && password.length < 14) throw const FormatException('Use a password with at least 14 characters.');
      final salt = h == null ? _random(16) : base64Decode(h['salt'] as String);
      if (protected) {
        key = Uint8List.fromList(await compute(_derive, {'password': password, 'salt': salt}));
      } else if (create) {
        key = Uint8List.fromList(_random(32));
        attemptedSalt = salt;
        await _saveDeviceKey(deviceKeys, salt, key);
      } else {
        final saved = await deviceKeys?.read(_keyName(salt));
        if (saved == null) {
          throw StateError('Device unlock is unavailable for this OS user. No data was reset. Use the original OS profile or restore an exported backup in a new workspace.');
        }
        key = Uint8List.fromList(base64Decode(saved));
        if (key.length != 32) throw const FormatException('The saved device key is invalid. Nothing was changed.');
      }
      final ledger = h == null ? LocalLedger.empty() : await _decrypt(h, key);
      final vault = LocalVault._(storage, ledger, salt, key, h?['version'] as int? ?? 2, protected, deviceKeys);
      if (create) await storage.write(await vault._seal(ledger), expectedRevision: -1);
      return vault;
    } catch (_) {
      if (attemptedSalt != null) await _discardUncommittedKey(storage, deviceKeys, attemptedSalt);
      if (key != null) key.fillRange(0, key.length, 0);
      rethrow;
    }
  }

  static Future<String> _sealWith(LocalLedger ledger, List<int> key, List<int> salt,
      {required int version, required bool passwordRequired}) async {
    final plain = utf8.encode(jsonEncode(ledger.data));
    try {
      if (plain.length > 16 * 1024 * 1024) throw StateError('This preview supports workspaces up to 16 MB. Export a backup before continuing.');
      final h = <String, dynamic>{'format': _format, 'version': version,
        'kdf': passwordRequired ? 'PBKDF2-SHA256' : 'OS-KEYSTORE',
        'iterations': passwordRequired ? vaultIterations : 0, 'revision': ledger.revision,
        'salt': base64Encode(salt), if (version == 2) 'unlock': passwordRequired ? 'password' : 'device'};
      final box = await AesGcm.with256bits().encrypt(plain, secretKey: SecretKey(key), aad: _aad(h));
      return jsonEncode({...h, 'nonce': base64Encode(box.nonce),
        'tag': base64Encode(box.mac.bytes), 'data': base64Encode(box.cipherText)});
    } finally { plain.fillRange(0, plain.length, 0); }
  }
  Future<String> _seal(LocalLedger ledger) => _sealWith(ledger, _key, _salt,
      version: _version, passwordRequired: _passwordRequired);
  void _begin() {
    if (_closed) throw StateError('Workspace is closed.');
    if (_busy) throw StateError('Another workspace operation is still running.');
    _busy = true;
  }
  Future<Json> _readCurrent({bool sameRevision = false}) async {
    final saved = await storage.read();
    if (saved == null) throw StateError('Saved workspace is missing. Close it and investigate before continuing.');
    final h = header(saved);
    if (h['salt'] != base64Encode(_salt) || h['version'] != _version || requiresPassword(h) != _passwordRequired) {
      throw StateError('Workspace security changed in another window. Close and reopen this workspace.');
    }
    if (sameRevision && h['revision'] != _ledger.revision) {
      throw StateError('Workspace changed in another window. Refresh before changing its security.');
    }
    return h;
  }
  Future<void> apply(String action, Json input) async {
    _begin();
    try {
      await _readCurrent();
      final next = _ledger.apply(action, input);
      if (identical(next, _ledger)) return;
      await storage.write(await _seal(next), expectedRevision: _ledger.revision);
      _ledger = next;
    } finally { _busy = false; }
  }
  Future<void> refresh() async {
    _begin();
    try { _ledger = await _decrypt(await _readCurrent(), _key); }
    finally { _busy = false; }
  }

  /// Changing access mode rotates the key and salt but preserves every financial
  /// record. The OS key is verified before committing device mode. Existing
  /// windows fail closed instead of writing with an obsolete key.
  /// Returns a non-fatal cleanup warning after a successful commit, if necessary.
  Future<String?> setPasswordRequired(bool required,
      {String currentPassword = '', String newPassword = ''}) async {
    _begin();
    Uint8List? nextKey;
    Uint8List? checkKey;
    List<int>? attemptedSalt;
    var committed = false;
    try {
      if (required == _passwordRequired) return null;
      final current = await _readCurrent(sameRevision: true);
      if (_passwordRequired) {
        checkKey = Uint8List.fromList(await compute(_derive, {'password': currentPassword, 'salt': _salt}));
        await _decrypt(current, checkKey);
      }
      if (required && newPassword.length < 14) throw const FormatException('Use a password with at least 14 characters.');
      final salt = _random(16);
      nextKey = required
          ? Uint8List.fromList(await compute(_derive, {'password': newPassword, 'salt': salt}))
          : Uint8List.fromList(_random(32));
      if (!required) {
        attemptedSalt = salt;
        await _saveDeviceKey(_deviceKeys, salt, nextKey);
      }
      final data = LocalLedger.clone(_ledger.data);
      data['revision'] = _ledger.revision + 1;
      (data['audit'] as List).add({'action': 'security-mode', 'atUtc': DateTime.now().toUtc().toIso8601String(),
        'passwordRequired': required});
      final next = LocalLedger(data);
      final encoded = await _sealWith(next, nextKey, salt, version: 2, passwordRequired: required);
      await storage.write(encoded, expectedRevision: _ledger.revision);
      committed = true;
      final oldCredential = !_passwordRequired ? _keyName(_salt) : null;
      _key.fillRange(0, _key.length, 0);
      _key = nextKey;
      nextKey = null;
      _salt = salt; _version = 2; _passwordRequired = required; _ledger = next;
      if (oldCredential != null) {
        try { await _deviceKeys?.delete(oldCredential); }
        catch (_) { return 'Password protection is enabled, but an obsolete device credential could not be removed. It cannot open the current workspace. Previously copied data is not retroactively protected.'; }
      }
      return null;
    } finally {
      if (!committed && attemptedSalt != null) await _discardUncommittedKey(storage, _deviceKeys, attemptedSalt);
      if (nextKey != null) nextKey.fillRange(0, nextKey.length, 0);
      if (checkKey != null) checkKey.fillRange(0, checkKey.length, 0);
      _busy = false;
    }
  }

  /// Explicit backup passwords keep device-mode backups portable. The UI always
  /// requests one. No-password export is retained only for legacy password-mode
  /// callers; device credentials are never exported.
  Future<String> exportBackup({String? password}) async {
    _begin();
    Uint8List? backupKey;
    try {
      final h = await _readCurrent();
      final saved = await _decrypt(h, _key);
      if (password == null) {
        if (!_passwordRequired) throw StateError('Choose a backup password before exporting a device-unlocked workspace.');
        return jsonEncode(h);
      }
      if (password.length < 14) throw const FormatException('Use a backup password with at least 14 characters.');
      final salt = _random(16);
      backupKey = Uint8List.fromList(await compute(_derive, {'password': password, 'salt': salt}));
      // The original password format remains readable by existing restore code.
      return await _sealWith(saved, backupKey, salt, version: 1, passwordRequired: true);
    } finally { if (backupKey != null) backupKey.fillRange(0, backupKey.length, 0); _busy = false; }
  }
  Future<void> restoreBackup(String encoded, String backupPassword) async {
    _begin();
    Uint8List? key;
    try {
      await _readCurrent(sameRevision: true);
      final h = header(encoded);
      if (!requiresPassword(h)) throw const FormatException('This is a device-bound database snapshot, not a portable backup. Use Export encrypted backup on the original device.');
      key = Uint8List.fromList(await compute(_derive, {'password': backupPassword, 'salt': base64Decode(h['salt'] as String)}));
      final recovered = await _decrypt(h, key);
      final data = LocalLedger.clone(recovered.data);
      data['revision'] = _ledger.revision + 1;
      (data['audit'] as List).add({'action': 'restore', 'atUtc': DateTime.now().toUtc().toIso8601String(),
        'fromBackupRevision': recovered.revision, 'replacedRevision': _ledger.revision});
      final next = LocalLedger(data);
      await storage.write(await _seal(next), expectedRevision: _ledger.revision);
      _ledger = next;
    } finally { if (key != null) key.fillRange(0, key.length, 0); _busy = false; }
  }
  Future<void> close() async {
    if (_busy) throw StateError('Wait until the save finishes before closing.');
    if (_closed) return;
    await storage.close();
    _key.fillRange(0, _key.length, 0);
    _closed = true;
    _ledger = LocalLedger.empty();
  }
}
