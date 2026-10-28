import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/planning.dart';
import 'package:budgetism/local/schedules.dart';
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'schedules_test.dart' show scheduleInput, occurrenceInput, onlySchedule;
import 'csv_import_test.dart' show importBatch, createRow;

LocalLedger matchingFixture({bool imported = false, String kind = 'expense', int amount = 2000,
    int expected = 2000, String date = '2026-10-28'}) {
  var ledger = LocalLedger.empty().apply('account', account('a', 'Fictional matching account', 100000))
    .apply('account', account('b', 'Fictional destination', 0));
  ledger = ledger.apply('schedule', scheduleInput(ledger, 'schedule', start: '2026-10-28', kind: kind, amount: expected));
  if (imported) {
    ledger = ledger.apply('import-csv', importBatch(ledger,
      [{...createRow(ledger, signed: -amount, reference: 'fictional-bank-id'), 'date': date}]));
  } else {
    ledger = ledger.apply('transaction', {...tx('actual', kind, accounts(ledger).first['id'] as String,
      kind == 'transfer' ? accounts(ledger).last['id'] as String : category(ledger, kind == 'income' ? 'Income' : 'Expense'),
      amount), 'effectiveDate': date});
  }
  return ledger;
}

Json matchRequest(LocalLedger ledger, String operation, {int index = 0, String? transactionId}) {
  final transaction = LocalLedger.rows(ledger.data['transactions'])
    .firstWhere((t) => transactionId == null || t['id'] == transactionId);
  return {...occurrenceInput(ledger, operation, index), 'expectedRevision': ledger.revision,
    'transactionId': transaction['id'], 'expectedTransactionVersion': transaction['version'], 'confirmMatch': true};
}

