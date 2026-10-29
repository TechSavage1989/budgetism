import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/bank_provider.dart';
import 'package:budgetism/local/budgets.dart';
import 'bank_test_helpers.dart';
import 'local_ledger_test.dart' show account, tx;
import 'reconciliation_test.dart' show statementRequest, reopenRequest;
import 'category_history_test.dart' show appliedFixture;
import 'import_profiles_test.dart' show profileRequest;
import 'schedule_matching_test.dart' show matchingFixture, matchRequest;

void main() {
  test('populated rule/history/profile collections survive connection and every refresh unchanged', () async {
    var original = appliedFixture();
    original = original.apply('import-profile', profileRequest(original));
    var l = bankFixture(original);
    for (var i = 0; i < 4; i++) {
      l = l.apply('bank-refresh', await simulatedBatch(l));
    }
    for (final key in [
      'categories',
      'transactions',
      'budgets',
      'schedules',
      'occurrences',
      'imports',
      'reconciliations',
      'categoryRules',
      'importProfiles',
    ]) {
      expect(l.data[key], original.data[key], reason: key);
    }
    expect((l.data['audit'] as List).take((original.data['audit'] as List).length).toList(), original.data['audit']);
    for (final entry in (original.data['operations'] as Map).entries) {
      expect(l.data['operations'][entry.key], entry.value);
    }
  });
  test('bank linking and correction preserve a CSV receipt and settled schedule relationship', () {
    var l = matchingFixture(imported: true);
    l = l.apply('schedule-match', matchRequest(l, 'scheduled-link'));
    final original = LocalLedger.clone(l.data);
    final mapping = connectRequest(l);
    mapping['accounts'][0]['accountId'] = BankSync.list(l.data, 'accounts').first['id'];
    l = l.apply('bank-connect', mapping);
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('imported', -2000, 'Fictional shop', date: '2026-10-28')]),
    );
    final t = BankSync.list(l.data, 'transactions').single;
    l = l.apply(
      'bank-review',
      reviewRequest(l, 'imported', 'match', {'transactionId': t['id'], 'expectedTransactionVersion': t['version']}),
    );
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [
        SimulatedBankProvider.record('imported', -2100, 'Fictional shop corrected', date: '2026-10-28', revision: 2),
      ]),
    );
    l = l.apply('bank-review', reviewRequest(l, 'imported', 'correct'));
    expect(l.data['imports'], original['imports']);
    expect(l.data['occurrences'], original['occurrences']);
    expect(l.data['schedules'], original['schedules']);
    final corrected = BankSync.list(l.data, 'transactions').single;
    expect(corrected['scheduleId'], t['scheduleId']);
    expect(corrected['occurrenceIndex'], t['occurrenceIndex']);
    expect(corrected['amountMinor'], 2100);
    expect(BankSync.inbox(l.data), isEmpty);
  });
  test('paired transfer protects duplicates on either side and audits both source links', () async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    l = l.apply('transaction', {
      ...tx('existing-card', 'income', bankAccount(l, 'orchard-card'), bankCategory(l, 'Income'), 5000),
      'effectiveDate': '2026-10-02',
    });
    final other = bankSource(l, 'card-in');
    final request = reviewRequest(l, 'card-out', 'transfer', {
      'otherSourceId': other['id'],
      'expectedOtherSourceRevision': other['revision'],
    });
    expect(() => l.apply('bank-review', request), throwsFormatException);
    l = l.apply('bank-review', {...request, 'confirmDuplicate': true});
    expect(BankSync.list(l.data, 'audit').last['after']['sourceChanges'].length, 2);
  });
  test('paired transfer correction needs agreement; removal requires both explicit tombstones', () async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    final other = bankSource(l, 'card-in');
    l = l.apply(
      'bank-review',
      reviewRequest(l, 'card-out', 'transfer', {
        'otherSourceId': other['id'],
        'expectedOtherSourceRevision': other['revision'],
      }),
    );
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [
        SimulatedBankProvider.record('card-out', -6000, 'Fictional card payment', transfer: 'card-pair', revision: 2),
      ]),
    );
    expect(() => l.apply('bank-review', reviewRequest(l, 'card-out', 'correct')), throwsFormatException);
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [
        SimulatedBankProvider.record(
          'card-in',
          6000,
          'Fictional card payment',
          account: 'orchard-card',
          transfer: 'card-pair',
          revision: 2,
        ),
      ]),
    );
    l = l.apply('bank-review', reviewRequest(l, 'card-out', 'correct'));
    expect(BankSync.list(l.data, 'transactions').single['amountMinor'], 6000);
    expect(bankSource(l, 'card-in')['reviewedRevision'], 2);
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [
        SimulatedBankProvider.record(
          'card-out',
          -6000,
          'Fictional card payment',
          transfer: 'card-pair',
          revision: 3,
          state: 'removed',
        ),
      ]),
    );
    expect(() => l.apply('bank-review', reviewRequest(l, 'card-out', 'remove')), throwsFormatException);
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [
        SimulatedBankProvider.record(
          'card-in',
          6000,
          'Fictional card payment',
          account: 'orchard-card',
          transfer: 'card-pair',
          revision: 3,
          state: 'removed',
        ),
      ]),
    );
    l = l.apply('bank-review', reviewRequest(l, 'card-out', 'remove'));
    expect(BankSync.list(l.data, 'transactions').single['voided'], true);
    expect(BankSync.list(l.snapshot(), 'accounts').map((a) => a['balanceMinor']).toList(), [250000, 100000, -10000]);
  });
  test('posted replacement audits the changed pending relationship and rejects competing successors', () {
    var l = bankFixture();
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('auth', -2500, 'Fictional', state: 'pending')]),
    );
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('posted', -2800, 'Fictional', pending: 'auth')]),
    );
    final changes =
        BankSync.list(l.data, 'audit').where((e) => e['action'] == 'bank-source-batch').last['changes'] as List;
    expect(changes.length, 2);
    expect(changes.where((c) => c['before'] != null).single['before']['supersededBy'], null);
    expect(
      () => l.apply(
        'bank-refresh',
        sourceBatch(l, [SimulatedBankProvider.record('another', -2800, 'Fictional', pending: 'auth')]),
      ),
      throwsFormatException,
    );
    final damaged = LocalLedger.clone(l.data);
    damaged['bankSources'][0]['supersededBy'] = null;
    expect(() => LocalLedger(damaged), throwsFormatException);
  });
  test('reading old schemas never migrates; connection requires separate upgrade and fictional consent', () {
    for (var schema = 1; schema <= 7; schema++) {
      final data = LocalLedger.empty().data;
      data['schema'] = schema;
      for (final key in ['imports', 'reconciliations', 'categoryRules', 'importProfiles']) {
        data[key] = <Json>[];
      }
      final l = LocalLedger(data), original = jsonEncode(data), request = connectRequest(LocalLedger(data));
      expect(BankSync.inbox(l.snapshot()), isEmpty);
      expect(jsonEncode(l.data), original);
      for (final flag in ['confirmReviewed', 'confirmFictional', 'confirmBankUpgrade']) {
        expect(() => l.apply('bank-connect', {...request, flag: false}), throwsFormatException);
      }
      final upgraded = l.apply('bank-connect', request);
      expect(upgraded.data['schema'], 8);
      for (final key in [
        'categories',
        'transactions',
        'budgets',
        'schedules',
        'occurrences',
        'imports',
        'reconciliations',
        'categoryRules',
        'importProfiles',
      ]) {
        expect(upgraded.data[key], l.data[key], reason: '$schema/$key');
      }
      expect(upgraded.data['transactions'], isEmpty);
      expect(() => upgraded.apply('bank-connect', connectRequest(upgraded)), throwsFormatException);
    }
  });
  test('mapping preserves existing opening balances and rejects duplicate, type and currency mistakes', () {
    final l = LocalLedger.empty().apply('account', account('existing', 'Fictional existing checking', 11111));
    final existing = BankSync.list(l.data, 'accounts').single;
    final request = connectRequest(l);
    request['accounts'][0]['accountId'] = existing['id'];
    final mapped = l.apply('bank-connect', request);
    expect(BankSync.list(mapped.data, 'accounts').length, 3);
    expect(BankSync.list(mapped.data, 'accounts').first, existing);
    for (final variation in ['currency', 'type', 'duplicate']) {
      final bad = LocalLedger.clone(request);
      if (variation == 'currency') bad['accounts'][0]['currency'] = 'EUR';
      if (variation == 'type') bad['accounts'][0]['type'] = 'savings';
      if (variation == 'duplicate') bad['accounts'][1] = {...bad['accounts'][0], 'sourceAccountId': 'another'};
      expect(() => l.apply('bank-connect', bad), throwsFormatException);
    }
    final sameName = LocalLedger.empty().apply('account', account('name', 'fictional orchard checking', 0));
    expect(() => sameName.apply('bank-connect', connectRequest(sameName)), throwsFormatException);
  });
  test('no live provider can enroll and snapshots cannot modify bank records', () {
    final l = LocalLedger.empty();
    expect(() => l.apply('bank-connect', {...connectRequest(l), 'providerId': 'real-bank'}), throwsFormatException);
    final connected = bankFixture();
    final snapshot = connected.snapshot();
    snapshot['bankConnections'][0]['connected'] = false;
    expect(bankConnection(connected)['connected'], true);
  });
  test('fictional balances and source activity stage without posting or changing existing collections', () async {
    final l = bankFixture(), original = jsonEncode(l.data);
    final refreshed = l.apply('bank-refresh', await simulatedBatch(l));
    expect(jsonEncode(l.data), original);
    expect(refreshed.data['transactions'], isEmpty);
    expect(refreshed.snapshot()['accounts'], l.snapshot()['accounts']);
    expect(BankSync.list(refreshed.data, 'bankSources').length, 14);
    final link = BankSync.list(refreshed.data, 'bankAccounts').first;
    expect(link['availableBalanceMinor'], (link['reportedBalanceMinor'] as int) - 13400);
    expect(bankConnection(refreshed)['checkpoint'], '1');
    expect(bankConnection(refreshed)['lastSuccessUtc'], isNotNull);
    expect(BankSync.inbox(refreshed.data).any((r) => (r['reasons'] as List).contains('pending_ambiguity')), true);
  });
  test('identical operations, new-operation retries and reordered repeated pages are no-ops', () async {
    final start = bankFixture(), request = await simulatedBatch(bankFixture());
    // Build the request against the same connection/workspace.
    request.addAll(await simulatedBatch(start));
    final l = start.apply('bank-refresh', request);
    expect(identical(l.apply('bank-refresh', request), l), true);
    final retry = LocalLedger.clone(request);
    retry['operationId'] = 'retrieved-again';
    retry['batch']['records'] = (retry['batch']['records'] as List).reversed.toList();
    retry['batch']['balances'] = (retry['batch']['balances'] as List).reversed.toList();
    expect(identical(l.apply('bank-refresh', retry), l), true);
    retry['batch']['records'][0]['signedMinor'] = -1;
    expect(() => l.apply('bank-refresh', retry), throwsFormatException);
  });
  test('partial, invalid, stale and conflicting batches are atomic and do not consume checkpoints', () {
    final l = bankFixture(), before = jsonEncode(l.data);
    for (final variation in [
      'partial',
      'cursor',
      'stale',
      'currency',
      'amount',
      'date',
      'unknown',
      'identity',
      'oversized',
      'timestamp',
    ]) {
      final request = sourceBatch(l, [
        SimulatedBankProvider.record('one', -1, 'Fictional'),
        SimulatedBankProvider.record('two', -2, 'Fictional'),
      ]);
      final batch = request['batch'];
      if (variation == 'partial') batch['complete'] = false;
      if (variation == 'cursor') batch['fromCheckpoint'] = 'wrong';
      if (variation == 'stale') request['expectedRevision'] = 0;
      if (variation == 'currency') batch['records'][1]['currency'] = 'EUR';
      if (variation == 'amount') batch['records'][1]['signedMinor'] = -1.1;
      if (variation == 'date') batch['records'][1]['date'] = '2026-02-30';
      if (variation == 'unknown') batch['records'][1]['sourceAccountId'] = 'unknown';
      if (variation == 'identity') batch['records'][1]['sourceId'] = 'one';
      if (variation == 'oversized') batch['records'] = List.filled(2001, batch['records'][0]);
      if (variation == 'timestamp') batch['dataTimestampUtc'] = 'invalid';
      expect(() => l.apply('bank-refresh', request), throwsFormatException, reason: variation);
      expect(jsonEncode(l.data), before);
    }
  });
  test('pending replacements use explicit identities, preserve authorizations and post spending once', () async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    expect(() => recordSource(l, 'dining-auth'), throwsFormatException);
    l = l.apply('bank-refresh', await simulatedBatch(l));
    expect(bankSource(l, 'dining-auth')['supersededBy'], bankSource(l, 'dining-posted')['id']);
    expect(bankSource(l, 'fuel-auth')['supersededBy'], bankSource(l, 'fuel-posted')['id']);
    l = recordSource(l, 'dining-posted');
    l = recordSource(l, 'fuel-posted');
    expect(BudgetEngine.calculate(l.snapshot(), '2026-10').spent, 8232);
    expect(BankSync.list(l.data, 'transactions').length, 2);
    expect(() => recordSource(l, 'dining-posted'), throwsFormatException);
  });
  test('same-ID pending to posted works; late predecessors and out-of-order source revisions remain safe', () {
    var l = bankFixture();
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('same', -10000, 'Fictional', state: 'pending')]),
    );
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('same', -5432, 'Fictional', revision: 2)]),
    );
    l = recordSource(l, 'same');
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('same', -10000, 'Fictional', state: 'pending')]),
    );
    expect(bankSource(l, 'same')['signedMinor'], -5432);
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('later-posted', -2800, 'Fictional', pending: 'later-auth')]),
    );
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('later-auth', -2500, 'Fictional', state: 'pending')]),
    );
    expect(bankSource(l, 'later-auth')['supersededBy'], bankSource(l, 'later-posted')['id']);
    expect(
      () => l.apply(
        'bank-refresh',
        sourceBatch(l, [SimulatedBankProvider.record('same', -999, 'Fictional', revision: 2)]),
      ),
      throwsFormatException,
    );
  });
  test('ambiguous pending and legitimate identical rows require review, never guess a merge', () async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    expect(() => recordSource(l, 'ambiguous-posted'), throwsFormatException);
    l = recordSource(l, 'ambiguous-posted', {'confirmPending': true});
    expect(bankSource(l, 'ambiguous-auth')['supersededBy'], null);
    l = recordSource(l, 'identical-a');
    // A linked source's existing posting cannot be matched to a second source on that account.
    expect(BankSync.duplicateCandidates(l.data, bankSource(l, 'identical-b')), isEmpty);
    l = recordSource(l, 'identical-b');
    expect(BankSync.list(l.data, 'transactions').length, 3);
  });
  test('manual matching preserves categories, notes, amounts and identity without reposting', () {
    var l = bankFixture();
    final manual = {
      ...tx('manual', 'expense', bankAccount(l), bankCategory(l), 1200),
      'effectiveDate': '2026-10-02',
      'notes': 'My private note',
    };
    l = l.apply('transaction', manual);
    final original = BankSync.list(l.data, 'transactions').single;
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('merchant', -1200, 'Fictional')]));
    expect(() => recordSource(l, 'merchant'), throwsFormatException);
    l = l.apply(
      'bank-review',
      reviewRequest(l, 'merchant', 'match', {
        'transactionId': original['id'],
        'expectedTransactionVersion': original['version'],
      }),
    );
    expect(BankSync.list(l.data, 'transactions').single, original);
    expect(bankSource(l, 'merchant')['transactionId'], original['id']);
  });
  test('two sides of checking transfer and card payment create one transfer each and no spending', () async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    for (final pair in [('save-in', 'save-out'), ('card-out', 'card-in')]) {
      final other = bankSource(l, pair.$2);
      l = l.apply(
        'bank-review',
        reviewRequest(l, pair.$1, 'transfer', {
          'otherSourceId': other['id'],
          'expectedOtherSourceRevision': other['revision'],
        }),
      );
      expect(bankSource(l, pair.$1)['transactionId'], bankSource(l, pair.$2)['transactionId']);
    }
    expect(BankSync.list(l.data, 'transactions').length, 2);
    expect(BudgetEngine.calculate(l.snapshot(), '2026-10').spent, 0);
    expect(BankSync.list(l.snapshot(), 'accounts').map((a) => a['balanceMinor']).toList(), [225000, 120000, -5000]);
    expect(BankSync.list(l.snapshot(), 'accounts').fold<int>(0, (n, a) => n + (a['balanceMinor'] as int)), 340000);
  });
  test('one-sided transfer can link a later opposite source without duplicating payment', () {
    var l = bankFixture();
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('out', -5000, 'Fictional payment', transfer: 'pair')]),
    );
    l = l.apply('bank-review', reviewRequest(l, 'out', 'transfer', {'otherAccountId': bankAccount(l, 'orchard-card')}));
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [
        SimulatedBankProvider.record('in', 5000, 'Fictional payment', account: 'orchard-card', transfer: 'pair'),
      ]),
    );
    final t = BankSync.list(l.data, 'transactions').single;
    l = l.apply(
      'bank-review',
      reviewRequest(l, 'in', 'match', {'transactionId': t['id'], 'expectedTransactionVersion': t['version']}),
    );
    expect(BankSync.list(l.data, 'transactions'), [t]);
  });
  test('refresh corrections preserve manual edits until explicit review, then retain categories and notes', () async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    l = recordSource(l, 'merchant');
    final t = BankSync.list(l.data, 'transactions').single;
    final newCategory = BankSync.list(l.data, 'categories').where((c) => c['kind'] == 'Expense').last['id'];
    l = l.apply('transaction', {
      ...t,
      'operationId': 'edit',
      'expectedVersion': t['version'],
      'payee': 'My chosen name',
      'counterpartyAccountId': newCategory,
      'notes': 'My chosen note',
    });
    final userEntry = BankSync.list(l.data, 'transactions').single;
    l = l.apply('bank-refresh', await simulatedBatch(l));
    expect(BankSync.list(l.data, 'transactions').single, userEntry);
    l = l.apply('bank-refresh', await simulatedBatch(l));
    l = l.apply('bank-review', reviewRequest(l, 'merchant', 'correct'));
    final corrected = BankSync.list(l.data, 'transactions').single;
    expect(corrected['amountMinor'], 1350);
    for (final key in ['id', 'payee', 'notes', 'counterpartyAccountId', 'operationId', 'createdUtc']) {
      expect(corrected[key], userEntry[key]);
    }
  });
  test('removal and missing records are distinct; explicit void retains source identity', () async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    l = recordSource(l, 'removed');
    final first = BankSync.list(l.data, 'transactions').single;
    l = l.apply('bank-refresh', await simulatedBatch(l));
    expect(BankSync.list(l.data, 'transactions').single, first);
    expect(bankSource(l, 'rent')['state'], 'posted');
    expect(
      BankSync.inbox(l.data).firstWhere((r) => r['id'] == bankSource(l, 'removed')['id'])['reasons'],
      contains('bank_removal'),
    );
    l = l.apply('bank-review', reviewRequest(l, 'removed', 'remove'));
    expect(BankSync.list(l.data, 'transactions').single['voided'], true);
    expect(bankSource(l, 'removed')['transactionId'], first['id']);
    expect(l.snapshot()['transactions'], isEmpty);
  });
  test('reconciliation conflicts cannot apply a correction or removal; keep is auditable', () {
    var l = bankFixture();
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('merchant', -1200, 'Fictional')]));
    l = recordSource(l, 'merchant');
    l = l.apply('reconcile', statementRequest(l, accountId: bankAccount(l), closing: 248800));
    final t = BankSync.list(l.data, 'transactions').single;
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('merchant', -1350, 'Fictional', revision: 2)]),
    );
    expect(BankSync.inbox(l.data).single['reasons'], contains('reconciliation_conflict'));
    expect(() => l.apply('bank-review', reviewRequest(l, 'merchant', 'correct')), throwsFormatException);
    final preserved = l.apply(
      'bank-review',
      reviewRequest(l, 'merchant', 'keep', {'reason': 'Retain statement evidence'}),
    );
    expect(BankSync.list(preserved.data, 'transactions').single, t);
    expect(BankSync.inbox(preserved.data), isEmpty);
    l = l.apply('reconcile-reopen', reopenRequest(l, Reconciliation.active(l.data, bankAccount(l)).single));
    l = l.apply('bank-review', reviewRequest(l, 'merchant', 'correct'));
    expect(BankSync.list(l.data, 'transactions').single['amountMinor'], 1350);
  });
  test('split correction refuses implicit redistribution and keeps every user split intact', () {
    var l = bankFixture();
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('split', -1200, 'Fictional')]));
    l = recordSource(l, 'split');
    final t = BankSync.list(l.data, 'transactions').single;
    final categories = BankSync.list(l.data, 'categories').where((c) => c['kind'] == 'Expense').toList();
    l = l.apply('transaction', {
      ...t,
      'operationId': 'split-edit',
      'expectedVersion': t['version'],
      'splits': [
        {'categoryId': categories[0]['id'], 'amountMinor': 700},
        {'categoryId': categories[1]['id'], 'amountMinor': 500},
      ],
    });
    final original = BankSync.list(l.data, 'transactions').single;
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('split', -1350, 'Fictional', revision: 2)]),
    );
    expect(() => l.apply('bank-review', reviewRequest(l, 'split', 'correct')), throwsFormatException);
    expect(BankSync.list(l.data, 'transactions').single, original);
  });
  test('schedule suggestions never post; explicit matching settles one occurrence without reposting', () {
    var l = bankFixture();
    l = l.apply('schedule', {
      'operationId': 'schedule',
      'expectedVersion': 0,
      'name': 'Fictional rent',
      'kind': 'expense',
      'accountId': bankAccount(l),
      'counterpartyAccountId': bankCategory(l),
      'currency': 'USD',
      'amountMinor': 90000,
      'payee': 'Fictional rent',
      'notes': '',
      'startDate': '2026-10-02',
      'frequency': 'monthly',
      'endDate': null,
    });
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('rent', -90000, 'Fictional rent')]));
    expect(BankSync.inbox(l.data).single['reasons'], contains('scheduled_match'));
    expect(l.data['occurrences'], isEmpty);
    l = recordSource(l, 'rent');
    final t = BankSync.list(l.data, 'transactions').single;
    final candidate = BankSync.scheduleCandidates(l.data, bankSource(l, 'rent')).single;
    l = l.apply('bank-review', reviewRequest(l, 'rent', 'schedule', candidate));
    expect(BankSync.list(l.data, 'transactions').length, 1);
    expect(BankSync.list(l.data, 'occurrences').single['transactionId'], t['id']);
    expect(BankSync.list(l.data, 'transactions').single['postings'], t['postings']);
    expect(BankSync.inbox(l.data), isEmpty);
  });
  test('failed status and disconnect preserve history; retries clear the one connection inbox item', () async {
    var l = bankFixture();
    final request = await simulatedBatch(l);
    l = l.apply('bank-refresh', request);
    final sources = l.data['bankSources'];
    final checkpoint = bankConnection(l)['checkpoint'];
    l = l.apply('bank-failure', {
      'operationId': 'failure',
      'expectedRevision': l.revision,
      'connectionId': bankConnection(l)['id'],
      'atUtc': '2026-10-29T12:01:00.000Z',
      'errorCode': 'interrupted',
    });
    expect(l.data['bankSources'], sources);
    expect(bankConnection(l)['checkpoint'], checkpoint);
    expect(BankSync.inbox(l.data).where((i) => i['source'] == null).length, 1);
    l = l.apply('bank-refresh', {...request, 'operationId': 'retry', 'expectedRevision': l.revision});
    expect(bankConnection(l)['refreshStatus'], 'success');
    expect(BankSync.inbox(l.data).where((i) => i['source'] == null), isEmpty);
    l = l.apply('bank-state', {
      'operationId': 'disconnect',
      'expectedRevision': l.revision,
      'connectionId': bankConnection(l)['id'],
      'connected': false,
      'confirmReviewed': true,
    });
    expect(l.data['bankSources'], sources);
    expect(bankConnection(l)['checkpoint'], checkpoint);
    expect(() => l.apply('bank-refresh', {...request, 'operationId': 'blocked'}), throwsFormatException);
  });
  test('stale review and changed operation ID contents reject without modifying any data', () {
    var l = bankFixture();
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('one', -1200, 'Fictional')]));
    final request = reviewRequest(l, 'one', 'record', {'categoryId': bankCategory(l)});
    for (final field in ['expectedRevision', 'expectedSourceRevision']) {
      expect(() => l.apply('bank-review', {...request, field: 0}), throwsFormatException);
    }
    final saved = l.apply('bank-review', request);
    expect(identical(saved.apply('bank-review', request), saved), true);
    expect(() => saved.apply('bank-review', {...request, 'notes': 'Changed'}), throwsFormatException);
  });
  test('restore validation rejects corrupt identities, relationships, currencies and checkpoints', () {
    var l = bankFixture();
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('one', -1200, 'Fictional')]));
    l = recordSource(l, 'one');
    for (final variation in [
      'source',
      'link',
      'transaction',
      'revision',
      'checkpoint',
      'batch',
      'currency',
      'duplicate',
      'pending',
      'missing',
    ]) {
      final d = LocalLedger.clone(l.data);
      if (variation == 'source') d['bankSources'][0]['sourceId'] = 'wrong';
      if (variation == 'link') d['bankAccounts'][0]['accountId'] = 'missing';
      if (variation == 'transaction') d['bankSources'][0]['transactionId'] = 'missing';
      if (variation == 'revision') d['bankSources'][0]['reviewedRevision'] = 100;
      if (variation == 'checkpoint') d['bankConnections'][0]['checkpoint'] = 'wrong';
      if (variation == 'batch') d['bankBatches'][0]['operationId'] = 'missing';
      if (variation == 'currency') d['bankSources'][0]['currency'] = 'EUR';
      if (variation == 'duplicate') d['bankSources'].add(LocalLedger.clone(d['bankSources'][0]));
      if (variation == 'pending') d['bankSources'][0]['supersededBy'] = 'missing';
      if (variation == 'missing') d.remove('bankSources');
      expect(() => LocalLedger(d), throwsFormatException, reason: variation);
    }
  });
}
