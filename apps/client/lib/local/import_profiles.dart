part of 'ledger.dart';

/// Encrypted, explicitly saved CSV settings. Never contains statement rows,
/// filenames, account selection, duplicate decisions or a transaction action.
class ImportProfiles {
  static const maxProfiles = 100;
  static const columnFields = ['date', 'payee', 'amount', 'debit', 'credit', 'reference', 'notes'];
  static const settingFields = ['delimiter', 'dateFormat', 'amountMode', 'reverseSign',
    'columns', 'expenseCategoryId', 'incomeCategoryId'];
  static String headerKey(String value) => value.trim().toLowerCase();

  static List<Json> list(Json data, {bool includeArchived = false}) {
    final result = LocalLedger.rows(data['importProfiles'] ?? <Json>[]).map(LocalLedger.clone)
        .where((p) => includeArchived || p['archived'] == false).toList();
    result.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    return result;
  }

  static Json settings(Object? value, List<Json> categories) {
    if (value is! Map || value.length != settingFields.length ||
        value.keys.any((k) => !settingFields.contains(k))) {
      LocalLedger.fail('Invalid CSV profile settings.');
    }
    final s = LocalLedger.clone(Map<String, dynamic>.from(value));
    if (![',', ';', '\t'].contains(s['delimiter']) || !['ymd', 'mdy', 'dmy'].contains(s['dateFormat']) ||
        !['signed', 'separate'].contains(s['amountMode']) || s['reverseSign'] is! bool ||
        (s['amountMode'] == 'separate' && s['reverseSign'] == true)) {
      LocalLedger.fail('Choose a supported separator, date format and amount mode.');
    }
    final raw = s['columns'];
    if (raw is! Map || raw.length != columnFields.length || raw.keys.any((k) => !columnFields.contains(k))) {
      LocalLedger.fail('Invalid CSV profile columns.');
    }
    final columns = Map<String, dynamic>.from(raw);
    final required = {'date', 'payee', if (s['amountMode'] == 'signed') 'amount' else ...['debit', 'credit']};
    final inactive = s['amountMode'] == 'signed' ? ['debit', 'credit'] : ['amount'];
    final used = <String>{};
    for (final field in columnFields) {
      final label = columns[field];
      if (label == null && !required.contains(field)) continue;
      final text = LocalLedger.text(label, 'CSV column header', 100);
      if (inactive.contains(field) || text != label || !used.add(headerKey(text))) {
        LocalLedger.fail('Each profile field must use a different, unambiguous CSV header.');
      }
    }
    for (final pair in {'expenseCategoryId': 'Expense', 'incomeCategoryId': 'Income'}.entries) {
      final id = s[pair.key];
      if (id != null && (id is! String || !categories.any((c) =>
          c['id'] == id && c['kind'] == pair.value && c['currency'] == 'USD'))) {
        LocalLedger.fail('Choose an existing ${pair.value.toLowerCase()} default category.');
      }
    }
    return s;
  }

  static void _revision(Json next, Json input) {
    if (input['expectedRevision'] != next['revision']) {
      LocalLedger.fail('Workspace changed. Refresh the import profiles before saving.');
    }
  }
  static Json save(Json next, Json input, String id, String operation) {
    _revision(next, input);
    final profiles = list(next, includeArchived: true);
    final index = profiles.indexWhere((p) => p['id'] == id);
    if (input['id'] != null && index < 0) LocalLedger.fail('Import profile was not found.');
    final before = index < 0 ? null : profiles[index];
    if (before != null && (input['expectedVersion'] != before['version'] || before['archived'] == true)) {
      LocalLedger.fail('Profile changed or is archived. Refresh, or restore it before editing.');
    }
    final name = LocalLedger.text(input['name'], 'Profile name', 80);
    if (profiles.any((p) => p['id'] != id && (p['name'] as String).toLowerCase() == name.toLowerCase())) {
      LocalLedger.fail('A profile already uses this name, including archived profiles.');
    }
    if (before == null && profiles.length >= maxProfiles) LocalLedger.fail('This preview supports up to $maxProfiles import profiles.');
    final config = settings(input['settings'], LocalLedger.rows(next['categories']));
    if ((next['schema'] as int) < LocalLedger.importProfileSchema) {
      if (input['confirmProfileUpgrade'] != true) {
        LocalLedger.fail('Export a backup and confirm the import-profile format upgrade first.');
      }
      for (final key in ['budgets', 'schedules', 'occurrences', 'imports', 'reconciliations', 'categoryRules']) {
        next.putIfAbsent(key, () => <Json>[]);
      }
      next['schema'] = LocalLedger.importProfileSchema;
    }
    final after = <String, dynamic>{'id': id, 'name': name, 'settings': config,
      'version': (before?['version'] as int? ?? 0) + 1, 'archived': false, 'operationId': operation};
    if (index < 0) { profiles.add(after); } else { profiles[index] = after; }
    next['importProfiles'] = profiles;
    return after;
  }

  static Json setArchived(Json next, Json input, String id, String operation) {
    _revision(next, input);
    final profiles = list(next, includeArchived: true);
    final index = profiles.indexWhere((p) => p['id'] == id);
    if (index < 0) LocalLedger.fail('Import profile was not found.');
    final before = profiles[index];
    if (input['expectedVersion'] != before['version'] || input['archived'] is! bool ||
        input['archived'] == before['archived'] || input['confirmReviewed'] != true) {
      LocalLedger.fail('Review the current profile and confirm archiving or restoring it.');
    }
    final after = {...before, 'archived': input['archived'],
      'version': (before['version'] as int) + 1, 'operationId': operation};
    profiles[index] = after;
    next['importProfiles'] = profiles;
    return after;
  }

  static void validate(Json data, List<Json> categories, Set<String> ids) {
    if ((data['schema'] as int) < LocalLedger.importProfileSchema) {
      if (data.containsKey('importProfiles') &&
          (data['importProfiles'] is! List || (data['importProfiles'] as List).isNotEmpty)) {
        LocalLedger.fail('Saved import profiles require the upgraded workspace format.');
      }
      return;
    }
    if (data['importProfiles'] is! List || (data['importProfiles'] as List).length > maxProfiles ||
        (data['importProfiles'] as List).any((p) => p is! Map)) {
      LocalLedger.fail('Invalid saved import profiles.');
    }
    final names = <String>{};
    for (final p in LocalLedger.rows(data['importProfiles'])) {
      final name = LocalLedger.text(p['name'], 'Profile name', 80);
      if (!ids.add(LocalLedger.text(p['id'], 'Profile identifier', 100)) || name != p['name'] ||
          !names.add(name.toLowerCase()) || p['archived'] is! bool || p['version'] is! int || p['version'] < 1 ||
          p['operationId'] is! String || !(data['operations'] as Map).containsKey(p['operationId'])) {
        LocalLedger.fail('Invalid, duplicated or orphaned import profile.');
      }
      settings(p['settings'], categories);
    }
  }
}