void main() {
  test('preview is read-only and match preserves every financial field and schema', () {
    final ledger = matchingFixture();
    final before = jsonEncode(ledger.data);
    final actual = LocalLedger.rows(ledger.data['transactions']).single;
    expect(ScheduleMatching.candidates(ledger.snapshot(), onlySchedule(ledger), '2026-10-28').single, actual);
    expect(jsonEncode(ledger.data), before);
    final result = ledger.apply('schedule-match', matchRequest(ledger, 'link'));
    expect(result.data['schema'], ledger.data['schema']);
    expect(result.snapshot()['accounts'], ledger.snapshot()['accounts']);
    expect(result.data['categories'], ledger.data['categories']);
    expect(result.data['budgets'], ledger.data['budgets']);
    expect(result.data['schedules'], ledger.data['schedules']);
    final linked = LocalLedger.rows(result.data['transactions']).single;
    for (final key in actual.keys.where((key) => key != 'version')) { expect(linked[key], actual[key], reason: key); }
    expect(linked['version'], actual['version'] + 1);
    expect(linked['scheduleId'], onlySchedule(ledger)['id']);
    expect(LocalLedger.rows(result.data['occurrences']).single['transactionId'], actual['id']);
    expect(BudgetEngine.calculate(result.snapshot(), '2026-10').spent, 2000);
    final audit = LocalLedger.rows(result.data['audit']);
    expect(audit[audit.length - 2]['action'], 'schedule-match-link');
    expect(audit[audit.length - 2]['before'], actual);
    expect(audit.last['action'], 'schedule-match');
  });

  test('imported payment keeps its receipt and cannot be reimported after matching', () {
    var ledger = matchingFixture(imported: true);
    final receipts = LocalLedger.clone(ledger.data)['imports'];
    ledger = ledger.apply('schedule-match', matchRequest(ledger, 'match-import'));
    expect(ledger.data['schema'], 4); expect(ledger.data['imports'], receipts);
    expect(ledger.data['transactions'].length, 1);
    expect(() => ledger.apply('import-csv', importBatch(ledger, [createRow(ledger, reference: 'fictional-bank-id')],
      operation: 'reimport')), throwsFormatException);
  });

  test('variable amounts and split categories retain actual totals after explicit review', () {
    var ledger = matchingFixture(amount: 2345, date: '2026-10-30');
    final actual = LocalLedger.rows(ledger.data['transactions']).single;
    final categories = LocalLedger.rows(ledger.data['categories']).where((c) => c['kind'] == 'Expense').toList();
    ledger = ledger.apply('transaction', {...actual, 'operationId': 'split', 'expectedVersion': 1,
      'splits': [{'categoryId': categories[1]['id'], 'amountMinor': 1000}, {'categoryId': categories[2]['id'], 'amountMinor': 1345}]});
    expect(ScheduleMatching.candidates(ledger.snapshot(), onlySchedule(ledger), '2026-10-28'), isEmpty);
    expect(ScheduleMatching.candidates(ledger.snapshot(), onlySchedule(ledger), '2026-10-28', includeDifferentAmounts: true).length, 1);
    final postings = LocalLedger.rows(ledger.data['transactions']).single['postings'];
    final result = ledger.apply('schedule-match', matchRequest(ledger, 'link-split'));
    expect(LocalLedger.rows(result.data['transactions']).single['postings'], postings);
    expect(BudgetEngine.calculate(result.snapshot(), '2026-10').spent, 2345);
    expect(LocalLedger.rows(result.data['occurrences']).single['plannedAmountMinor'], 2000);
    expect(LocalLedger.rows(result.data['transactions']).single['effectiveDate'], '2026-10-30');
  });

  test('recorded income and transfers link without a new posting or budget expense', () {
    for (final kind in ['income', 'transfer']) {
      final ledger = matchingFixture(kind: kind);
      final result = ledger.apply('schedule-match', matchRequest(ledger, 'link-$kind'));
      expect(result.snapshot()['accounts'], ledger.snapshot()['accounts']);
      expect(result.data['transactions'].length, 1);
      expect(BudgetEngine.calculate(result.snapshot(), '2026-10').spent, 0);
    }
  });

  test('wrong account, type, currency, voided and reverse transfer candidates are excluded', () {
    final ledger = matchingFixture(kind: 'transfer');
    final schedule = onlySchedule(ledger), actual = LocalLedger.rows(ledger.data['transactions']).single;
    for (final invalid in [
      {...actual, 'accountId': schedule['counterpartyAccountId'], 'counterpartyAccountId': schedule['accountId']},
      {...actual, 'counterpartyAccountId': 'different'}, {...actual, 'accountId': 'different'},
      {...actual, 'kind': 'income'}, {...actual, 'currency': 'EUR'}, {...actual, 'voided': true},
      {...actual, 'scheduleId': 'already-linked'}, {...actual, 'occurrenceIndex': 0},
    ]) { expect(ScheduleMatching.eligible(schedule, invalid), isFalse); }
    final expense = matchingFixture();
    final t = LocalLedger.rows(expense.data['transactions']).single;
    final voided = expense.apply('void', {'operationId': 'void', 'id': t['id'], 'expectedVersion': t['version']});
    expect(() => voided.apply('schedule-match', matchRequest(voided, 'void-match')), throwsFormatException);
    final wrongKind = expense.apply('transaction', {...t, 'kind': 'income', 'counterpartyAccountId': category(expense, 'Income'),
      'operationId': 'wrong-kind', 'expectedVersion': t['version']});
    expect(() => wrongKind.apply('schedule-match', matchRequest(wrongKind, 'wrong-match')), throwsFormatException);
    final reverse = ledger.apply('transaction', {...actual, 'accountId': schedule['counterpartyAccountId'],
      'counterpartyAccountId': schedule['accountId'], 'operationId': 'reverse', 'expectedVersion': actual['version']});
    expect(() => reverse.apply('schedule-match', matchRequest(reverse, 'reverse-match')), throwsFormatException);
  });

  test('date windows include endpoints, exclude beyond 90 days and use date-only math', () {
    final at90 = matchingFixture(date: '2027-01-26');
    expect(ScheduleMatching.candidates(at90.snapshot(), onlySchedule(at90), '2026-10-28'), isEmpty);
    expect(ScheduleMatching.candidates(at90.snapshot(), onlySchedule(at90), '2026-10-28', windowDays: 90).length, 1);
    expect(at90.apply('schedule-match', matchRequest(at90, 'day90')).data['transactions'].length, 1);
    final at91 = matchingFixture(date: '2027-01-27');
    expect(ScheduleMatching.candidates(at91.snapshot(), onlySchedule(at91), '2026-10-28', windowDays: 90), isEmpty);
    expect(() => at91.apply('schedule-match', matchRequest(at91, 'day91')), throwsFormatException);
    final before90 = matchingFixture(date: '2026-07-30');
    expect(before90.apply('schedule-match', matchRequest(before90, 'before90')).data['transactions'].length, 1);
    expect(ScheduleMatching.daysApart('2026-11-01', '2026-11-02'), 1);
    expect(() => ScheduleMatching.candidates(at90.snapshot(), onlySchedule(at90), '2026-10-28', windowDays: 365), throwsFormatException);
  });

  test('no implicit match and repeated links or different replay payloads are rejected', () {
    final ledger = matchingFixture();
    final request = matchRequest(ledger, 'link');
    expect(() => ledger.apply('schedule-match', {...request, 'confirmMatch': false}), throwsFormatException);
    final result = ledger.apply('schedule-match', request);
    expect(identical(result.apply('schedule-match', request), result), isTrue);
    expect(() => result.apply('schedule-match', {...request, 'confirmMatch': false}), throwsFormatException);
    expect(() => result.apply('schedule-match', matchRequest(result, 'again')), throwsFormatException);
    expect(() => result.apply('schedule-match', matchRequest(result, 'another-occurrence', index: 1)), throwsFormatException);
    expect(ScheduleMatching.candidates(result.snapshot(), onlySchedule(result), '2026-10-28'), isEmpty);
  });

  test('all stale versions, missing identity, paused schedules and settled dates fail atomically', () {
    final ledger = matchingFixture(); final request = matchRequest(ledger, 'link'); final before = jsonEncode(ledger.data);
    for (final changed in [
      {...request, 'expectedRevision': ledger.revision - 1}, {...request, 'expectedTransactionVersion': 99},
      {...request, 'expectedScheduleVersion': 99}, {...request, 'expectedOccurrenceVersion': 99},
      {...request, 'transactionId': 'missing'}, {...request, 'index': -1},
    ]) { expect(() => ledger.apply('schedule-match', changed), throwsFormatException); }
    expect(jsonEncode(ledger.data), before);
    final schedule = onlySchedule(ledger);
    final paused = ledger.apply('schedule-state', {'operationId': 'pause', 'id': schedule['id'], 'expectedVersion': 1, 'paused': true});
    expect(() => paused.apply('schedule-match', matchRequest(paused, 'paused-match')), throwsFormatException);
    final skipped = ledger.apply('schedule-skip', occurrenceInput(ledger, 'skip', 0));
    expect(() => skipped.apply('schedule-match', matchRequest(skipped, 'skipped-match')), throwsFormatException);
    final postponed = ledger.apply('schedule-postpone', {...occurrenceInput(ledger, 'delay', 0), 'dueDate': '2026-11-02'});
    expect(() => postponed.apply('schedule-match', {...request, 'expectedRevision': postponed.revision}), throwsFormatException);
    expect(postponed.apply('schedule-match', matchRequest(postponed, 'match-postponed')).data['transactions'].length, 1);
  });

  test('matching removes only the planned occurrence and never double counts future actuals', () {
    final ledger = matchingFixture();
    final accountId = accounts(ledger).first['id'] as String;
    final result = ledger.apply('schedule-match', matchRequest(ledger, 'link'));
    final forecast = PlanningEngine.forecast(result.snapshot(), today: '2026-10-27', days: 3);
    expect(forecast.starting[accountId], 100000);
    expect(forecast.days.firstWhere((d) => d.date == '2026-10-28').projected[accountId], 98000);
    expect(PlanningEngine.forecast(result.snapshot(), today: '2026-10-29', days: 3).starting[accountId], 98000);
    expect(ScheduleEngine.upcoming(result.snapshot(), today: '2026-10-28').items.every((o) => o.index != 0), isTrue);
    final calendar = PlanningEngine.calendar(result.snapshot(), from: '2026-10-01', through: '2026-10-31', today: '2026-10-28');
    expect(calendar.where((e) => e.transaction != null).length, 1);
    expect(calendar.where((e) => e.planned && e.occurrence!.index == 0), isEmpty);
  });

  test('edits and voids retain both link and receipt and never regenerate a matched occurrence', () {
    var ledger = matchingFixture(imported: true);
    ledger = ledger.apply('schedule-match', matchRequest(ledger, 'link'));
    final t = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('transaction', {...t, 'operationId': 'edit', 'expectedVersion': t['version'], 'amountMinor': 2345});
    expect(LocalLedger.rows(ledger.data['transactions']).single['scheduleId'], onlySchedule(ledger)['id']);
    ledger = ledger.apply('void', {'operationId': 'void', 'id': t['id'], 'expectedVersion': 3});
    expect(accounts(ledger).first['balanceMinor'], 100000);
    expect(ledger.data['imports'].length, 1);
    expect(ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-10-28').items.every((o) => o.index != 0), isTrue);
    expect(() => ledger.apply('schedule-confirm', {...occurrenceInput(ledger, 'duplicate-confirm', 0),
      'effectiveDate': '2026-10-28', 'amountMinor': 2000}), throwsFormatException);
    final bad = LocalLedger.clone(ledger.data); (bad['transactions'] as List).single.remove('scheduleId');
    expect(() => LocalLedger(bad), throwsFormatException);
  });
}
