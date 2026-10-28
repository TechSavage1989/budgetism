part of 'ledger.dart';

/// Suggestions never mutate the ledger. Linking keeps every monetary field and
/// the original import receipt; only relationship metadata and versions change.
class ScheduleMatching {
  static const windows = [7, 30, 90];
  static const maxDays = 90;

  static bool eligible(Json schedule, Json transaction) {
    if (transaction['voided'] != false || transaction.containsKey('scheduleId') ||
        transaction.containsKey('occurrenceIndex') || transaction['kind'] != schedule['kind'] ||
        transaction['accountId'] != schedule['accountId'] || transaction['currency'] != schedule['currency']) {
      return false;
    }
    return schedule['kind'] != 'transfer' ||
        transaction['counterpartyAccountId'] == schedule['counterpartyAccountId'];
  }

  static int daysApart(String dueDate, String recordedDate) =>
      Recurrence.parse(recordedDate).difference(Recurrence.parse(dueDate)).inDays.abs();

  static List<Json> candidates(Json snapshot, Json schedule, String dueDate,
      {int windowDays = 7, bool includeDifferentAmounts = false}) {
    if (!windows.contains(windowDays)) LocalLedger.fail('Choose a supported matching date range.');
    Recurrence.parse(dueDate);
    final result = LocalLedger.rows(snapshot['transactions']).where((t) => eligible(schedule, t) &&
        daysApart(dueDate, t['effectiveDate'] as String) <= windowDays &&
        (includeDifferentAmounts || t['amountMinor'] == schedule['amountMinor'])).toList();
    result.sort((a, b) {
      final amountOrder = (a['amountMinor'] == schedule['amountMinor'] ? 0 : 1)
          .compareTo(b['amountMinor'] == schedule['amountMinor'] ? 0 : 1);
      if (amountOrder != 0) return amountOrder;
      final dateOrder = daysApart(dueDate, a['effectiveDate'] as String)
          .compareTo(daysApart(dueDate, b['effectiveDate'] as String));
      if (dateOrder != 0) return dateOrder;
      final actualDateOrder = (a['effectiveDate'] as String).compareTo(b['effectiveDate'] as String);
      return actualDateOrder != 0 ? actualDateOrder : (a['id'] as String).compareTo(b['id'] as String);
    });
    return result;
  }

  static String _link(Json next, Json input, String operation, Json schedule,
      Json occurrence, List<Json> transactions) {
    if (input['confirmMatch'] != true) LocalLedger.fail('Review and confirm the selected existing transaction.');
    if (input['expectedRevision'] != next['revision']) LocalLedger.fail('Workspace changed. Close this dialog and refresh before matching.');
    final id = LocalLedger.text(input['transactionId'], 'Transaction identifier', 100);
    final index = transactions.indexWhere((t) => t['id'] == id);
    if (index < 0) LocalLedger.fail('The selected transaction was not found.');
    final before = transactions[index];
    if (input['expectedTransactionVersion'] != before['version']) LocalLedger.fail('Transaction changed. Refresh before matching.');
    if (!eligible(schedule, before)) LocalLedger.fail('Choose an unlinked, non-voided transaction of the same type and account. Transfer direction must also match.');
    if (daysApart(occurrence['dueDate'] as String, before['effectiveDate'] as String) > maxDays) {
      LocalLedger.fail('The recorded date must be within 90 days of this occurrence due date.');
    }
    final after = {...before, 'version': (before['version'] as int) + 1,
      'scheduleId': schedule['id'], 'occurrenceIndex': input['index']};
    // Do not recompute postings, change categories/dates, or replace bank IDs.
    transactions[index] = after;
    next['audit'] = [...LocalLedger.rows(next['audit']), {
      'operationId': operation, 'action': 'schedule-match-link', 'objectId': id,
      'atUtc': occurrence['resolvedAtUtc'], 'before': LocalLedger.clone(before), 'after': LocalLedger.clone(after),
    }];
    return id;
  }
}
