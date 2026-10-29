import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/bank_provider.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'bank_test_helpers.dart';
import 'local_security_test.dart' show TestStorage, TestDeviceKeys;

class _DelayedProvider implements BankProvider {
  final gate = Completer<void>();
  @override
  String get providerId => BankSync.simulatedProvider;
  @override
  Future<BankPage> fetch({required String checkpoint, String? pageToken}) async {
    await gate.future;
    return SimulatedBankProvider().fetch(checkpoint: checkpoint, pageToken: pageToken);
  }
}

class _BadPages implements BankProvider {
  _BadPages(this.mode);
  final String mode;
  @override
  String get providerId => BankSync.simulatedProvider;
  @override
  Future<BankPage> fetch({required String checkpoint, String? pageToken}) async {
    final p = await SimulatedBankProvider().fetch(checkpoint: checkpoint, pageToken: pageToken);
    return BankPage(
      batchId: pageToken != null && mode == 'changed' ? 'different' : p.batchId,
      fromCheckpoint: p.fromCheckpoint,
      checkpoint: p.checkpoint,
      dataTimestampUtc: p.dataTimestampUtc,
      records: p.records,
      balances: p.balances,
      nextPageToken: mode == 'cycle' ? 'second' : p.nextPageToken,
    );
  }
}

class _UncertainStorage extends TestStorage {
  bool throwAfterCommit = false;
  @override
  Future<void> write(String value, {required int expectedRevision}) async {
    await super.write(value, expectedRevision: expectedRevision);
    if (throwAfterCommit) {
      throwAfterCommit = false;
      throw StateError('Unknown commit outcome');
    }
  }
}

