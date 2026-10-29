import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'csv_import.dart';
import 'ledger.dart';

/// A detached suggestion for an unsaved CSV row, never an existing transaction.
class CsvCategorySuggestion {
  const CsvCategorySuggestion({required this.rowNumber, required this.date,
    required this.payee, required this.signedMinor, required this.currentCategory,
    required this.categoryId, required this.categoryName, required this.ruleName,
    required this.ruleId, required this.ruleVersion, required this.priority});
  final int rowNumber, signedMinor, ruleVersion, priority;
  final String date, payee, currentCategory, categoryId, categoryName, ruleName, ruleId;
}

class CsvRuleReview {
  CsvRuleReview._(this.fingerprint, List<CsvCategorySuggestion> suggestions)
      : suggestions = List.unmodifiable(suggestions);
  final String fingerprint;
  final List<CsvCategorySuggestion> suggestions;
}

/// Uses saved rules only on explicit request. Acceptance changes detached import
/// choices, not the ledger. The existing import commit remains the only writer.
class CsvRuleSuggestions {
  static const maxSelection = 500;
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static CsvRuleReview preview({required Json snapshot, required String accountId,
      required String fileHash, required List<CsvEntry> entries,
      required Map<int, Json> choices, Set<int> reviewedRows = const {}}) {
    if (snapshot['cursor'] is! int || !RegExp(r'^[a-f0-9]{64}$').hasMatch(fileHash) ||
        !LocalLedger.rows(snapshot['accounts']).any((a) => a['id'] == accountId && a['currency'] == 'USD')) {
      throw const FormatException('Choose an existing account and regenerate the CSV preview.');
    }
    if (entries.length > CsvTable.maxRows) throw const FormatException('Too many CSV rows.');
    final rules = CategoryRules.ordered(snapshot);
    final categories = {for (final c in LocalLedger.rows(snapshot['categories'])) c['id']: c};
    final suggestions = <CsvCategorySuggestion>[], seen = <int>{};
    for (final entry in entries) {
      if (entry.rowNumber < 2 || !seen.add(entry.rowNumber)) {
        throw const FormatException('CSV row identities changed. Regenerate the preview.');
      }
      final row = entry.values, choice = choices[entry.rowNumber];
      if (row == null || entry.error != null || choice == null ||
          choice['action'] != 'create' || reviewedRows.contains(entry.rowNumber)) continue;
      if (row['rowNumber'] != entry.rowNumber) throw const FormatException('CSV row identity is inconsistent.');
      final amount = LocalLedger.minor(row['signedMinor'], signed: true);
      if (amount == 0) continue;
      final kind = amount < 0 ? 'expense' : 'income';
      // Never change type, transfer direction, duplicate approval or matching.
      if (choice['kind'] != kind || CsvImport.transferHint(row['payee'] as String) ||
          CsvImport.consumed(snapshot, accountId, fileHash, row)) continue;
      LocalLedger.date(row['date']);
      final payee = LocalLedger.text(row['payee'], 'Description', 150);
      final candidate = <String, dynamic>{'kind': kind, 'accountId': accountId,
        'counterpartyAccountId': choice['targetId'], 'amountMinor': amount.abs(), 'payee': payee};
      // These prospective entries are statement-sourced. Manual-only rules do
      // not match. First match wins even if it proposes the current category.
      final rule = rules.where((r) => CategoryRules.matches(r, candidate, true)).firstOrNull;
      if (rule == null || rule['categoryId'] == choice['targetId']) continue;
      final category = categories[rule['categoryId']];
      if (category == null || category['kind'] != (amount < 0 ? 'Expense' : 'Income')) {
        throw const FormatException('A rule category is unavailable. Refresh and review again.');
      }
      suggestions.add(CsvCategorySuggestion(rowNumber: entry.rowNumber,
        date: row['date'] as String, payee: payee, signedMinor: amount,
        currentCategory: categories[choice['targetId']]?['name'] as String? ?? 'No category',
        categoryId: category['id'] as String, categoryName: category['name'] as String,
        ruleName: rule['name'] as String, ruleId: rule['id'] as String,
        ruleVersion: rule['version'] as int, priority: rule['priority'] as int));
    }
    suggestions.sort((a, b) => a.rowNumber.compareTo(b.rowNumber));
    final numbers = choices.keys.toList()..sort();
    final reviewed = reviewedRows.toList()..sort();
    final fingerprint = sha256.convert(utf8.encode(jsonEncode(_canonical({
      'revision': snapshot['cursor'], 'account': accountId, 'file': fileHash,
      'rules': rules, 'categories': snapshot['categories'], 'imports': snapshot['imports'],
      'rows': [for (final e in entries) {'number': e.rowNumber, 'values': e.values, 'error': e.error}],
      'choices': {for (final n in numbers) '$n': choices[n]}, 'reviewed': reviewed,
    })))).toString();
    return CsvRuleReview._(fingerprint, suggestions);
  }

  /// Re-derives proposals against current data. Returns selected replacements;
  /// callers must retain all unselected choices and explicitly import later.
  static Map<int, Json> accept({required CsvRuleReview review, required Json snapshot,
      required String accountId, required String fileHash, required List<CsvEntry> entries,
      required Map<int, Json> choices, required List<int> selectedRows,
      required bool confirmed, Set<int> reviewedRows = const {}}) {
    if (!confirmed || selectedRows.isEmpty || selectedRows.length > maxSelection ||
        selectedRows.toSet().length != selectedRows.length) {
      throw const FormatException('Select and review between 1 and 500 category suggestions.');
    }
    final current = preview(snapshot: snapshot, accountId: accountId, fileHash: fileHash,
      entries: entries, choices: choices, reviewedRows: reviewedRows);
    if (current.fingerprint != review.fingerprint) {
      throw const FormatException('Workspace or import choices changed. Close suggestions and preview the CSV again.');
    }
    final proposals = {for (final p in current.suggestions) p.rowNumber: p};
    if (selectedRows.any((n) => !proposals.containsKey(n))) {
      throw const FormatException('A selected row no longer has a category suggestion.');
    }
    return {for (final n in selectedRows) n: {
      ...LocalLedger.clone(choices[n]!), 'targetId': proposals[n]!.categoryId,
    }};
  }
}
