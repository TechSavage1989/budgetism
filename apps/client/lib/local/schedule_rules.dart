part of 'ledger.dart';

class _ScheduleChange {
  _ScheduleChange(this.id, this.before, this.after);
  final String id;
  final Json? before;
  final Json after;
}

/// Runs inside the same detached ledger mutation and SQLite commit as the
/// resulting transaction. A settled occurrence can never create another one.
class _ScheduleRules {
  static const actions = ['schedule', 'schedule-state', 'schedule-confirm', 'schedule-postpone', 'schedule-skip'];
  static const statuses = ['postponed', 'confirmed', 'skipped'];
  static Never fail(String message) => LocalLedger.fail(message);

  static void template(Json schedule, List<Json> accounts, List<Json> categories) {
    LocalLedger.text(schedule['name'], 'Schedule name', 100);
    LocalLedger.text(schedule['payee'], 'Payee', 150, optional: true);
    LocalLedger.text(schedule['notes'], 'Notes', 500, optional: true);
    Recurrence.parse(schedule['startDate']);
    if (!Recurrence.frequencies.contains(schedule['frequency']) || schedule['paused'] is! bool ||
        schedule['version'] is! int || schedule['version'] < 1) {
      fail('Invalid recurring schedule.');
    }
    if (schedule['endDate'] != null) {
      Recurrence.parse(schedule['endDate']);
      if ((schedule['endDate'] as String).compareTo(schedule['startDate'] as String) < 0) {
        fail('The last scheduled date must not precede the first due date.');
      }
    }
    LocalLedger.postingsFor({...schedule, 'splits': <Json>[]}, accounts, categories);
  }

  static String originalDate(Json schedule, Object? index) {
    if (index is! int) fail('Invalid occurrence index.');
    final due = Recurrence.at(schedule['startDate'] as String, schedule['frequency'] as String, index);
    if (due == null || (schedule['endDate'] != null && due.compareTo(schedule['endDate'] as String) > 0)) {
      fail('This occurrence is outside the schedule.');
    }
    return due;
  }

  static _ScheduleChange apply(Json next, String action, Json input, String operation,
      List<Json> accounts, List<Json> categories, List<Json> transactions) {
    final schedules = LocalLedger.rows(next['schedules']);
    final occurrences = LocalLedger.rows(next['occurrences']);
    if (action == 'schedule' || action == 'schedule-state') {
      final id = input['id'] == null ? const Uuid().v4() : LocalLedger.text(input['id'], 'Schedule identifier', 100);
      final index = schedules.indexWhere((s) => s['id'] == id);
      if ((input['id'] != null || action == 'schedule-state') && index < 0) fail('Schedule was not found.');
      final before = index < 0 ? null : schedules[index];
      if (input['expectedVersion'] != (before?['version'] ?? 0)) fail('Schedule changed. Refresh before editing.');
      if (before == null && schedules.length >= 500) fail('This preview supports up to 500 schedules.');
      Json after;
      if (action == 'schedule-state') {
        if (input['paused'] is! bool) fail('Choose whether the schedule is paused.');
        after = {...before!, 'paused': input['paused'], 'version': (before['version'] as int) + 1};
      } else {
        if (before != null && ['startDate', 'frequency', 'endDate'].any((key) => before[key] != input[key])) {
          fail('The recurrence and date range cannot be changed. Pause this schedule and create a new one.');
        }
        after = {'id': id, 'name': LocalLedger.text(input['name'], 'Schedule name', 100),
          'kind': input['kind'], 'accountId': input['accountId'], 'counterpartyAccountId': input['counterpartyAccountId'],
          'currency': input['currency'], 'amountMinor': LocalLedger.minor(input['amountMinor']),
          'payee': LocalLedger.text(input['payee'] ?? '', 'Payee', 150, optional: true),
          'notes': LocalLedger.text(input['notes'] ?? '', 'Notes', 500, optional: true),
          'startDate': input['startDate'], 'frequency': input['frequency'], 'endDate': input['endDate'],
          'paused': before?['paused'] ?? false, 'version': (before?['version'] as int? ?? 0) + 1};
        template(after, accounts, categories);
      }
      if (index < 0) { schedules.add(after); } else { schedules[index] = after; }
      next['schedules'] = schedules;
      return _ScheduleChange(id, before, after);
    }

    final scheduleIndex = schedules.indexWhere((s) => s['id'] == input['scheduleId']);
    if (scheduleIndex < 0) fail('Schedule was not found.');
    final schedule = schedules[scheduleIndex];
    if (schedule['paused'] == true) fail('Resume this schedule before resolving an occurrence.');
    if (input['expectedScheduleVersion'] != schedule['version']) fail('Schedule changed. Refresh before continuing.');
    final original = originalDate(schedule, input['index']);
    final index = occurrences.indexWhere((o) => o['scheduleId'] == schedule['id'] && o['index'] == input['index']);
    final before = index < 0 ? null : occurrences[index];
    if (before != null && before['status'] != 'postponed') {
      fail('This occurrence was already recorded or skipped. Review its history instead.');
    }
    if (input['expectedOccurrenceVersion'] != (before?['version'] ?? 0)) fail('Occurrence changed. Refresh before continuing.');
    final id = before?['id'] as String? ?? const Uuid().v4();
    final after = <String, dynamic>{'id': id, 'scheduleId': schedule['id'], 'index': input['index'],
      'originalDueDate': original, 'dueDate': before?['dueDate'] ?? original,
      'version': (before?['version'] as int? ?? 0) + 1, 'scheduleVersion': schedule['version'],
      'plannedAmountMinor': schedule['amountMinor'], 'transactionId': null, 'resolvedAtUtc': null};
    if (action == 'schedule-postpone') {
      Recurrence.parse(input['dueDate']);
      if ((input['dueDate'] as String).compareTo(after['dueDate'] as String) <= 0) fail('Choose a later due date.');
      after.addAll({'status': 'postponed', 'dueDate': input['dueDate']});
    } else {
      after['resolvedAtUtc'] = DateTime.now().toUtc().toIso8601String();
      if (action == 'schedule-confirm') {
        LocalLedger.date(input['effectiveDate']);
        final transaction = <String, dynamic>{'id': const Uuid().v4(), 'operationId': operation,
          'kind': schedule['kind'], 'accountId': schedule['accountId'], 'counterpartyAccountId': schedule['counterpartyAccountId'],
          'currency': 'USD', 'amountMinor': LocalLedger.minor(input['amountMinor']), 'effectiveDate': input['effectiveDate'],
          'payee': schedule['payee'], 'notes': LocalLedger.text(input['notes'] ?? schedule['notes'], 'Notes', 500, optional: true),
          'splits': <Json>[], 'voided': false, 'version': 1, 'createdUtc': after['resolvedAtUtc'],
          'scheduleId': schedule['id'], 'occurrenceIndex': input['index']};
        transaction['postings'] = LocalLedger.postingsFor(transaction, accounts, categories);
        transactions.add(transaction);
        after.addAll({'status': 'confirmed', 'transactionId': transaction['id']});
      } else if (action == 'schedule-skip') {
        after['status'] = 'skipped';
      } else {
        fail('Unsupported occurrence action.');
      }
    }
    if (index < 0) { occurrences.add(after); } else { occurrences[index] = after; }
    next['occurrences'] = occurrences;
    return _ScheduleChange(id, before, after);
  }

