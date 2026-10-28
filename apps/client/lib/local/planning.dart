import 'budgets.dart';
import 'ledger.dart';
import 'recurrence.dart';
import 'schedules.dart';

/// Read-only event. No forecast or calendar action posts to the ledger.
class PlanningEvent {
  const PlanningEvent({required this.id, required this.date, required this.name,
    required this.status, required this.kind, required this.accountIds,
    required this.changes, this.transaction, this.occurrence});
  final String id, date, name, status, kind;
  final Set<String> accountIds;
  final Map<String, int> changes;
  final Json? transaction;
  final ScheduledOccurrence? occurrence;
  bool get planned => occurrence != null;
  int changeFor(Set<String> ids) => changes.entries.where((e) => ids.contains(e.key))
      .fold(0, (total, e) => BudgetEngine.add(total, e.value));
}

class ForecastDay {
  const ForecastDay(this.date, this.recorded, this.projected, this.events);
  final String date;
  final Map<String, int> recorded, projected;
  final List<PlanningEvent> events;
  int total(Set<String> ids, {bool includePlans = true}) => ids.fold(0,
    (sum, id) => BudgetEngine.add(sum, (includePlans ? projected : recorded)[id] ?? 0));
}

class CashForecast {
  const CashForecast(this.today, this.starting, this.days, this.overdueCounts);
  final String today;
  final Map<String, int> starting;
  final List<ForecastDay> days;
  final Map<String, int> overdueCounts;
  String? firstBelow(String accountId, int minimum) {
    for (final day in days) {
      if (day.projected[accountId]! < minimum) return day.date;
    }
    return null;
  }
}

class PlanningEngine {
  static const maxEvents = 100000;
  static const cashTypes = ['checking', 'savings', 'cash'];
  static bool cashAccount(Json account) => cashTypes.contains(account['type']);
  static bool _within(String date, String from, String through) =>
      date.compareTo(from) >= 0 && date.compareTo(through) <= 0;
  static Set<String> _accountIds(Json value) => {
    value['accountId'] as String,
    if (value['kind'] == 'transfer') value['counterpartyAccountId'] as String,
  };
  static Map<String, int> _changes(List<Json> postings, Set<String> known) {
    final result = <String, int>{};
    for (final posting in postings) {
      final id = posting['ledgerId'] as String;
      if (known.contains(id)) {
        result[id] = BudgetEngine.add(result[id] ?? 0, posting['amountMinor'] as int);
      }
    }
    return result;
  }
  static Map<String, Map<int, Json>> _records(Json data) {
    final result = <String, Map<int, Json>>{};
    for (final record in LocalLedger.rows(data['occurrences'] ?? <Json>[])) {
      (result[record['scheduleId'] as String] ??= {})[record['index'] as int] = record;
    }
    return result;
  }

