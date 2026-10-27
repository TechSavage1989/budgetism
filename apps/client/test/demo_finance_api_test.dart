import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/demo_finance_api.dart';

void main() {
  test('Demo returns explicit sample accounts and does not require network', () async {
    final demo = DemoFinanceApi();
    expect(demo.isDemo, isTrue);
    final snapshot = await demo.snapshot();
    expect((snapshot['accounts'] as List).length, 3);
    expect((snapshot['transactions'] as List).length, 4);
  });

  test('Demo transfer updates both accounts and preserves net worth', () async {
    final demo = DemoFinanceApi();
    final before = (await demo.snapshot())['accounts'] as List;
    final cashBefore = (before[0]['balanceMinor'] as int) + (before[1]['balanceMinor'] as int);
    final from = before[0]['id'] as String;
    final to = before[1]['id'] as String;
    final transfer = {
      'operationId': 'a6e7685b-889f-47c7-9d71-1ec6b7e9b142',
      'kind': 'transfer', 'accountId': from, 'counterpartyAccountId': to,
      'amountMinor': 2500, 'currency': 'USD', 'effectiveDate': '2026-10-27',
      'payee': 'Savings', 'notes': '',
    };
    await demo.createTransaction(transfer);
    await demo.createTransaction(transfer); // idempotent retry
    final after = (await demo.snapshot())['accounts'] as List;
    expect(after[0]['balanceMinor'], (before[0]['balanceMinor'] as int) - 2500);
    expect(after[1]['balanceMinor'], (before[1]['balanceMinor'] as int) + 2500);
    expect((after[0]['balanceMinor'] as int) + (after[1]['balanceMinor'] as int), cashBefore);
    expect(((await demo.snapshot())['transactions'] as List).length, 5);
  });

  test('Demo rejects a transfer into the same account', () async {
    final demo = DemoFinanceApi();
    final accountId = ((await demo.snapshot())['accounts'] as List).first['id'];
    expect(() => demo.createTransaction({
      'operationId':'3bef1706-44f7-4ee4-bf5c-a1614fe4fb72',
      'kind':'transfer','accountId':accountId,'counterpartyAccountId':accountId,
      'amountMinor':100,'currency':'USD','effectiveDate':'2026-10-27',
      'payee':'Invalid','notes':''
    }), throwsArgumentError);
  });
}
