import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/reports.dart';

void main() {
  test('aggregate transfer-only movement beyond the exact range fails during calculation, not UI rendering', () {
    final data = LocalLedger.clone(LocalLedger.empty().data);
    final accounts = <Json>[];
    final transactions = <Json>[];
    final selected = <String>{};
    const amount = 50000000000000;
    for (var i = 0; i < 100; i++) {
      final to = 'selected-$i', from = 'outside-$i';
      selected.add(to);
      accounts.addAll([
        {'id': to, 'name': 'Fictional selected $i', 'type': 'checking', 'currency': 'USD', 'version': 1, 'openingBalanceMinor': -amount},
        {'id': from, 'name': 'Fictional outside $i', 'type': 'checking', 'currency': 'USD', 'version': 1, 'openingBalanceMinor': amount},
      ]);
      for (final month in ['09', '10']) {
        transactions.add({'id': 'transfer-$i-$month', 'kind': 'transfer', 'accountId': from,
          'counterpartyAccountId': to, 'currency': 'USD', 'amountMinor': amount,
          'effectiveDate': '2026-$month-15', 'payee': 'Fictional transfer', 'notes': '',
          'version': 1, 'voided': false, 'postings': [
            {'ledgerId': from, 'amountMinor': -amount}, {'ledgerId': to, 'amountMinor': amount}]});
      }
    }
    data['accounts'] = accounts; data['transactions'] = transactions;
    final ledger = LocalLedger(data); // Every saved account remains within the ledger's own limit.
    expect(() => ReportEngine.calculate(ledger.snapshot(), from: '2026-09-01',
      through: '2026-10-28', today: '2026-10-28', accountIds: selected), throwsFormatException);
    final ordinary = ReportEngine.calculate(ledger.snapshot(), from: '2026-09-01',
      through: '2026-10-28', today: '2026-10-28', accountIds: {'selected-0'});
    expect(ordinary.balanceChange, amount * 2); expect(ordinary.netIncome, 0);
  });
}
