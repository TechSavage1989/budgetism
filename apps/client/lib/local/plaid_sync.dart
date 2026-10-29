import 'dart:convert';

typedef PlaidJson = Map<String, dynamic>;
typedef PlaidPageReader = Future<PlaidJson> Function(String cursor);

/// A sanitized provider error. Never include response bodies or credentials.
class PlaidSyncException implements Exception {
  const PlaidSyncException(this.code);
  final String code;
  @override
  String toString() => 'Plaid synchronization could not finish ($code).';
}

/// Detached transport result. Nothing is persisted until the caller commits
/// every change and the final cursor in one workspace transaction.
class PlaidDelta {
  PlaidDelta(this.fromCursor, this.cursor, List<PlaidJson> changes)
    : _encoded = jsonEncode(changes);
  final String fromCursor, cursor, _encoded;
  List<PlaidJson> get changes =>
      (jsonDecode(_encoded) as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
}

class PlaidSyncCollector {
  PlaidSyncCollector(
    this.readPage, {
    this.maxPages = 100,
    this.maxChanges = 50000,
  });
  final PlaidPageReader readPage;
  final int maxPages, maxChanges;
  bool _busy = false;

  Future<PlaidDelta> collect(String savedCursor) async {
    if (_busy) throw const PlaidSyncException('already-running');
    if (maxPages < 1 || maxChanges < 1 || savedCursor.length > 4096) {
      throw const PlaidSyncException('invalid-request');
    }
    _busy = true;
    try {
      // Plaid requires restarting the WHOLE pagination cycle after a mutation.
      // Limit restarts so an unstable upstream cannot run indefinitely.
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          return await _collect(savedCursor);
        } on PlaidSyncException catch (error) {
          if (error.code != 'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION' ||
              attempt == 2) {
            rethrow;
          }
        }
      }
      throw const PlaidSyncException('retry-limit');
    } finally {
      _busy = false;
    }
  }

  Future<PlaidDelta> _collect(String start) async {
    var cursor = start;
    final seen = <String>{start};
    final changes = <PlaidJson>[];
    for (var pageNumber = 0; pageNumber < maxPages; pageNumber++) {
      final page = await readPage(cursor);
      if (page['has_more'] is! bool ||
          page['next_cursor'] is! String ||
          (page['next_cursor'] as String).length > 4096) {
        throw const PlaidSyncException('invalid-page');
      }
      for (final kind in ['added', 'modified', 'removed']) {
        final rows = page[kind];
        if (rows is! List || rows.any((r) => r is! Map)) {
          throw const PlaidSyncException('invalid-page');
        }
        for (final row in rows) {
          final value = Map<String, dynamic>.from(row as Map);
          _identifier(value['transaction_id']);
          _identifier(value['account_id']);
          changes.add({'kind': kind, 'value': value});
          if (changes.length > maxChanges) {
            throw const PlaidSyncException('batch-limit');
          }
        }
      }
      final next = page['next_cursor'] as String;
      if (next.isEmpty &&
          (start.isNotEmpty ||
              changes.isNotEmpty ||
              page['has_more'] == true)) {
        throw const PlaidSyncException('invalid-cursor');
      }
      if (page['has_more'] == false) {
        return PlaidDelta(start, next, changes);
      }
      if (!seen.add(next)) throw const PlaidSyncException('cursor-cycle');
      cursor = next;
    }
    throw const PlaidSyncException('page-limit');
  }

  static void _identifier(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 256) {
      throw const PlaidSyncException('invalid-identity');
    }
  }
}

/// Convert a decimal representation without multiplying a binary float.
/// Callers handling raw JSON should preserve monetary number lexemes as text.
/// USD only; reject fractional cents and values outside the ledger's range.
int plaidUsdMinor(String decimal, {bool transaction = false}) {
  final match = RegExp(
    r'^(-?)([0-9]{1,12})(?:\.([0-9]{1,2}))?$',
  ).firstMatch(decimal);
  if (match == null) throw const PlaidSyncException('invalid-usd-amount');
  final magnitude =
      int.parse(match[2]!) * 100 + int.parse((match[3] ?? '').padRight(2, '0'));
  if (magnitude > 99999999999999) {
    throw const PlaidSyncException('amount-limit');
  }
  final signed = match[1] == '-' ? -magnitude : magnitude;
  // Plaid transaction amounts are positive for outflows; ledger effects are negative.
  return transaction ? -signed : signed;
}
