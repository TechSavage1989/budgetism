import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/bank_widgets.dart';
import 'package:budgetism/local/bank_provider.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import '../test/bank_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('BANK_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('BANK_TEST_DIRECTORY');
  const password = 'fictional bank native backup password';
  testWidgets('fictional bank mapping, review, atomic refresh and backup survive native process restart', (
    tester,
  ) async {
    late Directory dir;
    late String path;
    LocalVault? vault, restored;
    const keys = SecureDeviceKeys();
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> open(Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () => showDialog<void>(context: context, builder: (_) => child),
                    child: const Text('Open test'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open test'));
      await tester.pumpAndSettle();
    }

    try {
      await tester.runAsync(() async {
        dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-bank-') : Directory(directory);
        path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to replace an existing workspace.');
          vault = await LocalVault.open(
            SqliteVaultStorage(path),
            '',
            create: true,
            requirePassword: false,
            deviceKeys: keys,
          );
        } else {
          vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        }
      });
      if (phase != 'read') {
        var completion = Completer<void>();
        await open(
          BankMappingDialog(
            snapshot: vault!.ledger.snapshot(),
            onSave: (input) async {
              try {
                await vault!.apply('bank-connect', input);
                completion.complete();
              } catch (error, stack) {
                completion.completeError(error, stack);
                rethrow;
              }
            },
          ),
        );
        final unchanged = await tester.runAsync(() => vault!.storage.read());
        await tap(find.byKey(const Key('bank-fictional-consent')));
        await tap(find.byKey(const Key('bank-upgrade-consent')));
        expect(await tester.runAsync(() => vault!.storage.read()), unchanged);
        await tap(find.byKey(const Key('bank-mapping-save')));
        await tester.runAsync(() => completion.future.timeout(const Duration(seconds: 30)));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await BankRefreshService(vault!).refresh(bankConnection(vault!.ledger)['id']);
        });
        expect(vault!.ledger.data['transactions'], isEmpty);
        final item = BankSync.inbox(
          vault!.ledger.data,
        ).firstWhere((r) => r['id'] == bankSource(vault!.ledger, 'merchant')['id']);
        completion = Completer<void>();
        await open(
          BankReviewDialog(
            snapshot: vault!.ledger.snapshot(),
            item: item,
            onSave: (input) async {
              try {
                await vault!.apply('bank-review', input);
                completion.complete();
              } catch (error, stack) {
                completion.completeError(error, stack);
                rethrow;
              }
            },
          ),
        );
        await tap(find.byKey(const Key('bank-decision')));
        await tester.tap(find.text('Record with a category').last);
        await tester.pumpAndSettle();
        await tap(find.byKey(const Key('bank-category')));
        await tester.tap(find.text('Dining').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('bank-notes')), 'Fictional native user note');
        await tester.pumpAndSettle();
        await tap(find.byKey(const Key('bank-review-consent')));
        await tap(find.byKey(const Key('bank-review-save')));
        await tester.runAsync(() => completion.future.timeout(const Duration(seconds: 30)));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final v = vault!, service = BankRefreshService(v), id = bankConnection(vault!.ledger)['id'] as String;
          final merchant = BankSync.list(v.ledger.data, 'transactions').single;
          await v.apply('reconcile', {
            'operationId': 'fictional-statement',
            'expectedRevision': v.ledger.revision,
            'accountId': bankAccount(v.ledger),
            'endDate': '2026-10-02',
            'closingMinor': 248800,
            'transactionIds': [merchant['id']],
            'confirmReviewed': true,
            'confirmReconciliationUpgrade': true,
            'note': 'Fictional statement',
          });
          final before = v.ledger.data;
          await expectLater(service.refresh(id, interruptAfterFirstPage: true), throwsStateError);
          expect(v.ledger.data['bankSources'], before['bankSources']);
          expect(bankConnection(v.ledger)['checkpoint'], '1');
          await service.refresh(id);
          await service.refresh(id);
          expect(bankConnection(v.ledger)['checkpoint'], '3');
          await expectLater(
            v.apply('bank-review', reviewRequest(v.ledger, 'merchant', 'correct')),
            throwsFormatException,
          );
          for (final pair in [('save-out', 'save-in'), ('card-out', 'card-in')]) {
            final other = bankSource(v.ledger, pair.$2);
            await v.apply(
              'bank-review',
              reviewRequest(v.ledger, pair.$1, 'transfer', {
                'otherSourceId': other['id'],
                'expectedOtherSourceRevision': other['revision'],
              }),
            );
          }
          for (final source in ['dining-posted', 'fuel-posted']) {
            await v.apply(
              'bank-review',
              reviewRequest(v.ledger, source, 'record', {'categoryId': bankCategory(v.ledger)}),
            );
          }
          final beforeRepeat = v.ledger.data;
          await service.refresh(id, repeatLast: true);
          expect(v.ledger.data, beforeRepeat);
          final backup = await v.exportBackup(password: password);
          File('${dir.path}${Platform.pathSeparator}fictional-backup.budgetism').writeAsStringSync(backup);
          await v.close();
          vault = null;
          if (phase != 'write') {
            vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
          }
        });
        if (phase == 'write') return;
      }
      final l = vault!.ledger;
      expect(vault!.passwordRequired, false);
      expect(l.data['schema'], 8);
      expect(bankConnection(l)['checkpoint'], '3');
      expect(bankConnection(l)['refreshStatus'], 'success');
      expect(BankSync.list(l.data, 'bankSources').length, 17);
      expect(BankSync.list(l.data, 'transactions').length, 5);
      expect(BudgetEngine.calculate(l.snapshot(), '2026-10').spent, 9432);
      expect(BankSync.list(l.snapshot(), 'accounts').map((a) => a['balanceMinor']).toList(), [215568, 120000, -5000]);
      expect(bankSource(l, 'dining-auth')['supersededBy'], bankSource(l, 'dining-posted')['id']);
      expect(bankSource(l, 'card-out')['transactionId'], bankSource(l, 'card-in')['transactionId']);
      final merchant = BankSync.list(
        l.data,
        'transactions',
      ).firstWhere((t) => t['id'] == bankSource(l, 'merchant')['transactionId']);
      expect(merchant['amountMinor'], 1200);
      expect(merchant['notes'], 'Fictional native user note');
      expect(Reconciliation.locked(l.data, merchant['id']), true);
      expect(
        BankSync.inbox(l.data).firstWhere((r) => r['id'] == bankSource(l, 'merchant')['id'])['reasons'],
        contains('reconciliation_conflict'),
      );
      await tester.runAsync(() async {
        final backup = File('${dir.path}${Platform.pathSeparator}fictional-backup.budgetism').readAsStringSync();
        restored = await LocalVault.open(
          SqliteVaultStorage('${dir.path}${Platform.pathSeparator}restored.sqlite3'),
          '',
          create: true,
          requirePassword: false,
          deviceKeys: keys,
        );
        await restored!.restoreBackup(backup, password);
        for (final key in [...BankSync.collections, 'transactions', 'accounts', 'reconciliations']) {
          expect(restored!.ledger.data[key], l.data[key], reason: key);
        }
        await restored!.setPasswordRequired(true, newPassword: password);
        await vault!.setPasswordRequired(true, newPassword: password);
      });
      expect(tester.takeException(), null);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await restored?.close();
        await vault?.close();
        if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true);
      });
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
