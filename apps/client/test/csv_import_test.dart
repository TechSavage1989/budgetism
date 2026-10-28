import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/csv_import.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/budgets.dart';
import 'local_ledger_test.dart' show account, category, accounts, tx;

Json importRow({int number = 2, int signed = -2000, String payee = 'Fictional shop', String reference = ''}) => {
  'rowNumber': number, 'date': '2026-10-27', 'signedMinor': signed, 'payee': payee, 'reference': reference, 'notes': ''};
Json importBatch(LocalLedger ledger, List<Json> rows, {String operation = 'import-test', String? accountId,
    bool upgrade = true, String? hash}) => {'operationId': operation, 'expectedRevision': ledger.revision,
  'accountId': accountId ?? accounts(ledger).first['id'], 'fileHash': hash ?? List.filled(64, 'a').join(),
  'fileName': 'fictional.csv', 'confirmImportUpgrade': upgrade, 'rows': rows};
Json createRow(LocalLedger ledger, {int number = 2, int signed = -2000, String reference = '', bool allow = false}) =>
  {...importRow(number: number, signed: signed, reference: reference), 'action': 'create',
    'kind': signed < 0 ? 'expense' : 'income', 'targetId': category(ledger, signed < 0 ? 'Expense' : 'Income'), 'allowDuplicate': allow};

