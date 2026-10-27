import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'ledger.dart';

abstract class VaultStorage {
  String get location;
  Future<String?> read();
  Future<void> write(String envelope, {required int expectedRevision});
  Future<void> close();
}

const vaultIterations = 600000;
const maxVaultBytes = 24 * 1024 * 1024;
const _format = 'Budgetism.encrypted-workspace';

Future<List<int>> _derive(Map<String, dynamic> args) async {
  final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: vaultIterations, bits: 256)
      .deriveKeyFromPassword(password: args['password'] as String, nonce: (args['salt'] as List).cast<int>());
  return key.extractBytes();
}

/// Financial payloads are encrypted; SQLite headers and revision metadata are not.
/// Passwords and keys are never persisted. Lost passwords cannot be recovered.
class LocalVault {
  LocalVault._(this.storage, this._ledger, this._salt, this._key);
  final VaultStorage storage;
  LocalLedger _ledger;
  final List<int> _salt;
  final Uint8List _key;
  bool _busy = false;
  bool _closed = false;
  LocalLedger get ledger {
    if (_closed) throw StateError('Workspace is locked.');
    return LocalLedger(_ledger.data);
  }
  String get location => storage.location;

  static Json header(String encoded) {
    if (utf8.encode(encoded).length > maxVaultBytes) throw const FormatException('Backup exceeds the supported size.');
    final value = jsonDecode(encoded);
    if (value is! Map) throw const FormatException('Invalid encrypted workspace.');
    final h = Map<String, dynamic>.from(value);
    if (h['format'] != _format || h['version'] != 1 || h['kdf'] != 'PBKDF2-SHA256' ||
        h['iterations'] != vaultIterations || h['revision'] is! int || h['revision'] < 0) {
      throw const FormatException('Unsupported encrypted workspace format.');
    }
    if (base64Decode(h['salt'] as String).length != 16 ||
        base64Decode(h['nonce'] as String).length != 12 ||
        base64Decode(h['tag'] as String).length != 16) throw const FormatException('Invalid encryption metadata.');
    return h;
  }
  static List<int> _aad(int revision) => utf8.encode('$_format|1|$vaultIterations|$revision');
  static Future<LocalLedger> _decrypt(Json h, List<int> key) async {
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(h['data'] as String), nonce: base64Decode(h['nonce'] as String),
          mac: Mac(base64Decode(h['tag'] as String))),
        secretKey: SecretKey(key), aad: _aad(h['revision'] as int));
      final ledger = LocalLedger(Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map));
      if (ledger.revision != h['revision']) throw const FormatException('Invalid workspace revision.');
      return ledger;
    } on SecretBoxAuthenticationError {
      throw const FormatException('The passphrase is incorrect or the workspace has been damaged. Nothing was changed.');
    }
  }

  static Future<LocalVault> open(VaultStorage storage, String password, {required bool create}) async {
    Uint8List? key;
    try {
      final existing = await storage.read();
      if (create && existing != null) throw StateError('A workspace already exists. Unlock it instead.');
      if (!create && existing == null) throw StateError('No saved workspace exists.');
      if (create && password.length < 14) throw const FormatException('Use a passphrase with at least 14 characters.');
      final h = existing == null ? null : header(existing);
      final salt = h == null ? List<int>.generate(16, (_) => Random.secure().nextInt(256)) : base64Decode(h['salt'] as String);
      key = Uint8List.fromList(await compute(_derive, {'password': password, 'salt': salt}));
      final ledger = h == null ? LocalLedger.empty() : await _decrypt(h, key);
      final vault = LocalVault._(storage, ledger, salt, key);
      if (create) await storage.write(await vault._seal(ledger), expectedRevision: -1);
      return vault;
    } catch (_) {
      if (key != null) key.fillRange(0, key.length, 0);
      rethrow;
    }
  }

  Future<String> _seal(LocalLedger ledger) async {
    final plain = utf8.encode(jsonEncode(ledger.data));
    if (plain.length > 16 * 1024 * 1024) throw StateError('This preview supports workspaces up to 16 MB. Export a backup before continuing.');
    final box = await AesGcm.with256bits().encrypt(plain, secretKey: SecretKey(_key), aad: _aad(ledger.revision));
    return jsonEncode({'format': _format, 'version': 1, 'kdf': 'PBKDF2-SHA256',
      'iterations': vaultIterations, 'revision': ledger.revision,
      'salt': base64Encode(_salt), 'nonce': base64Encode(box.nonce),
      'tag': base64Encode(box.mac.bytes), 'data': base64Encode(box.cipherText)});
  }
  void _begin() {
    if (_closed) throw StateError('Workspace is locked.');
    if (_busy) throw StateError('Another workspace operation is still running.');
    _busy = true;
  }
  Future<void> apply(String action, Json input) async {
    _begin();
    try {
      final next = _ledger.apply(action, input);
      if (identical(next, _ledger)) return;
      await storage.write(await _seal(next), expectedRevision: _ledger.revision);
      _ledger = next; // Never display an unsaved mutation as committed.
    } finally { _busy = false; }
  }
  Future<void> refresh() async {
    _begin();
    try {
      final saved = await storage.read();
      if (saved == null) throw StateError('Saved workspace is missing. Lock and investigate before continuing.');
      final h = header(saved);
      _ledger = await _decrypt(h, _key);
    } finally { _busy = false; }
  }
  Future<String> exportBackup() async {
    _begin();
    try {
      final encoded = await storage.read();
      if (encoded == null) throw StateError('No saved workspace exists.');
      // Verify the exact encrypted bytes to be exported, including schema and postings.
      await _decrypt(header(encoded), _key);
      return encoded;
    } finally { _busy = false; }
  }
  Future<void> restoreBackup(String encoded, String backupPassword) async {
    _begin();
    Uint8List? key;
    try {
      final h = header(encoded);
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
    if (_busy) throw StateError('Wait until the save finishes before locking.');
    if (_closed) return;
    await storage.close();
    _key.fillRange(0, _key.length, 0);
    _closed = true;
    _ledger = LocalLedger.empty();
  }
}
