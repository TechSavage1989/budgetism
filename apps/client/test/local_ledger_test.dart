import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';

Json account(String op, String name, int balance, {String type = 'checking'}) => {
  'operationId': op, 'name': name, 'type': type, 'currency': 'USD', 'openingBalanceMinor': balance};
Json tx(String op, String kind, String from, String to, int amount) => {
  'operationId': op, 'kind': kind, 'accountId': from, 'counterpartyAccountId': to,
  'amountMinor': amount, 'currency': 'USD', 'effectiveDate': '2026-10-27', 'payee': 'Test payee', 'notes': ''};
String category(LocalLedger l, String kind) => LocalLedger.rows(l.data['categories']).firstWhere((c) => c['kind'] == kind)['id'] as String;
List<Json> accounts(LocalLedger l) => LocalLedger.rows(l.snapshot()['accounts']);

void main() {
  late LocalLedger ledger;
  setUp(() {
    ledger = LocalLedger.empty().apply('account', account('a1', 'Checking', 100000))
      .apply('account', account('a2', 'Card', -5000, type: 'credit_card'));
  });
  test('card purchase and payment count expense once; transfer conserves worth', () {
    final a = accounts(ledger);
    ledger = ledger.apply('transaction', tx('t1', 'expense', a[1]['id'], category(ledger, 'Expense'), 10000));
    final beforeWorth = accounts(ledger).fold<int>(0, (s, a) => s + (a['balanceMinor'] as int));
    ledger = ledger.apply('transaction', tx('t2', 'transfer', a[0]['id'], a[1]['id'], 10000));
    expect(accounts(ledger)[0]['balanceMinor'], 90000);
    expect(accounts(ledger)[1]['balanceMinor'], -5000);
    expect(accounts(ledger).fold<int>(0, (s, a) => s + (a['balanceMinor'] as int)), beforeWorth);
    final expenses = LocalLedger.rows(ledger.snapshot()['transactions']).where((t) => t['kind'] == 'expense');
    expect(expenses.fold<int>(0, (s, t) => s + (t['amountMinor'] as int)), 10000);
  });
  test('income, expense and opening values stay exact in minor units', () {
    final id = accounts(ledger)[0]['id'] as String;
    ledger = ledger.apply('transaction', tx('income', 'income', id, category(ledger, 'Income'), 10));
    ledger = ledger.apply('transaction', tx('expense', 'expense', id, category(ledger, 'Expense'), 3));
    expect(accounts(ledger)[0]['balanceMinor'], 100007);
  });
  test('editing a transaction replaces postings; void removes its balance effect', () {
    final id = accounts(ledger)[0]['id'] as String;
    final original = tx('expense', 'expense', id, category(ledger, 'Expense'), 1000);
    ledger = ledger.apply('transaction', original);
    final transaction = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('transaction', {...original, 'operationId': 'edit', 'id': transaction['id'], 'expectedVersion': 1, 'amountMinor': 2500});
    expect(accounts(ledger)[0]['balanceMinor'], 97500);
    expect(LocalLedger.rows(ledger.data['transactions']).single['version'], 2);
    ledger = ledger.apply('void', {'operationId': 'void', 'id': transaction['id'], 'expectedVersion': 2});
    expect(accounts(ledger)[0]['balanceMinor'], 100000);
    expect(ledger.snapshot()['transactions'], isEmpty);
    expect(LocalLedger.rows(ledger.data['transactions']).single['voided'], true);
    expect(LocalLedger.rows(ledger.data['audit']).last['before']['amountMinor'], 2500);
  });
  test('valid splits balance; mismatched split is a negative control', () {
    final categories = LocalLedger.rows(ledger.data['categories']).where((c) => c['kind'] == 'Expense').toList();
    final original = tx('split', 'expense', accounts(ledger)[0]['id'], categories[0]['id'], 1050);
    final input = {...original, 'splits': [
      {'categoryId': categories[0]['id'], 'amountMinor': 700},
      {'categoryId': categories[1]['id'], 'amountMinor': 350}]};
    ledger = ledger.apply('transaction', input);
    final postings = LocalLedger.rows(LocalLedger.rows(ledger.data['transactions']).single['postings']);
    expect(postings.fold<int>(0, (s, p) => s + (p['amountMinor'] as int)), 0);
    expect(postings.length, 3);
    expect(() => ledger.apply('transaction', {...input, 'operationId': 'bad-split', 'amountMinor': 1049}), throwsFormatException);
    expect(ledger.revision, 3);
  });
  test('repeated operation is a no-op; different content with same ID fails', () {
    final input = tx('same', 'expense', accounts(ledger)[0]['id'], category(ledger, 'Expense'), 99);
    ledger = ledger.apply('transaction', input);
    expect(identical(ledger.apply('transaction', input), ledger), true);
    expect(() => ledger.apply('transaction', {...input, 'amountMinor': 100}), throwsFormatException);
  });
  test('invalid operation does not consume its operation ID', () {
    final input = tx('retry', 'expense', accounts(ledger)[0]['id'], category(ledger, 'Expense'), 0);
    expect(() => ledger.apply('transaction', input), throwsFormatException);
    ledger = ledger.apply('transaction', {...input, 'amountMinor': 1});
    expect(accounts(ledger)[0]['balanceMinor'], 99999);
  });
  test('self transfer, wrong category kind and impossible dates rejected', () {
    final id = accounts(ledger)[0]['id'] as String;
    expect(() => ledger.apply('transaction', tx('self', 'transfer', id, id, 1)), throwsFormatException);
    expect(() => ledger.apply('transaction', tx('wrong', 'expense', id, category(ledger, 'Income'), 1)), throwsFormatException);
    expect(() => ledger.apply('transaction', {...tx('date', 'expense', id, category(ledger, 'Expense'), 1), 'effectiveDate': '2026-02-30'}), throwsFormatException);
  });
  test('stale transaction edit rejected without changing balances', () {
    final input = tx('original', 'income', accounts(ledger)[0]['id'], category(ledger, 'Income'), 500);
    ledger = ledger.apply('transaction', input);
    final id = LocalLedger.rows(ledger.data['transactions']).single['id'];
    expect(() => ledger.apply('transaction', {...input, 'operationId': 'stale', 'id': id, 'expectedVersion': 0}), throwsFormatException);
    expect(accounts(ledger)[0]['balanceMinor'], 100500);
  });
  test('snapshot mutations do not modify ledger; tampered postings fail restore validation', () {
    final input = tx('original', 'expense', accounts(ledger)[0]['id'], category(ledger, 'Expense'), 500);
    ledger = ledger.apply('transaction', input);
    final snapshot = ledger.snapshot();
    (snapshot['accounts'] as List).first['name'] = 'Changed';
    expect(accounts(ledger)[0]['name'], 'Checking');
    final altered = LocalLedger.clone(ledger.data);
    (altered['transactions'] as List).first['amountMinor'] = 1;
    expect(() => LocalLedger(altered), throwsFormatException);
    expect(() => LocalLedger({...ledger.data, 'schema': 99}), throwsFormatException);
  });
  test('category rename and account edit retain transaction references and audit', () {
    final a = accounts(ledger)[0];
    ledger = ledger.apply('account', {...account('edit-account', 'Primary', 150000), 'id': a['id'], 'expectedVersion': 1});
    expect(accounts(ledger)[0]['balanceMinor'], 150000);
    final c = LocalLedger.rows(ledger.data['categories']).first;
    ledger = ledger.apply('category', {'operationId': 'rename', 'id': c['id'], 'name': 'Food'});
    expect(LocalLedger.rows(ledger.data['categories']).first['name'], 'Food');
  });
}
