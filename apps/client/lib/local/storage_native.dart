import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'vault.dart';

const localStorageSupported = true;
const _applicationId = 0x42554447;

Future<VaultStorage> openVaultStorage() async {
  final String base;
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) throw StateError('Windows application-data directory is unavailable.');
    base = '$local${Platform.pathSeparator}Budgetism';
  } else {
    base = '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}Budgetism';
  }
  final directory = Directory('$base${Platform.pathSeparator}finance');
  await directory.create(recursive: true);
  return SqliteVaultStorage('${directory.path}${Platform.pathSeparator}workspace.sqlite3');
}

/// Only ciphertext is stored. SQLite transactions protect commits and retain
/// one previous encrypted snapshot; a revision check prevents stale writers.
class SqliteVaultStorage implements VaultStorage {
  SqliteVaultStorage(this.location) : _db = sqlite3.open(location) {
    try {
      _db.execute('PRAGMA busy_timeout = 5000');
      final id = _db.select('PRAGMA application_id').first.values.first as int;
      final version = _db.userVersion;
      final tables = _db.select("SELECT name FROM sqlite_master WHERE type = 'table'");
      if (id == 0 && version == 0 && tables.isEmpty) {
        _db.execute('BEGIN IMMEDIATE');
        try {
          _db.execute('CREATE TABLE vault (id INTEGER PRIMARY KEY CHECK (id = 1), revision INTEGER NOT NULL, current TEXT NOT NULL, previous TEXT)');
          _db.execute('PRAGMA application_id = $_applicationId');
          _db.userVersion = 1;
          _db.execute('COMMIT');
        } catch (_) { _db.execute('ROLLBACK'); rethrow; }
      } else if (id != _applicationId || version != 1) {
        throw StateError('Unsupported or unrelated database. Nothing was reset.');
      }
      _db.execute('PRAGMA journal_mode = DELETE');
      _db.execute('PRAGMA synchronous = FULL');
    } catch (_) { _db.close(); rethrow; }
  }
  final Database _db;
  bool _closed = false;
  @override
  final String location;
  void _checkOpen() { if (_closed) throw StateError('Workspace is locked.'); }
  @override
  Future<String?> read() async {
    _checkOpen();
    final rows = _db.select('SELECT current FROM vault WHERE id = 1');
    return rows.isEmpty ? null : rows.single['current'] as String;
  }
  @override
  Future<void> write(String envelope, {required int expectedRevision}) async {
    _checkOpen();
    final next = LocalVault.header(envelope)['revision'] as int;
    if (next != expectedRevision + 1) throw StateError('Invalid workspace revision sequence.');
    _db.execute('BEGIN IMMEDIATE');
    try {
      final rows = _db.select('SELECT revision FROM vault WHERE id = 1');
      final revision = rows.isEmpty ? -1 : rows.single['revision'] as int;
      if (revision != expectedRevision) throw StateError('This workspace was changed in another window. Refresh, then retry your edit.');
      if (rows.isEmpty) {
        _db.execute('INSERT INTO vault (id, revision, current) VALUES (1, ?, ?)', [next, envelope]);
      } else {
        _db.execute('UPDATE vault SET previous = current, current = ?, revision = ? WHERE id = 1', [envelope, next]);
      }
      _db.execute('COMMIT');
    } catch (_) { _db.execute('ROLLBACK'); rethrow; }
  }
  @override
  Future<void> close() async { if (!_closed) { _db.close(); _closed = true; } }
}