  /// Enumerates the requested dates directly, not the truncated Upcoming list.
  /// An old overdue backlog can never displace entries in a future forecast.
  static List<PlanningEvent> calendar(Json data, {required String from,
      required String through, required String today}) {
    final first = Recurrence.parse(from), last = Recurrence.parse(through);
    Recurrence.parse(today);
    if (last.isBefore(first) || last.difference(first).inDays > 365) {
      throw const FormatException('Choose a calendar range of at most 366 days.');
    }
    final accounts = LocalLedger.rows(data['accounts']);
    final categories = LocalLedger.rows(data['categories']);
    final known = accounts.map((a) => a['id'] as String).toSet();
    final schedules = LocalLedger.rows(data['schedules'] ?? <Json>[]);
    final byId = {for (final s in schedules) s['id']: s};
    final records = _records(data);
    final events = <PlanningEvent>[];
    void add(PlanningEvent event) {
      if (events.length >= maxEvents) {
        throw const FormatException('Too much activity for this range. Choose a shorter range. No partial forecast is shown.');
      }
      events.add(event);
    }
    for (final t in LocalLedger.rows(data['transactions'])) {
      final date = t['effectiveDate'] as String;
      if (!_within(date, from, through)) continue;
      final voided = t['voided'] == true;
      final payee = t['payee'] as String? ?? '';
      add(PlanningEvent(id: 'transaction:${t['id']}', date: date,
        name: payee.isNotEmpty ? payee : byId[t['scheduleId']]?['name'] as String? ?? 'Recorded ${t['kind']}',
        status: voided ? 'Voided' : date.compareTo(today) > 0 ? 'Recorded future' : 'Recorded',
        kind: t['kind'] as String, accountIds: _accountIds(t),
        changes: voided ? {} : _changes(LocalLedger.rows(t['postings']), known), transaction: t));
    }
    for (final schedule in schedules) {
      final byIndex = records[schedule['id']] ?? <int, Json>{};
      for (final record in byIndex.values.where((r) => r['status'] == 'skipped')) {
        final date = record['dueDate'] as String;
        if (_within(date, from, through)) {
          add(PlanningEvent(id: 'skip:${record['id']}', date: date,
            name: schedule['name'] as String, status: 'Skipped', kind: schedule['kind'] as String,
            accountIds: _accountIds(schedule), changes: const {}));
        }
      }
      if (schedule['paused'] == true) continue;
      void planned(ScheduledOccurrence occurrence) {
        final overdue = occurrence.dueDate.compareTo(today) < 0;
        add(PlanningEvent(id: 'schedule:${schedule['id']}/${occurrence.index}',
          date: occurrence.dueDate, name: occurrence.name,
          status: overdue ? 'Overdue' : occurrence.record != null ? 'Postponed' : 'Scheduled',
          kind: schedule['kind'] as String, accountIds: _accountIds(schedule),
          changes: _changes(LocalLedger.postingsFor({...schedule, 'splits': <Json>[]}, accounts, categories), known),
          occurrence: occurrence));
      }
      final start = schedule['startDate'] as String;
      final frequency = schedule['frequency'] as String;
      var index = Recurrence.lastIndex(start, frequency, from);
      if (index < 0) index = 0;
      if (Recurrence.at(start, frequency, index)!.compareTo(from) < 0) index++;
      final end = schedule['endDate'] as String?;
      final limit = Recurrence.lastIndex(start, frequency,
        end != null && end.compareTo(through) < 0 ? end : through);
      for (; index <= limit; index++) {
        if (byIndex.containsKey(index)) continue;
        planned(ScheduledOccurrence(schedule, index, Recurrence.at(start, frequency, index)!, null));
      }
      // Explicit postponements may originate before this range or move past the
      // template's end date. Their stable identity is retained exactly once.
      for (final record in byIndex.values) {
        if (record['status'] == 'postponed' && _within(record['dueDate'] as String, from, through)) {
          planned(ScheduledOccurrence(schedule, record['index'] as int,
            record['originalDueDate'] as String, record));
        }
      }
    }
    events.sort((a, b) {
      final order = a.date.compareTo(b.date);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return events;
  }

  /// Counts unresolved overdue dates without enumerating years of history.
  /// These dates are disclosed but NEVER assigned an invented payment date.
  static Map<String, int> overdueCounts(Json data, String today) {
    Recurrence.parse(today);
    final result = <String, int>{};
    final records = _records(data);
    for (final s in LocalLedger.rows(data['schedules'] ?? <Json>[])) {
      if (s['paused'] == true) continue;
      final start = s['startDate'] as String, frequency = s['frequency'] as String;
      final end = s['endDate'] as String?;
      final through = end != null && end.compareTo(today) < 0 ? end : today;
      var last = Recurrence.lastIndex(start, frequency, through);
      if (last >= 0 && Recurrence.at(start, frequency, last) == today) last--;
      var count = last + 1;
      for (final r in (records[s['id']] ?? <int, Json>{}).values) {
        if ((r['index'] as int) <= last) count--;
        if (r['status'] == 'postponed' && (r['dueDate'] as String).compareTo(today) < 0) count++;
      }
      for (final id in _accountIds(s)) { result[id] = (result[id] ?? 0) + count; }
    }
    return result;
  }

  /// Starting balances include recorded entries through today, not future-dated
  /// entries. Future recorded entries enter on their effective date. Confirmed
  /// occurrences appear only as their actual transaction, including edited dates.
  static CashForecast forecast(Json data, {required String today, int days = 30}) {
    if (days < 1 || days > 365) throw const FormatException('Choose 1 to 365 forecast days.');
    final start = Recurrence.parse(today);
    final end = start.add(Duration(days: days - 1));
    if (end.year > 9999) throw const FormatException('Forecast exceeds the supported date range.');
    final balances = {for (final a in LocalLedger.rows(data['accounts'])) a['id'] as String: a['openingBalanceMinor'] as int};
    final known = balances.keys.toSet();
    for (final t in LocalLedger.rows(data['transactions'])) {
      if (t['voided'] == true || (t['effectiveDate'] as String).compareTo(today) > 0) continue;
      for (final entry in _changes(LocalLedger.rows(t['postings']), known).entries) {
        balances[entry.key] = BudgetEngine.add(balances[entry.key]!, entry.value);
      }
    }
    final events = calendar(data, from: today, through: Recurrence.format(end), today: today);
    final byDate = <String, List<PlanningEvent>>{};
    for (final event in events) { (byDate[event.date] ??= []).add(event); }
    final recorded = Map<String, int>.from(balances), projected = Map<String, int>.from(balances);
    final result = <ForecastDay>[];
    for (var i = 0; i < days; i++) {
      final date = Recurrence.format(start.add(Duration(days: i)));
      final daily = byDate[date] ?? <PlanningEvent>[];
      for (final event in daily) {
        if (!event.planned && date == today) continue; // Already in the start.
        for (final change in event.changes.entries) {
          if (!event.planned) recorded[change.key] = BudgetEngine.add(recorded[change.key]!, change.value);
          projected[change.key] = BudgetEngine.add(projected[change.key]!, change.value);
        }
      }
      result.add(ForecastDay(date, Map.unmodifiable(recorded), Map.unmodifiable(projected), List.unmodifiable(daily)));
    }
    return CashForecast(today, Map.unmodifiable(balances), result, overdueCounts(data, today));
  }
}
