part of 'ledger.dart';

/// Receipts and all selected transactions are one validated ledger mutation.
class _ImportRules {
  static bool _digest(Object? value) => value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
  static int _effect(Json t, String account) => t['voided'] == true ? 0 :
    LocalLedger.rows(t['postings']).where((p) => p['ledgerId'] == account)
      .fold<int>(0, (sum, p) => sum + (p['amountMinor'] as int));
  static Json apply(Json next, Json input, String operation, List<Json> accounts,
      List<Json> categories, List<Json> transactions) {
    if (input['expectedRevision'] != next['revision']) LocalLedger.fail('Workspace changed. Reopen the import and review it again.');
    final accountId = LocalLedger.text(input['accountId'], 'Import account', 100);
    if (!accounts.any((a) => a['id'] == accountId)) LocalLedger.fail('Choose an existing import account.');
    final hash = input['fileHash'];
    if (!_digest(hash)) LocalLedger.fail('Invalid CSV identity.');
    final label = LocalLedger.text(input['fileName'], 'CSV filename', 200);
    if (label.contains('/') || label.contains('\\')) LocalLedger.fail('Use a filename, not a full file path.');
    if (input['rows'] is! List || (input['rows'] as List).isEmpty || (input['rows'] as List).length > 500) {
      LocalLedger.fail('Select between 1 and 500 rows for this import.');
    }
    if (next['schema'] != LocalLedger.importSchema) {
      if (input['confirmImportUpgrade'] != true) LocalLedger.fail('Export a backup and confirm the import-history format upgrade first.');
      next.addAll({'schema': LocalLedger.importSchema, 'budgets': next['budgets'] ?? <Json>[],
        'schedules': next['schedules'] ?? <Json>[], 'occurrences': next['occurrences'] ?? <Json>[], 'imports': <Json>[]});
    }
    final receipts = LocalLedger.rows(next['imports']);
    final newReceipts = <Json>[];
    final matchedThisBatch = <String>{};
    for (final row in LocalLedger.rows(input['rows'])) {
      final number = row['rowNumber'];
      if (number is! int || number < 2 || number > 1001) LocalLedger.fail('Invalid CSV record number.');
      LocalLedger.date(row['date']);
      final signed = LocalLedger.minor(row['signedMinor'], signed: true);
      if (signed == 0) LocalLedger.fail('Cannot import a zero-amount transaction.');
      final payee = LocalLedger.text(row['payee'], 'Description', 150);
      final reference = LocalLedger.text(row['reference'], 'Unique bank ID', 100, optional: true);
      final notes = LocalLedger.text(row['notes'], 'Notes', 500, optional: true);
      if ([...receipts, ...newReceipts].any((r) => r['accountId'] == accountId &&
          ((r['fileHash'] == hash && r['rowNumber'] == number) || (reference.isNotEmpty && r['reference'] == reference)))) {
        LocalLedger.fail('CSV row $number was already handled. Regenerate the preview.');
      }
      String transactionId;
      if (row['action'] == 'match') {
        final matches = transactions.where((t) => t['id'] == row['transactionId']).toList();
        if (matches.length != 1 || matches.single['voided'] == true ||
            matches.single['effectiveDate'] != row['date'] || _effect(matches.single, accountId) != signed ||
            !matchedThisBatch.add(matches.single['id'] as String)) {
          LocalLedger.fail('Choose a different existing transaction with the same account, date and signed amount.');
        }
        transactionId = matches.single['id'] as String;
      } else if (row['action'] == 'create') {
        final possible = transactions.any((t) => t['voided'] != true &&
          t['effectiveDate'] == row['date'] && _effect(t, accountId) == signed);
        final historical = receipts.any((r) => r['accountId'] == accountId && r['date'] == row['date'] &&
          r['signedMinor'] == signed && (r['payee'] as String).toLowerCase() == payee.toLowerCase());
        if ((possible || historical) && row['allowDuplicate'] != true) {
          LocalLedger.fail('CSV row $number may duplicate an existing or previously imported transaction. Review it explicitly.');
        }
        final kind = row['kind'];
        if (kind != 'transfer' && kind != (signed < 0 ? 'expense' : 'income')) LocalLedger.fail('Transaction type must agree with the signed account amount.');
        final target = row['targetId'];
        final tx = <String, dynamic>{'id': const Uuid().v4(), 'operationId': operation,
          'kind': kind, 'accountId': kind == 'transfer' && signed > 0 ? target : accountId,
          'counterpartyAccountId': kind == 'transfer' && signed > 0 ? accountId : target,
          'amountMinor': signed.abs(), 'currency': 'USD', 'effectiveDate': row['date'],
          'payee': payee, 'notes': notes, 'splits': <Json>[], 'voided': false, 'version': 1,
          'createdUtc': DateTime.now().toUtc().toIso8601String()};
        tx['postings'] = LocalLedger.postingsFor(tx, accounts, categories);
        if (_effect(tx, accountId) != signed) LocalLedger.fail('Imported account effect does not match the statement.');
        transactions.add(tx); transactionId = tx['id'] as String;
      } else { LocalLedger.fail('Choose Import or Match for every included row.'); }
      newReceipts.add({'id': const Uuid().v4(), 'batchId': operation, 'fileHash': hash, 'fileName': label,
        'accountId': accountId, 'rowNumber': number, 'date': row['date'], 'signedMinor': signed,
        'payee': payee, 'reference': reference, 'transactionId': transactionId, 'action': row['action'],
        'atUtc': DateTime.now().toUtc().toIso8601String()});
    }
    if (receipts.length + newReceipts.length > 20000) LocalLedger.fail('This preview supports up to 20,000 imported row receipts.');
    next['imports'] = [...receipts, ...newReceipts];
    return {'fileName': label, 'accountId': accountId, 'receipts': newReceipts};
  }
  static void validate(Json data, List<Json> accounts, List<Json> transactions, Set<String> ids) {
    if (data['schema'] != LocalLedger.importSchema) {
      if (data.containsKey('imports') && (data['imports'] is! List || (data['imports'] as List).isNotEmpty)) {
        LocalLedger.fail('Import receipts require the upgraded workspace schema.');
      }
      return;
    }
    if (data['imports'] is! List || (data['imports'] as List).length > 20000) LocalLedger.fail('Invalid import history.');
    final rows = <String>{}; final references = <String>{};
    final accountIds = accounts.map((a) => a['id']).toSet();
    final txIds = transactions.map((t) => t['id']).toSet();
    for (final r in LocalLedger.rows(data['imports'])) {
      if (!ids.add(LocalLedger.text(r['id'], 'Import receipt identifier', 100))) LocalLedger.fail('Duplicate import receipt identifier.');
      LocalLedger.text(r['batchId'], 'Import batch', 100);
      LocalLedger.text(r['fileName'], 'CSV filename', 200);
      LocalLedger.text(r['payee'], 'Description', 150);
      final reference = LocalLedger.text(r['reference'], 'Unique bank ID', 100, optional: true);
      LocalLedger.date(r['date']);
      if (!_digest(r['fileHash']) || !accountIds.contains(r['accountId']) || !txIds.contains(r['transactionId']) ||
          r['rowNumber'] is! int || r['rowNumber'] < 2 || r['rowNumber'] > 1001 ||
          LocalLedger.minor(r['signedMinor'], signed: true) == 0 || !['create', 'match'].contains(r['action']) ||
          r['atUtc'] is! String || DateTime.tryParse(r['atUtc'] as String) == null ||
          !(data['operations'] as Map).containsKey(r['batchId']) ||
          !rows.add('${r['accountId']}|${r['fileHash']}|${r['rowNumber']}') ||
          (reference.isNotEmpty && !references.add('${r['accountId']}|$reference'))) {
        LocalLedger.fail('Invalid, duplicated or orphaned import receipt.');
      }
      // The receipt describes the original source. Edits/voids must not change
      // that identity or permit accidentally re-importing the original row.
    }
  }
}