  static void validate(Json data, List<Json> accounts, List<Json> categories,
      List<Json> transactions, Set<String> ids) {
    if (data['schema'] != LocalLedger.schema) {
      for (final key in ['schedules', 'occurrences']) {
        if (data.containsKey(key) && (data[key] is! List || (data[key] as List).isNotEmpty)) {
          fail('Recurring records require the upgraded workspace schema.');
        }
      }
      if (transactions.any((t) => t.containsKey('scheduleId') || t.containsKey('occurrenceIndex'))) {
        fail('Linked transactions require the recurring workspace schema.');
      }
      return;
    }
    if (data['schedules'] is! List || data['occurrences'] is! List) fail('Recurring records are missing.');
    final schedules = LocalLedger.rows(data['schedules']);
    final occurrences = LocalLedger.rows(data['occurrences']);
    if (schedules.length > 500) fail('Too many recurring schedules.');
    final byId = <String, Json>{};
    for (final schedule in schedules) {
      final id = LocalLedger.text(schedule['id'], 'Schedule identifier', 100);
      if (!ids.add(id)) fail('Duplicate record identifier.');
      template(schedule, accounts, categories);
      byId[id] = schedule;
    }
    final txById = {for (final t in transactions) t['id']: t};
    final occurrenceKeys = <String>{};
    final linked = <String>{};
    for (final occurrence in occurrences) {
      final id = LocalLedger.text(occurrence['id'], 'Occurrence identifier', 100);
      if (!ids.add(id)) fail('Duplicate record identifier.');
      final schedule = byId[occurrence['scheduleId']];
      if (schedule == null) fail('Occurrence references an unknown schedule.');
      final original = originalDate(schedule, occurrence['index']);
      Recurrence.parse(occurrence['dueDate']);
      LocalLedger.minor(occurrence['plannedAmountMinor']);
      if (original != occurrence['originalDueDate'] || (occurrence['dueDate'] as String).compareTo(original) < 0 ||
          !statuses.contains(occurrence['status']) || occurrence['version'] is! int || occurrence['version'] < 1 ||
          occurrence['scheduleVersion'] is! int || occurrence['scheduleVersion'] < 1 ||
          occurrence['scheduleVersion'] > schedule['version'] ||
          !occurrenceKeys.add('${schedule['id']}/${occurrence['index']}')) {
        fail('Invalid or duplicate schedule occurrence.');
      }
      final transactionId = occurrence['transactionId'];
      if (occurrence['status'] == 'confirmed') {
        final transaction = txById[transactionId];
        if (transactionId is! String || !linked.add(transactionId) || transaction == null ||
            transaction['scheduleId'] != schedule['id'] || transaction['occurrenceIndex'] != occurrence['index']) {
          fail('Recorded occurrence is missing its linked transaction.');
        }
      } else if (transactionId != null) {
        fail('Unrecorded occurrences cannot reference a transaction.');
      }
      if (occurrence['status'] == 'postponed') {
        if (occurrence['resolvedAtUtc'] != null || occurrence['dueDate'] == original) fail('Invalid postponed occurrence.');
      } else if (occurrence['resolvedAtUtc'] is! String || DateTime.tryParse(occurrence['resolvedAtUtc'] as String) == null) {
        fail('Invalid occurrence resolution timestamp.');
      }
    }
    for (final transaction in transactions) {
      if (transaction.containsKey('scheduleId') || transaction.containsKey('occurrenceIndex')) {
        if (!linked.contains(transaction['id'])) fail('Scheduled transaction is missing its occurrence.');
      }
    }
  }
}