void main() {
  test('CSV quotes, escaped quotes, multiline, CRLF, BOM, delimiters and literal formulas', () {
    final table = CsvTable.parse('\uFEFFDate,Description,Amount\r\n2026-10-27,"Shop, ""One""\nNorth",-12.34\r\n2026-10-28,=not_executed,1.00\r\n');
    expect(table.records.length, 2); expect(table.records.first[1], 'Shop, "One"\nNorth');
    final rows = CsvImport.preview(table, const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2));
    expect(rows[0].values!['payee'], 'Shop, "One" North'); expect(rows[0].values!['signedMinor'], -1234);
    expect(rows[1].values!['payee'], '=not_executed');
    expect(CsvTable.parse('Date;Description;Amount\n2026-10-27;Test;1.00', delimiter: ';').records.length, 1);
    expect(CsvTable.parse('Date\tDescription\tAmount\n2026-10-27\tTest\t1.00', delimiter: '\t').records.length, 1);
  });
  test('malformed CSV, invalid UTF8, long fields and oversized files fail without guessing', () {
    for (final input in ['A,B,C\n1,"unclosed,2', 'A,B,C\n1,"closed"tail,2', 'A,B,C\n1,te"xt,2', 'A,,C\n1,2,3', 'binary\u0000']) {
      expect(() => CsvTable.parse(input), throwsFormatException);
    }
    expect(() => utf8.decode([0xff, 0xfe]), throwsFormatException);
    expect(() => CsvTable.parse('A,B,C\n1,${List.filled(4097, 'x').join()},2'), throwsFormatException);
    expect(() => CsvTable.parse('A,B,C\n${List.filled(1001, '1,2,3\n').join()}'), throwsFormatException);
    expect(() => CsvTable.parse(List.filled(CsvTable.maxBytes + 1, 'a').join()), throwsFormatException);
  });
  test('money parser keeps exact cents, rejects fractional cents, ambiguous grouping and exponents', () {
    expect(CsvImport.amount('0.10'), 10); expect(CsvImport.amount('-\$1,234.56'), -123456);
    expect(CsvImport.amount('(200.10)'), -20010); expect(CsvImport.amount('+1.2'), 120);
    expect(CsvImport.amount('', emptyIsZero: true), 0);
    for (final input in ['1.001', 'NaN', '1e3', '1,00', '1.234,00', '--1', '(-1)', '999999999999999.99', '']) {
      expect(() => CsvImport.amount(input), throwsFormatException);
    }
    expect(CsvImport.date('03/04/2026', 'mdy'), '2026-03-04');
    expect(CsvImport.date('03/04/2026', 'dmy'), '2026-04-03');
    expect(() => CsvImport.date('2026-02-29', 'ymd'), throwsFormatException);
    expect(CsvImport.date('2028-02-29', 'ymd'), '2028-02-29');
    expect(() => CsvImport.date('03/04/26', 'mdy'), throwsFormatException);
  });
  test('row errors are visible; separate debit/credit and reversed signs are explicit', () {
    final rows = CsvImport.preview(CsvTable.parse('Date,Payee,Debit,Credit\n10/27/2026,Test,10.01,\n10/28/2026,Test,,20\n10/29/2026,Test,1,1\n10/30/2026,Test,0,0\n10/31/2026,Test,1'),
      const CsvMapping(dateColumn: 0, payeeColumn: 1, debitColumn: 2, creditColumn: 3, dateFormat: 'mdy'));
    expect(rows.map((r) => r.values?['signedMinor']), [-1001, 2000, null, null, null]);
    expect(rows.skip(2).every((r) => r.error != null), isTrue);
    final reversed = CsvImport.preview(CsvTable.parse('Date,Payee,Amount\n2026-10-27,Test,10.01'),
      const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2, reverseSign: true));
    expect(reversed.single.values!['signedMinor'], -1001);
    expect(() => CsvImport.preview(CsvTable.parse('A,B,C\n1,2,3'),
      const CsvMapping(dateColumn: 0, payeeColumn: 0, amountColumn: 2)), throwsFormatException);
  });

  late LocalLedger ledger;
  setUp(() { ledger = LocalLedger.empty().apply('account', account('checking', 'Fictional checking', 100000)); });
  test('preview does not write; explicit import upgrade preserves records and affects actual budget once', () {
    final before = jsonEncode(ledger.data);
    CsvImport.preview(CsvTable.parse('Date,Payee,Amount\n2026-10-27,Test,-20'),
      const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2));
    expect(jsonEncode(ledger.data), before);
    final rows = [createRow(ledger, signed: 50000), createRow(ledger, number: 3, signed: -20000)];
    expect(() => ledger.apply('import-csv', importBatch(ledger, rows, upgrade: false)), throwsFormatException);
    final request = importBatch(ledger, rows);
    final updated = ledger.apply('import-csv', request);
    expect(updated.data['schema'], LocalLedger.importSchema); expect(accounts(updated).single['balanceMinor'], 130000);
    expect(updated.data['categories'], ledger.data['categories']); expect(updated.data['budgets'], ledger.data['budgets']);
    expect(updated.data['schedules'], ledger.data['schedules']); expect(updated.data['imports'].length, 2);
    expect(BudgetEngine.calculate(updated.snapshot(), '2026-10').spent, 20000);
    expect(identical(updated.apply('import-csv', request), updated), isTrue);
    expect(jsonEncode(ledger.data), before);
  });
  test('same file and optional bank ID stay deduplicated across edits, voids, mapping changes and filenames', () {
    final row = createRow(ledger, reference: 'bank-unique-1');
    ledger = ledger.apply('import-csv', importBatch(ledger, [row]));
    final original = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('void', {'operationId': 'void', 'id': original['id'], 'expectedVersion': 1});
    final before = jsonEncode(ledger.data);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [row], operation: 'repeat')), throwsFormatException);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [{...row, 'signedMinor': -3000, 'allowDuplicate': true}], operation: 'remapped')), throwsFormatException);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [row], operation: 'reference-repeat', hash: List.filled(64, 'b').join())), throwsFormatException);
    expect(CsvImport.consumed(ledger.snapshot(), accounts(ledger).first['id'], List.filled(64, 'a').join(), row), isTrue);
    expect(jsonEncode(ledger.data), before);
  });
  test('same-date/amount manual entry can be matched without posting again; duplicates need explicit review', () {
    ledger = ledger.apply('transaction', tx('manual', 'expense', accounts(ledger).first['id'], category(ledger, 'Expense'), 2000));
    final id = LocalLedger.rows(ledger.data['transactions']).single['id'];
    final row = createRow(ledger);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [row])), throwsFormatException);
    final matched = ledger.apply('import-csv', importBatch(ledger, [{...row, 'action': 'match', 'transactionId': id}]));
    expect(matched.data['transactions'], ledger.data['transactions']); expect(accounts(matched).first['balanceMinor'], 98000);
    expect(matched.data['imports'].single['action'], 'match');
    final separate = ledger.apply('import-csv', importBatch(ledger, [{...row, 'allowDuplicate': true}]));
    expect(accounts(separate).first['balanceMinor'], 96000);
  });
  test('identical valid statement rows are not silently collapsed; second needs duplicate consent', () {
    final first = createRow(ledger), second = createRow(ledger, number: 3);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [first, second])), throwsFormatException);
    ledger = ledger.apply('import-csv', importBatch(ledger, [first, {...second, 'allowDuplicate': true}]));
    expect(ledger.data['transactions'].length, 2); expect(accounts(ledger).first['balanceMinor'], 96000);
  });
  test('transfer imports balance both accounts; the other account statement matches instead of spending twice', () {
    ledger = ledger.apply('account', account('card', 'Fictional credit card', -2000, type: 'credit_card'));
    final a = accounts(ledger), checking = a.first['id'] as String, card = a.last['id'] as String;
    final row = {...createRow(ledger), 'kind': 'transfer', 'targetId': card};
    ledger = ledger.apply('import-csv', importBatch(ledger, [row]));
    expect(accounts(ledger).map((a) => a['balanceMinor']), [98000, 0]);
    expect(BudgetEngine.calculate(ledger.snapshot(), '2026-10').spent, 0);
    final existing = LocalLedger.rows(ledger.data['transactions']).single;
    final credit = {...importRow(signed: 2000), 'action': 'match', 'transactionId': existing['id']};
    ledger = ledger.apply('import-csv', importBatch(ledger, [credit], operation: 'card-import', accountId: card));
    expect(ledger.data['transactions'].length, 1); expect(ledger.data['imports'].length, 2);
    expect(CsvImport.effect(existing, checking), -2000);
  });
  test('positive transfer import uses the chosen source and preserves worth', () {
    ledger = ledger.apply('account', account('saving', 'Fictional saving', 0));
    final to = accounts(ledger).last['id'] as String, from = accounts(ledger).first['id'];
    ledger = ledger.apply('import-csv', importBatch(ledger, [{...createRow(ledger, signed: 2000), 'kind': 'transfer', 'targetId': from}], accountId: to));
    expect(accounts(ledger).map((a) => a['balanceMinor']), [98000, 2000]);
  });
  test('stale revision, invalid rows, wrong matching and reused matches reject the whole batch', () {
    final before = jsonEncode(ledger.data), good = createRow(ledger);
    expect(() => ledger.apply('import-csv', {...importBatch(ledger, [good]), 'expectedRevision': -1}), throwsFormatException);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [good, {...good, 'rowNumber': 3, 'date': 'bad'}])), throwsFormatException);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [{...good, 'action': 'match', 'transactionId': 'missing'}])), throwsFormatException);
    expect(jsonEncode(ledger.data), before);
    ledger = ledger.apply('transaction', tx('manual', 'expense', accounts(ledger).first['id'], category(ledger, 'Expense'), 2000));
    final id = LocalLedger.rows(ledger.data['transactions']).single['id'];
    expect(() => ledger.apply('import-csv', importBatch(ledger, [
      {...good, 'action': 'match', 'transactionId': id}, {...good, 'rowNumber': 3, 'action': 'match', 'transactionId': id}])), throwsFormatException);
  });
  test('receipt corruption is rejected and scheduled operations remain available after importing', () {
    ledger = ledger.apply('import-csv', importBatch(ledger, [createRow(ledger)]));
    final corrupted = LocalLedger.clone(ledger.data); corrupted['imports'][0]['transactionId'] = 'missing';
    expect(() => LocalLedger(corrupted), throwsFormatException);
    final duplicate = LocalLedger.clone(ledger.data); duplicate['imports'].add(LocalLedger.clone(duplicate['imports'][0]));
    expect(() => LocalLedger(duplicate), throwsFormatException);
    ledger = ledger.apply('schedule', {'operationId': 'schedule-after-import', 'expectedVersion': 0, 'name': 'Fictional future bill',
      'kind': 'expense', 'accountId': accounts(ledger).first['id'], 'counterpartyAccountId': category(ledger, 'Expense'),
      'currency': 'USD', 'amountMinor': 1000, 'payee': 'Test', 'notes': '', 'startDate': '2026-10-28', 'frequency': 'monthly', 'endDate': null});
    expect(ledger.data['schema'], LocalLedger.importSchema); expect(ledger.data['imports'].length, 1); expect(ledger.data['schedules'].length, 1);
  });
}
