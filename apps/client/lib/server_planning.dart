import 'dart:convert';
import 'finance_api.dart';
import 'local/ledger.dart';
import 'local/planning_api.dart';
import 'local/recurrence.dart';
import 'local/budgets.dart';

/// A detached server projection. This adapter never opens or uploads a local vault.
class ServerPlanningApi implements PlanningWorkspaceApi {
  ServerPlanningApi(this.api);
  final FinanceApi api;
  Json? _snapshot;
  int _version = 0, _ledgerCursor = 0, _generation = 0;
  bool busy = false;
  Json? _pending;
  String? _pendingContent;
  @override
  Json get planningSnapshot => LocalLedger.clone(
    _snapshot ?? (throw StateError('Reload server planning first.')),
  );

  static Json validate(Json response) {
    if (response['version'] is! int ||
        (response['version'] as int) < 0 ||
        response['ledgerCursor'] is! int ||
        (response['ledgerCursor'] as int) < 0) {
      throw const FormatException('Invalid planning state.');
    }
    final data = LocalLedger.clone(
      Map<String, dynamic>.from(response['snapshot'] as Map),
    );
    final accounts = LocalLedger.rows(data['accounts']),
        categories = LocalLedger.rows(data['categories']),
        entries = LocalLedger.rows(data['transactions']);
    if (accounts.length + categories.length > 2000 || entries.length > 10000) {
      throw const FormatException(
        'Planning inventory exceeds supported bounds.',
      );
    }
    final accountIds = <String>{}, categoryIds = <String>{}, ids = <String>{};
    for (final a in accounts) {
      if (a['id'] is! String ||
          !accountIds.add(a['id'] as String) ||
          a['currency'] != 'USD' ||
          a['name'] is! String ||
          a['openingBalanceMinor'] != 0 ||
          a['archived'] is! bool) {
        throw const FormatException('Invalid account projection.');
      }
    }
    for (final c in categories) {
      if (c['id'] is! String ||
          !categoryIds.add(c['id'] as String) ||
          !['Expense', 'Income'].contains(c['kind']) ||
          c['currency'] != 'USD') {
        throw const FormatException('Invalid category projection.');
      }
    }
    for (final t in entries) {
      if (!ids.add(t['id'] as String) ||
          !accountIds.contains(t['accountId']) ||
          !['income', 'expense', 'transfer', 'opening'].contains(t['kind']) ||
          t['currency'] != 'USD') {
        throw const FormatException('Invalid entry projection.');
      }
      Recurrence.parse(t['effectiveDate']);
      if (t['amountMinor'] is! int ||
          (t['amountMinor'] as int).abs() > BudgetEngine.maxTotalMinor) {
        throw const FormatException('Invalid exact amount.');
      }
      var total = 0;
      for (final p in LocalLedger.rows(t['postings'])) {
        if (p['amountMinor'] is! int || p['ledgerId'] is! String) {
          throw const FormatException('Invalid posting projection.');
        }
        total = BudgetEngine.add(total, p['amountMinor'] as int);
      }
      if (total != 0 || LocalLedger.rows(t['postings']).length < 2) {
        throw const FormatException('Unbalanced projection.');
      }
      if (t['scheduleId'] == null) {
        t.remove('scheduleId');
        t.remove('occurrenceIndex');
      }
    }
    data['transactions'] = entries;
    for (final key in [
      'budgets',
      'schedules',
      'occurrences',
      'labels',
      'savedViews',
      'annotations',
      'audit',
    ]) {
      if (data[key] is! List) {
        throw const FormatException('Incomplete planning state.');
      }
    }
    data['serverProjection'] = true;
    return data;
  }

  Future<void> refresh() async {
    final generation = ++_generation, session = api.token;
    final response = await api.planningRequest();
    final data = validate(response);
    if (generation != _generation || session != api.token) {
      throw FinanceApiException('Your session changed. Reload.', 401);
    }
    _snapshot = data;
    _version = response['version'] as int;
    _ledgerCursor = response['ledgerCursor'] as int;
  }

  Future<void> command(String action, Json input) async {
    if (busy) throw StateError('A planning action is already running.');
    final data = LocalLedger.clone(input)..remove('operationId');
    // Treat budget dialogs' fresh retry IDs as the same pending content. The
    // original request/envelope/operation ID must survive an uncertain result.
    final content = jsonEncode({'action': action, 'data': data});
    if (_pending != null && _pendingContent != content) {
      throw StateError(
        'Retry the unchanged pending action before starting another.',
      );
    }
    _pending ??= {
      'operationId': input['operationId'],
      'expectedVersion': _version,
      'expectedLedgerCursor': _ledgerCursor,
      'action': action,
      'data': data,
      'confirmed': true,
    };
    _pendingContent = content;
    busy = true;
    try {
      await api.planningRequest(_pending);
      await refresh();
      _pending = null;
      _pendingContent = null;
    } on FinanceApiException catch (e) {
      if (e.statusCode == 400 ||
          e.statusCode == 409 ||
          e.statusCode == 401 ||
          e.statusCode == 403) {
        _pending = null;
        _pendingContent = null;
      }
      rethrow;
    } finally {
      busy = false;
    }
  }

  @override
  Future<void> saveBudget(Json d) => command('budget', d);
  @override
  Future<void> removeBudget(Json d) => command('budget-remove', d);
  @override
  Future<void> copyBudgets(Json d) => command('budget-copy', d);
  @override
  Future<void> saveSchedule(Json d) => command('schedule', d);
  @override
  Future<void> setSchedulePaused(Json d) => command('schedule-state', d);
  @override
  Future<void> matchOccurrence(Json d) => command('schedule-match', d);
  @override
  Future<void> confirmOccurrence(Json d) => command('schedule-confirm', d);
  @override
  Future<void> postponeOccurrence(Json d) => command('schedule-postpone', d);
  @override
  Future<void> skipOccurrence(Json d) => command('schedule-skip', d);
}
