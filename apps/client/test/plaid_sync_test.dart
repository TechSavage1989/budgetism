import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/plaid_sync.dart';

Map<String, dynamic> page(String cursor, {bool more = false, String? id}) => {
  'next_cursor': cursor,
  'has_more': more,
  'added': [
    if (id != null) {'transaction_id': id, 'account_id': 'fictional-account'},
  ],
  'modified': [],
  'removed': [],
};

void main() {
  test(
    'complete pages produce detached changes and one final cursor',
    () async {
      final calls = <String>[];
      final collector = PlaidSyncCollector((cursor) async {
        calls.add(cursor);
        return cursor == 'saved'
            ? page('page-2', more: true, id: 'a')
            : page('final', id: 'b');
      });
      final result = await collector.collect('saved');
      expect(calls, ['saved', 'page-2']);
      expect(result.fromCursor, 'saved');
      expect(result.cursor, 'final');
      expect(result.changes.length, 2);
      result.changes.first['value']['transaction_id'] = 'changed';
      expect(result.changes.first['value']['transaction_id'], 'a');
    },
  );
  test(
    'pagination mutation discards partial data and restarts from saved cursor',
    () async {
      final calls = <String>[];
      final collector = PlaidSyncCollector((cursor) async {
        calls.add(cursor);
        if (calls.length == 1) {
          return page('partial', more: true, id: 'discard');
        }
        if (calls.length == 2) {
          throw const PlaidSyncException(
            'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION',
          );
        }
        return page('complete', id: 'retained');
      });
      final result = await collector.collect('original');
      expect(calls, ['original', 'partial', 'original']);
      expect(result.changes.single['value']['transaction_id'], 'retained');
    },
  );
  test('mutation retries are bounded', () async {
    var calls = 0;
    final collector = PlaidSyncCollector((_) async {
      calls++;
      throw const PlaidSyncException(
        'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION',
      );
    });
    await expectLater(
      collector.collect(''),
      throwsA(isA<PlaidSyncException>()),
    );
    expect(calls, 3);
  });
  test('initial not-ready response retains empty checkpoint', () async {
    final result = await PlaidSyncCollector((_) async => page('')).collect('');
    expect(result.cursor, '');
    expect(result.changes, isEmpty);
  });
  test(
    'partial failures return no result; next attempt uses original cursor',
    () async {
      final calls = <String>[];
      var failing = true;
      final collector = PlaidSyncCollector((cursor) async {
        calls.add(cursor);
        if (cursor == 'start') return page('next', more: true, id: 'a');
        if (failing) throw const PlaidSyncException('unavailable');
        return page('done');
      });
      await expectLater(
        collector.collect('start'),
        throwsA(isA<PlaidSyncException>()),
      );
      failing = false;
      expect((await collector.collect('start')).changes.length, 1);
      expect(calls, ['start', 'next', 'start', 'next']);
    },
  );
  test(
    'rejects cycles, page limits, batch limits and malformed data',
    () async {
      final collectors = [
        PlaidSyncCollector((_) async => page('same', more: true)),
        PlaidSyncCollector((_) async => page('next', more: true), maxPages: 1),
        PlaidSyncCollector(
          (c) async => page(c == '' ? 'n' : 'done', more: c == '', id: 'a'),
          maxChanges: 1,
        ),
        PlaidSyncCollector((_) async => {...page('done'), 'added': 'bad'}),
        PlaidSyncCollector((_) async => page('done', id: '')),
        PlaidSyncCollector((_) async => page('', id: 'a')),
      ];
      for (final collector in collectors) {
        await expectLater(
          collector.collect(''),
          throwsA(isA<PlaidSyncException>()),
        );
      }
    },
  );
  test('single flight rejects overlapping collection', () async {
    final gate = Completer<Map<String, dynamic>>();
    final collector = PlaidSyncCollector((_) => gate.future);
    final pending = collector.collect('');
    await expectLater(
      collector.collect(''),
      throwsA(isA<PlaidSyncException>()),
    );
    gate.complete(page('done'));
    await pending;
  });
  test('exact cents and Plaid transaction sign convention', () {
    expect(plaidUsdMinor('54.32', transaction: true), -5432);
    expect(plaidUsdMinor('-25.10', transaction: true), 2510);
    expect(plaidUsdMinor('0.29'), 29);
    expect(plaidUsdMinor('999999999999.99'), 99999999999999);
    expect(plaidUsdMinor('-0.00'), 0);
    for (final invalid in [
      '1.001',
      'NaN',
      'Infinity',
      '1e2',
      ' 1',
      '1000000000000',
      '.1',
    ]) {
      expect(() => plaidUsdMinor(invalid), throwsA(isA<PlaidSyncException>()));
    }
  });
}
