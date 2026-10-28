import 'ledger.dart';
import 'recurrence.dart';

class ScheduledOccurrence {
  const ScheduledOccurrence(this.schedule, this.index, this.originalDueDate, this.record);
  final Json schedule;
  final int index;
  final String originalDueDate;
  final Json? record;
  String get dueDate => record?['dueDate'] as String? ?? originalDueDate;
  String get name => schedule['name'] as String;
  int get amount => schedule['amountMinor'] as int;
  int get version => record?['version'] as int? ?? 0;
  Json command(String operationId) => {'operationId': operationId, 'scheduleId': schedule['id'],
    'index': index, 'expectedScheduleVersion': schedule['version'], 'expectedOccurrenceVersion': version};
  String timing(String today) {
    final days = Recurrence.parse(dueDate).difference(Recurrence.parse(today)).inDays;
    if (days < 0) return 'Overdue by ${-days} day${days == -1 ? '' : 's'}';
    if (days == 0) return 'Due today';
    return 'Due in $days day${days == 1 ? '' : 's'}';
  }
}

class UpcomingSchedulePage {
  const UpcomingSchedulePage(this.items, this.hasMore);
  final List<ScheduledOccurrence> items;
  final bool hasMore;
}

/// Upcoming entries are projections, not ledger transactions. There is no timer
/// that posts a bill, skips an overdue date or writes an occurrence on opening.
class ScheduleEngine {
  static String horizon(String today, int days) {
    if (days < 0 || days > 366) throw const FormatException('Choose a horizon of at most 366 days.');
    final result = Recurrence.parse(today).add(Duration(days: days));
    return result.year > 9999 ? '9999-12-31' : Recurrence.format(result);
  }

  /// All unconfirmed overdue dates are eligible, not only a recent lookback.
  /// Fetch one extra candidate per schedule, then sort before limiting globally.
  /// This keeps the oldest eligible dates visible and reports truncation.
  static UpcomingSchedulePage upcoming(Json data, {required String today, int days = 30, int limit = 200}) {
    if (limit < 1 || limit > 1000) throw const FormatException('Invalid scheduled list limit.');
    final through = horizon(today, days);
    final records = <String, Map<int, Json>>{};
    for (final record in LocalLedger.rows(data['occurrences'] ?? <Json>[])) {
      (records[record['scheduleId'] as String] ??= {})[record['index'] as int] = record;
    }
    final candidates = <ScheduledOccurrence>[];
    for (final schedule in LocalLedger.rows(data['schedules'] ?? <Json>[])) {
      if (schedule['paused'] == true) continue;
      final end = schedule['endDate'] as String?;
      final last = Recurrence.lastIndex(schedule['startDate'] as String, schedule['frequency'] as String,
          end != null && end.compareTo(through) < 0 ? end : through);
      final byIndex = records[schedule['id']] ?? <int, Json>{};
      var included = 0;
      for (var index = 0; index <= last && included <= limit; index++) {
        // Explicit records are handled separately so a postponed early date
        // cannot displace a later original date that is actually due sooner.
        if (byIndex.containsKey(index)) continue;
        final due = Recurrence.at(schedule['startDate'] as String, schedule['frequency'] as String, index)!;
        final occurrence = ScheduledOccurrence(schedule, index, due, null);
        if (occurrence.dueDate.compareTo(through) > 0) continue;
        candidates.add(occurrence);
        included++;
      }
      for (final record in byIndex.values) {
        if (record['status'] != 'postponed' || (record['dueDate'] as String).compareTo(through) > 0) continue;
        candidates.add(ScheduledOccurrence(schedule, record['index'] as int, record['originalDueDate'] as String, record));
      }
    }
    candidates.sort((a, b) {
      final date = a.dueDate.compareTo(b.dueDate);
      if (date != 0) return date;
      final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (name != 0) return name;
      final id = (a.schedule['id'] as String).compareTo(b.schedule['id'] as String);
      return id == 0 ? a.index.compareTo(b.index) : id;
    });
    return UpcomingSchedulePage(candidates.take(limit).toList(), candidates.length > limit);
  }
}
