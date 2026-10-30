import 'server_bank.dart';

/// Detached, bounded read model. Provider balances never enter ledger totals.
class ServerDashboard {
  ServerDashboard._(this.data);
  final Map<String, dynamic> data;
  static ServerDashboard parse(Map<String, dynamic> data, String through) {
    Never invalid() =>
        throw const FormatException('Invalid dashboard response.');
    bool integer(dynamic v, {int min = -9007199254740991}) =>
        v is int && v >= min && v <= 9007199254740991;
    bool text(dynamic v, int max) =>
        v is String && v.isNotEmpty && v.length <= max;
    bool id(dynamic v) =>
        v is String &&
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(v);
    List<Map<String, dynamic>> rows(String key, int max) {
      final value = data[key];
      if (value is! List || value.length > max) invalid();
      return value.map((v) => Map<String, dynamic>.from(v as Map)).toList();
    }

    if (data['through'] != through || data['currency'] != 'USD') invalid();
    for (final key in [
      'assetsMinor',
      'netBalanceMinor',
      'incomeMinor',
      'expenseMinor',
      'netIncomeMinor',
    ]) {
      if (!integer(data[key])) invalid();
    }
    for (final key in [
      'recordedCount',
      'futureCount',
      'spendingCategoryCount',
    ]) {
      if (!integer(data[key], min: 0)) invalid();
    }
    final accounts = rows('accounts', 1000),
        recent = rows('recent', 8),
        categories = rows('spendingCategories', 6);
    final ids = <String>{};
    for (final a in accounts) {
      if (!id(a['id']) ||
          !ids.add(a['id'] as String) ||
          !text(a['name'], 100) ||
          !text(a['type'], 30) ||
          a['archived'] is! bool ||
          !integer(a['balanceMinor'])) {
        invalid();
      }
    }
    final entryIds = <String>{};
    for (final e in recent) {
      final date = e['date'];
      if (!id(e['id']) ||
          !entryIds.add(e['id'] as String) ||
          !ids.contains(e['accountId']) ||
          !id(e['counterpartyAccountId']) ||
          !text(e['accountName'], 100) ||
          !text(e['counterpartyName'], 100) ||
          !{'income', 'expense', 'transfer', 'opening'}.contains(e['kind']) ||
          !integer(e['amountMinor']) ||
          e['payee'] is! String ||
          (e['payee'] as String).length > 150 ||
          date is! String ||
          DateTime.tryParse(date)?.toIso8601String().substring(0, 10) != date ||
          date.compareTo(through) > 0) {
        invalid();
      }
    }
    final categoryIds = <String>{};
    for (final c in categories) {
      if (!id(c['id']) ||
          !categoryIds.add(c['id'] as String) ||
          !text(c['name'], 100) ||
          !integer(c['amountMinor']) ||
          !integer(c['entryCount'], min: 1)) {
        invalid();
      }
    }
    if (categories.length > (data['spendingCategoryCount'] as int) ||
        recent.length > (data['recordedCount'] as int)) {
      invalid();
    }
    final bank = Map<String, dynamic>.from(data['bank'] as Map);
    if (!{
      'ready',
      'disabled',
      'storage-unavailable',
    }.contains(bank['status'])) {
      invalid();
    }
    if (bank['status'] == 'ready') {
      if (bank['needsReviewCount'] is! int ||
          bank['totalSources'] is! int ||
          (bank['needsReviewCount'] as int) > (bank['totalSources'] as int)) {
        invalid();
      }
      ServerBankState.parse({
        'storageReady': true,
        'connection': bank['connection'],
        'accounts': bank['accounts'],
        'sources': [],
        'totalSources': bank['totalSources'],
        'needsReviewCount': bank['needsReviewCount'],
        'hasMore': false,
      });
    } else if (bank['needsReviewCount'] != null ||
        bank['totalSources'] != null ||
        bank['connection'] != null ||
        bank['accounts'] is! List ||
        (bank['accounts'] as List).isNotEmpty) {
      invalid();
    }
    return ServerDashboard._(data);
  }
}