Future<LocalVault> _vault(TestStorage storage) =>
    LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('encrypted connect, refresh and review failures leave payload unchanged and retries commit once', () async {
    final storage = TestStorage();
    final vault = await _vault(storage);
    try {
      for (final action in ['bank-connect', 'bank-refresh', 'bank-review']) {
        final input =
            action == 'bank-connect'
                ? connectRequest(vault.ledger)
                : action == 'bank-refresh'
                ? await simulatedBatch(vault.ledger)
                : reviewRequest(vault.ledger, 'merchant', 'record', {'categoryId': bankCategory(vault.ledger)});
        final before = storage.saved, revision = vault.ledger.revision;
        storage.failWrite = true;
        await expectLater(vault.apply(action, input), throwsStateError);
        expect(storage.saved, before);
        expect(vault.ledger.revision, revision);
        storage.failWrite = false;
        await vault.apply(action, input);
        final after = storage.saved;
        await vault.apply(action, input);
        expect(storage.saved, after);
      }
      expect(storage.saved, isNot(contains('Orchard')));
      expect(storage.saved, isNot(contains('Bookshop')));
      expect(vault.passwordRequired, false);
    } finally {
      await vault.close();
    }
  });
  test('interrupted fetch retains sources, last success and checkpoint; one safe retry succeeds', () async {
    final storage = TestStorage();
    final vault = await _vault(storage);
    try {
      await vault.apply('bank-connect', connectRequest(vault.ledger));
      final service = BankRefreshService(vault), id = bankConnection(vault.ledger)['id'] as String;
      await service.refresh(id);
      final before = vault.ledger;
      await expectLater(service.refresh(id, interruptAfterFirstPage: true), throwsStateError);
      expect(vault.ledger.data['bankSources'], before.data['bankSources']);
      expect(bankConnection(vault.ledger)['checkpoint'], bankConnection(before)['checkpoint']);
      expect(bankConnection(vault.ledger)['lastSuccessUtc'], bankConnection(before)['lastSuccessUtc']);
      expect(bankConnection(vault.ledger)['refreshStatus'], 'error');
      expect(BankSync.inbox(vault.ledger.data).where((i) => i['source'] == null).length, 1);
      await service.refresh(id);
      final after = vault.ledger;
      await service.refresh(id, repeatLast: true);
      expect(vault.ledger.data, after.data);
      expect(bankConnection(after)['checkpoint'], '2');
      expect(bankConnection(after)['refreshStatus'], 'success');
    } finally {
      await vault.close();
    }
  });
  test('single flight, changed pages, cyclic pagination and stale concurrent writes fail closed', () async {
    final storage = TestStorage(), keys = TestDeviceKeys();
    final vault = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: keys);
    try {
      await vault.apply('bank-connect', connectRequest(vault.ledger));
      final service = BankRefreshService(vault), id = bankConnection(vault.ledger)['id'] as String;
      for (final mode in ['changed', 'cycle']) {
        await expectLater(service.refresh(id, provider: _BadPages(mode)), throwsStateError);
        expect(vault.ledger.data['bankSources'], isEmpty);
        expect(bankConnection(vault.ledger)['checkpoint'], '');
      }
      final delayed = _DelayedProvider();
      final task = service.refresh(id, provider: delayed);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await expectLater(service.refresh(id), throwsStateError);
      final other = await LocalVault.open(storage, '', create: false, deviceKeys: keys);
      await other.apply('category', {
        'operationId': 'concurrent',
        'name': 'Fictional concurrent category',
        'kind': 'Expense',
      });
      await other.close();
      delayed.gate.complete();
      await expectLater(task, throwsStateError);
      expect(vault.ledger.data['bankSources'], isEmpty);
      expect(bankConnection(vault.ledger)['checkpoint'], '');
      await service.refresh(id);
      expect(bankConnection(vault.ledger)['checkpoint'], '1');
    } finally {
      await vault.close();
    }
  });
  test('uncertain successful commit is recovered without rollback or duplicate on retry', () async {
    final storage = _UncertainStorage();
    final v = await _vault(storage);
    try {
      await v.apply('bank-connect', connectRequest(v.ledger));
      final service = BankRefreshService(v), id = bankConnection(v.ledger)['id'] as String;
      storage.throwAfterCommit = true;
      await expectLater(service.refresh(id), throwsStateError);
      expect(bankConnection(v.ledger)['checkpoint'], '1');
      expect(BankSync.list(v.ledger.data, 'bankSources').length, 14);
      await service.refresh(id, repeatLast: true);
      expect(bankConnection(v.ledger)['refreshStatus'], 'success');
      expect(BankSync.list(v.ledger.data, 'bankSources').length, 14);
      expect(BankSync.list(v.ledger.data, 'bankBatches').length, 1);
    } finally {
      await v.close();
    }
  });
  test('SQLite restart, independent password backup and optional-password changes preserve all bank records', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-fictional-bank-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    final keys = TestDeviceKeys();
    LocalVault? vault, destination;
    const password = 'fictional bank portable backup password';
    try {
      vault = await LocalVault.open(
        SqliteVaultStorage(path),
        '',
        create: true,
        requirePassword: false,
        deviceKeys: keys,
      );
      await vault.apply('bank-connect', connectRequest(vault.ledger));
      await BankRefreshService(vault).refresh(bankConnection(vault.ledger)['id']);
      await vault.apply(
        'bank-review',
        reviewRequest(vault.ledger, 'merchant', 'record', {
          'categoryId': bankCategory(vault.ledger),
          'notes': 'Fictional private note',
        }),
      );
      final before = LocalLedger.clone(vault.ledger.data);
      final backup = await vault.exportBackup(password: password);
      expect(backup, isNot(contains('Fictional')));
      await vault.close();
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(vault.ledger.data, before);
      expect(vault.passwordRequired, false);
      destination = await LocalVault.open(
        TestStorage(),
        '',
        create: true,
        requirePassword: false,
        deviceKeys: TestDeviceKeys(),
      );
      await destination.restoreBackup(backup, password);
      for (final key in [...BankSync.collections, 'accounts', 'categories', 'transactions', 'operations']) {
        expect(destination.ledger.data[key], before[key], reason: key);
      }
      await vault.setPasswordRequired(true, newPassword: password);
      await vault.close();
      vault = await LocalVault.open(SqliteVaultStorage(path), password, create: false, deviceKeys: keys);
      expect(vault.passwordRequired, true);
      for (final key in BankSync.collections) {
        expect(vault.ledger.data[key], before[key]);
      }
      await vault.setPasswordRequired(false, currentPassword: password);
      expect(vault.passwordRequired, false);
    } finally {
      await destination?.close();
      await vault?.close();
      dir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
