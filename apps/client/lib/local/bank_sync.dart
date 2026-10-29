part of 'ledger.dart';

/// Provider-neutral, detached mutations. Only the fictional adapter is enabled.
/// Source changes and their checkpoint commit together; review is a separate,
/// explicit ledger operation. No IO, credentials, timers or inferred deletions.
class BankSync {
  static const simulatedProvider = 'budgetism-fictional-v1';
  static const collections = ['bankConnections', 'bankAccounts', 'bankSources', 'bankBatches'];
  static const sourceFields = [
    'sourceAccountId',
    'sourceId',
    'revision',
    'state',
    'signedMinor',
    'currency',
    'date',
    'description',
    'pendingSourceId',
    'transferKey',
  ];
  static List<Json> list(Json data, String key) => LocalLedger.rows(data[key] ?? <Json>[]);
  static Never fail(String message) => LocalLedger.fail(message);
  static String digest(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(LocalLedger._canonical(value)))).toString();
  static String batchDigest(Map batch) => digest({
    ...batch,
    for (final key in ['records', 'balances'])
      key: batch[key] is List ? ((batch[key] as List).map(digest).toSet().toList()..sort()) : batch[key],
  });
  static String sourceKey(String connection, String account, String source) => digest([connection, account, source]);
  static Json payload(Json source) => {for (final key in sourceFields) key: source[key]};
  static String timestamp(Object? value) {
    final text = LocalLedger.text(value, 'Data timestamp', 40);
    final parsed = DateTime.tryParse(text);
    if (!text.endsWith('Z') || parsed == null || !parsed.isUtc) fail('Use a valid UTC data timestamp.');
    return text;
  }

  static void _revision(Json data, Json input) {
    if (input['expectedRevision'] != data['revision']) fail('Workspace changed. Refresh and review again.');
  }

  static Json connection(Json data, Object? id) =>
      list(data, 'bankConnections').where((c) => c['id'] == id).firstOrNull ?? (fail('Connection was not found.'));
  static Json accountLink(Json data, Json source) => list(
    data,
    'bankAccounts',
  ).firstWhere((a) => a['connectionId'] == source['connectionId'] && a['sourceAccountId'] == source['sourceAccountId']);
  static int effect(Json transaction, String accountId) => LocalLedger.rows(
    transaction['postings'],
  ).where((p) => p['ledgerId'] == accountId).fold<int>(0, (sum, p) => sum + (p['amountMinor'] as int));

  static bool isReplay(Json data, Json input) {
    final batch = input['batch'];
    if (batch is! Map) return false;
    final c = connection(data, input['connectionId']);
    if (c['connected'] != true) fail('Reconnect the simulation before refreshing.');
    final existing =
        list(
          data,
          'bankBatches',
        ).where((b) => b['connectionId'] == c['id'] && b['batchId'] == batch['batchId']).firstOrNull;
    if (existing == null) return false;
    if (existing['digest'] != batchDigest(batch)) fail('A retrieved batch identity changed. Nothing was committed.');
    return true;
  }

  static Json apply(
    Json next,
    String action,
    Json input,
    String operation,
    List<Json> accounts,
    List<Json> categories,
    List<Json> transactions,
  ) {
    _revision(next, input);
    if (action == 'bank-connect') return _connect(next, input, operation, accounts);
    if ((next['schema'] as int) < LocalLedger.bankSchema) fail('Set up the fictional connection first.');
    if (action == 'bank-review') return _review(next, input, operation, accounts, categories, transactions);
    final connections = list(next, 'bankConnections');
    final index = connections.indexWhere((c) => c['id'] == input['connectionId']);
    if (index < 0) fail('Connection was not found.');
    final before = connections[index];
    Json after;
    if (action == 'bank-state') {
      if (input['confirmReviewed'] != true ||
          input['connected'] is! bool ||
          input['connected'] == before['connected']) {
        fail('Confirm disconnecting or reconnecting this simulation.');
      }
      after = {...before, 'connected': input['connected'], 'refreshStatus': 'idle', 'errorCode': null};
    } else {
      if (before['connected'] != true) fail('Reconnect the simulation before refreshing.');
      final now = timestamp(input['atUtc']);
      if (action == 'bank-failure') {
        if (!['interrupted', 'invalid-feed', 'save-failed'].contains(input['errorCode'])) {
          fail('Invalid refresh failure.');
        }
        after = {...before, 'lastAttemptUtc': now, 'refreshStatus': 'error', 'errorCode': input['errorCode']};
      } else if (action == 'bank-refresh') {
        after =
            isReplay(next, input)
                ? {
                  ...before,
                  'lastAttemptUtc': now,
                  'lastSuccessUtc': now,
                  'refreshStatus': 'success',
                  'errorCode': null,
                }
                : _refresh(next, input, operation, before, now);
      } else {
        fail('Unsupported bank operation.');
      }
    }
    after['version'] = (before['version'] as int) + 1;
    connections[index] = after;
    next['bankConnections'] = connections;
    return {'connectionBefore': before, 'connectionAfter': after};
  }

  static Json _connect(Json next, Json input, String operation, List<Json> accounts) {
    if (input['providerId'] != simulatedProvider ||
        input['confirmFictional'] != true ||
        input['confirmReviewed'] != true) {
      fail('Only the fictional simulation is available. Confirm that all selected accounts are for fictional testing.');
    }
    if ((next['schema'] as int) < LocalLedger.bankSchema && input['confirmBankUpgrade'] != true) {
      fail('Export a backup and confirm the bank-source format upgrade first. Older builds cannot open it.');
    }
    final connections = list(next, 'bankConnections');
    // A single reusable simulation avoids accidentally duplicating its history.
    if (connections.any((c) => c['providerId'] == simulatedProvider)) {
      fail('The simulation already exists. Reconnect it instead.');
    }
    final raw = input['accounts'];
    if (raw is! List || raw.isEmpty || raw.length > 20 || raw.any((a) => a is! Map)) {
      fail('Review the account mapping.');
    }
    final links = list(next, 'bankAccounts');
    final sourceIds = <String>{};
    final targetIds = links.map((a) => a['accountId']).toSet();
    final connectionId = const Uuid().v4();
    final newAccounts = <Json>[];
    for (final mapping in LocalLedger.rows(raw)) {
      final sourceId = LocalLedger.text(mapping['sourceAccountId'], 'Source account identity', 100);
      final name = LocalLedger.text(mapping['name'], 'Fictional account name', 100);
      if (!sourceIds.add(sourceId) ||
          mapping['currency'] != 'USD' ||
          !LocalLedger.accountTypes.contains(mapping['type'])) {
        fail('Account identities must be unique and use a supported USD account type.');
      }
      LocalLedger.date(mapping['historyFrom']);
      final baseline = LocalLedger.minor(mapping['openingBalanceMinor'], signed: true);
      Json account;
      if (mapping['accountId'] == null) {
        if (accounts.any((a) => (a['name'] as String).toLowerCase() == name.toLowerCase())) {
          fail('An account already uses this name. Map the existing fictional account instead.');
        }
        account = {
          'id': const Uuid().v4(),
          'name': name,
          'type': mapping['type'],
          'currency': 'USD',
          'openingBalanceMinor': baseline,
          'version': 1,
          'archived': false,
        };
        accounts.add(account);
        newAccounts.add(account);
      } else {
        account =
            accounts.where((a) => a['id'] == mapping['accountId']).firstOrNull ??
            (fail('The selected account no longer exists.'));
        if (account['type'] != mapping['type'] ||
            account['currency'] != mapping['currency'] ||
            account['archived'] == true) {
          fail('Match the account type and currency to an active fictional account.');
        }
      }
      if (!targetIds.add(account['id'])) fail('Each account can be linked only once.');
      links.add({
        'id': const Uuid().v4(),
        'connectionId': connectionId,
        'sourceAccountId': sourceId,
        'name': name,
        'type': mapping['type'],
        'currency': 'USD',
        'accountId': account['id'],
        'historyFrom': mapping['historyFrom'],
        'openingBalanceMinor': baseline,
        'reportedBalanceMinor': null,
        'availableBalanceMinor': null,
        'dataTimestampUtc': null,
      });
    }
    for (final key in [
      'budgets',
      'schedules',
      'occurrences',
      'imports',
      'reconciliations',
      'categoryRules',
      'importProfiles',
      ...collections,
    ]) {
      next.putIfAbsent(key, () => <Json>[]);
    }
    final c = <String, dynamic>{
      'id': connectionId,
      'providerId': simulatedProvider,
      'institution': 'Fictional Orchard Bank',
      'connected': true,
      'checkpoint': '',
      'version': 1,
      'lastAttemptUtc': null,
      'lastSuccessUtc': null,
      'dataTimestampUtc': null,
      'refreshStatus': 'idle',
      'errorCode': null,
      'operationId': operation,
    };
    next.addAll({
      'schema': LocalLedger.bankSchema,
      'bankConnections': [...connections, c],
      'bankAccounts': links,
    });
    return {'connection': c, 'newAccounts': newAccounts, 'links': links};
  }

  static void _sourcePayload(Json source) {
    if (source.length != sourceFields.length || source.keys.any((k) => !sourceFields.contains(k))) {
      fail('Unsupported source record fields.');
    }
    for (final key in ['sourceAccountId', 'sourceId']) {
      LocalLedger.text(source[key], 'Source identity', 100);
    }
    if (source['revision'] is! int ||
        source['revision'] < 1 ||
        source['revision'] > 2147483647 ||
        !['pending', 'posted', 'removed'].contains(source['state']) ||
        source['currency'] != 'USD') {
      fail('Unsupported source revision, currency or state.');
    }
    if (LocalLedger.minor(source['signedMinor'], signed: true) == 0) fail('A source amount cannot be zero.');
    LocalLedger.date(source['date']);
    LocalLedger.text(source['description'], 'Source description', 150);
    for (final key in ['pendingSourceId', 'transferKey']) {
      if (source[key] != null) LocalLedger.text(source[key], 'Source relationship', 100);
    }
    if (source['pendingSourceId'] == source['sourceId'] ||
        (source['pendingSourceId'] != null && source['state'] == 'pending')) {
      fail('Invalid pending relationship.');
    }
  }

  static Json _refresh(Json next, Json input, String operation, Json before, String now) {
    final value = input['batch'];
    if (value is! Map) fail('Missing complete source batch.');
    final batch = Map<String, dynamic>.from(value);
    final batchId = LocalLedger.text(batch['batchId'], 'Batch identity', 100);
    final checkpoint = LocalLedger.text(batch['checkpoint'], 'Sync checkpoint', 200);
    final stamp = timestamp(batch['dataTimestampUtc']);
    if (batch['complete'] != true ||
        batch['fromCheckpoint'] != before['checkpoint'] ||
        (before['dataTimestampUtc'] != null &&
            DateTime.parse(stamp).isBefore(DateTime.parse(before['dataTimestampUtc'] as String)))) {
      fail('Incomplete, stale or out-of-order refresh. Retry from the saved checkpoint.');
    }
    if (batch['records'] is! List ||
        (batch['records'] as List).length > 2000 ||
        (batch['records'] as List).any((r) => r is! Map) ||
        batch['balances'] is! List ||
        (batch['balances'] as List).length > 100 ||
        (batch['balances'] as List).any((r) => r is! Map)) {
      fail('Invalid or oversized source batch.');
    }
    final links = list(next, 'bankAccounts');
    final mine = {for (final a in links.where((a) => a['connectionId'] == before['id'])) a['sourceAccountId']: a};
    final sources = list(next, 'bankSources');
    final byId = {for (final s in sources) s['id']: s};
    final originals = {for (final s in sources) s['id']: LocalLedger.clone(s)};
    final events = LocalLedger.rows(batch['records'])..sort(
      (a, b) =>
          (a['revision'] is int && b['revision'] is int) ? (a['revision'] as int).compareTo(b['revision'] as int) : 0,
    );
    final eventVersions = <String, String>{};
    for (final record in events) {
      _sourcePayload(record);
      final link = mine[record['sourceAccountId']];
      if (link == null || (record['date'] as String).compareTo(link['historyFrom'] as String) < 0) {
        fail('Source record is outside the reviewed account/history mapping.');
      }
      final id = sourceKey(before['id'] as String, record['sourceAccountId'] as String, record['sourceId'] as String);
      final eventKey = '$id/${record['revision']}';
      final content = digest(record);
      if (eventVersions.containsKey(eventKey) && eventVersions[eventKey] != content) {
        fail('Conflicting source revisions in the same refresh.');
      }
      eventVersions[eventKey] = content;
      final old = byId[id];
      if (old != null) {
        if (record['revision'] < old['revision']) continue;
        if (record['revision'] == old['revision']) {
          if (digest(payload(old)) != content) fail('Source content changed without a new revision.');
          continue;
        }
        if (old['state'] == 'posted' && record['state'] == 'pending') fail('A posted record cannot return to pending.');
        if (old['pendingSourceId'] != record['pendingSourceId']) fail('A durable pending relationship cannot change.');
        if (old['supersededBy'] != null && record['state'] == 'posted') {
          fail('A replaced authorization cannot post again.');
        }
      }
      final after = <String, dynamic>{
        ...?(old),
        ...record,
        'id': id,
        'connectionId': before['id'],
        'transactionId': old?['transactionId'],
        'reviewedRevision': old?['reviewedRevision'] ?? 0,
        'decision': old?['decision'],
        'supersededBy': old?['supersededBy'],
        'scheduleDismissedRevision': old?['scheduleDismissedRevision'] ?? 0,
      };
      byId[id] = after;
    }
    // Link after all pages have been assembled, independent of response order.
    for (final source in byId.values.where((s) => s['connectionId'] == before['id'] && s['pendingSourceId'] != null)) {
      final predecessorId = sourceKey(
        before['id'] as String,
        source['sourceAccountId'] as String,
        source['pendingSourceId'] as String,
      );
      final predecessor = byId[predecessorId];
      // Providers may omit a historical authorization. Retain its explicit ID.
      if (predecessor == null) continue;
      if (predecessor['state'] == 'posted' ||
          predecessor['transactionId'] != null ||
          (predecessor['supersededBy'] != null && predecessor['supersededBy'] != source['id'])) {
        fail('Conflicting pending-to-posted identity. Review the feed before retrying.');
      }
      predecessor['supersededBy'] = source['id'];
    }
    final balanced = <String>{};
    for (final balance in LocalLedger.rows(batch['balances'])) {
      final link = mine[balance['sourceAccountId']];
      if (link == null || balance['currency'] != 'USD' || !balanced.add(balance['sourceAccountId'] as String)) {
        fail('Invalid, duplicated or unmapped reported balance.');
      }
      LocalLedger.minor(balance['reportedBalanceMinor'], signed: true);
      if (balance['availableBalanceMinor'] != null) LocalLedger.minor(balance['availableBalanceMinor'], signed: true);
      link.addAll({
        'reportedBalanceMinor': balance['reportedBalanceMinor'],
        'availableBalanceMinor': balance['availableBalanceMinor'],
        'dataTimestampUtc': stamp,
      });
    }
    // Map values and list rows are detached copies; explicitly replace the rows.
    next['bankAccounts'] = [
      for (final link in links) link['connectionId'] == before['id'] ? mine[link['sourceAccountId']]! : link,
    ];
    next['bankSources'] = byId.values.toList();
    next['bankBatches'] = [
      ...list(next, 'bankBatches'),
      {
        'id': const Uuid().v4(),
        'connectionId': before['id'],
        'batchId': batchId,
        'fromCheckpoint': batch['fromCheckpoint'],
        'checkpoint': checkpoint,
        'digest': batchDigest(batch),
        'operationId': operation,
      },
    ];
    // Include source before/after evidence in the ordinary encrypted audit.
    final changed = <Json>[
      for (final source in byId.values)
        if (digest(originals[source['id']]) != digest(source)) {'before': originals[source['id']], 'after': source},
    ];
    next['audit'] = [
      ...LocalLedger.rows(next['audit']),
      {'action': 'bank-source-batch', 'operationId': operation, 'atUtc': now, 'changes': changed},
    ];
    return {
      ...before,
      'checkpoint': checkpoint,
      'dataTimestampUtc': stamp,
      'lastAttemptUtc': now,
      'lastSuccessUtc': now,
      'refreshStatus': 'success',
      'errorCode': null,
    };
  }

  static List<Json> duplicateCandidates(Json data, Json source) {
    final account = accountLink(data, source)['accountId'] as String;
    final used =
        list(data, 'bankSources')
            .where(
              (s) =>
                  s['id'] != source['id'] &&
                  s['sourceAccountId'] == source['sourceAccountId'] &&
                  s['connectionId'] == source['connectionId'] &&
                  s['supersededBy'] == null &&
                  s['transactionId'] != null,
            )
            .map((s) => s['transactionId'])
            .toSet();
    return list(data, 'transactions')
        .where(
          (t) =>
              t['voided'] == false &&
              !used.contains(t['id']) &&
              t['effectiveDate'] == source['date'] &&
              effect(t, account) == source['signedMinor'],
        )
        .toList();
  }

  static List<Json> transferCandidates(Json data, Json source) {
    if (source['state'] != 'posted') return [];
    return list(data, 'bankSources')
        .where(
          (s) =>
              s['id'] != source['id'] &&
              s['connectionId'] == source['connectionId'] &&
              s['sourceAccountId'] != source['sourceAccountId'] &&
              s['state'] == 'posted' &&
              s['transactionId'] == null &&
              s['supersededBy'] == null &&
              s['reviewedRevision'] != s['revision'] &&
              s['signedMinor'] == -(source['signedMinor'] as int) &&
              ScheduleMatching.daysApart(source['date'] as String, s['date'] as String) <= 3 &&
              (source['transferKey'] == null || s['transferKey'] == source['transferKey']),
        )
        .toList();
  }

  static List<Json> pendingCandidates(Json data, Json source) =>
      list(data, 'bankSources')
          .where(
            (s) =>
                s['id'] != source['id'] &&
                s['connectionId'] == source['connectionId'] &&
                s['sourceAccountId'] == source['sourceAccountId'] &&
                s['state'] == 'pending' &&
                s['supersededBy'] == null &&
                (s['description'] as String).toLowerCase() == (source['description'] as String).toLowerCase() &&
                ScheduleMatching.daysApart(source['date'] as String, s['date'] as String) <= 7,
          )
          .toList();

  static List<Json> scheduleCandidates(Json data, Json source) {
    if (source['state'] != 'posted' || source['scheduleDismissedRevision'] == source['revision']) return [];
    final linked = list(data, 'transactions').where((t) => t['id'] == source['transactionId']).firstOrNull;
    if (linked != null && (linked['voided'] == true || linked.containsKey('scheduleId'))) return [];
    final signed = source['signedMinor'] as int;
    final candidate =
        linked ??
        <String, dynamic>{
          'voided': false,
          'currency': 'USD',
          'kind':
              source['transferKey'] != null
                  ? 'transfer'
                  : signed < 0
                  ? 'expense'
                  : 'income',
          'accountId': accountLink(data, source)['accountId'],
          'amountMinor': signed.abs(),
        };
    final day = Recurrence.parse(source['date']);
    final result = <Json>[];
    for (final schedule in list(data, 'schedules')) {
      if (schedule['paused'] == true ||
          !ScheduleMatching.eligible(schedule, candidate) ||
          schedule['amountMinor'] != candidate['amountMinor']) {
        continue;
      }
      final high = day.add(const Duration(days: 7));
      final low = day.subtract(const Duration(days: 7));
      final through = high.year > 9999 ? '9999-12-31' : Recurrence.format(high);
      final from = low.year < 1900 ? '1900-01-01' : Recurrence.format(low);
      final first = Recurrence.lastIndex(schedule['startDate'], schedule['frequency'], from);
      final last = Recurrence.lastIndex(schedule['startDate'], schedule['frequency'], through);
      final records = list(data, 'occurrences').where((o) => o['scheduleId'] == schedule['id']).toList();
      final indices = <int>{
        for (var i = first < 0 ? 0 : first; i <= last; i++) i,
        ...records.where((o) => o['status'] == 'postponed').map((o) => o['index'] as int),
      };
      for (final index in indices) {
        final original = Recurrence.at(schedule['startDate'], schedule['frequency'], index);
        if (original == null || (schedule['endDate'] != null && original.compareTo(schedule['endDate'] as String) > 0)) {
          continue;
        }
        final record = records.where((o) => o['index'] == index).firstOrNull;
        final due = record?['dueDate'] as String? ?? original;
        if ((record != null && record['status'] != 'postponed') || ScheduleMatching.daysApart(due, source['date']) > 7) {
          continue;
        }
        result.add({
          'scheduleId': schedule['id'],
          'index': index,
          'name': schedule['name'],
          'dueDate': due,
          'expectedScheduleVersion': schedule['version'],
          'expectedOccurrenceVersion': record?['version'] ?? 0,
        });
      }
    }
    return result;
  }

  /// One read-only inbox combines all source exceptions and connection failures.
  static List<Json> inbox(Json data) {
    final result = <Json>[];
    for (final c in list(data, 'bankConnections').where((c) => c['refreshStatus'] == 'error')) {
      result.add({
        'id': 'connection:${c['id']}',
        'connectionId': c['id'],
        'reasons': ['connection_problem'],
      });
    }
    for (final source in list(data, 'bankSources')) {
      if (source['supersededBy'] != null || source['state'] == 'pending') continue;
      final linked = list(data, 'transactions').where((t) => t['id'] == source['transactionId']).firstOrNull;
      final reasons = <String>[];
      if (source['reviewedRevision'] != source['revision']) {
        if (linked != null) {
          reasons.add(source['state'] == 'removed' ? 'bank_removal' : 'bank_correction');
          if (Reconciliation.locked(data, linked['id'])) reasons.add('reconciliation_conflict');
          if (linked['voided'] == true) reasons.add('recorded_entry_voided');
        } else if (source['state'] == 'posted') {
          reasons.add('category_needed');
          if (duplicateCandidates(data, source).isNotEmpty) reasons.add('potential_duplicate');
          if (pendingCandidates(data, source).isNotEmpty && source['pendingSourceId'] == null) {
            reasons.add('pending_ambiguity');
          }
          if (source['transferKey'] != null ||
              transferCandidates(data, source).isNotEmpty ||
              RegExp(r'transfer|payment', caseSensitive: false).hasMatch(source['description'])) {
            reasons.add('possible_transfer');
          }
        }
      }
      if (source['decision'] != 'ignored' && scheduleCandidates(data, source).isNotEmpty) {
        reasons.add('scheduled_match');
      }
      if (reasons.isNotEmpty) result.add({'id': source['id'], 'source': source, 'reasons': reasons});
    }
    return result;
  }

  static Json _review(
    Json next,
    Json input,
    String operation,
    List<Json> accounts,
    List<Json> categories,
    List<Json> transactions,
  ) {
    if (input['confirmReviewed'] != true) fail('Review and confirm this decision.');
    final sources = list(next, 'bankSources');
    final originals = {for (final s in sources) s['id']: LocalLedger.clone(s)};
    final index = sources.indexWhere((s) => s['id'] == input['sourceId']);
    if (index < 0) fail('Source record was not found.');
    final source = sources[index];
    final before = LocalLedger.clone(source);
    if (input['expectedSourceRevision'] != source['revision'] ||
        source['supersededBy'] != null ||
        source['state'] == 'pending') {
      fail('Source changed or is still pending. Refresh the review inbox.');
    }
    final decision = input['decision'];
    final transactionIndex = transactions.indexWhere((t) => t['id'] == source['transactionId']);
    final oldTransaction = transactionIndex < 0 ? null : transactions[transactionIndex];
    final linkedSources =
        sources
            .where(
              (s) =>
                  s['transactionId'] != null &&
                  s['transactionId'] == source['transactionId'] &&
                  s['supersededBy'] == null,
            )
            .toList();
    final accountId = accountLink(next, source)['accountId'] as String;
    final amount = (source['signedMinor'] as int).abs();
    final kind = (source['signedMinor'] as int) < 0 ? 'expense' : 'income';
    Json? afterTransaction;
    if (['record', 'transfer', 'match'].contains(decision)) {
      if (source['transactionId'] != null ||
          source['state'] != 'posted' ||
          source['reviewedRevision'] == source['revision']) {
        fail('This source has already been handled or is not posted.');
      }
      if (decision == 'match') {
        final match = duplicateCandidates(next, source).where((t) => t['id'] == input['transactionId']).firstOrNull;
        if (match == null || match['version'] != input['expectedTransactionVersion']) {
          fail('Choose a current exact-date, exact-amount existing entry.');
        }
        source['transactionId'] = match['id'];
        afterTransaction = match;
      } else {
        if (duplicateCandidates(next, source).isNotEmpty && input['confirmDuplicate'] != true) {
          fail('Review possible duplicates before recording a separate entry.');
        }
        if (pendingCandidates(next, source).isNotEmpty &&
            source['pendingSourceId'] == null &&
            input['confirmPending'] != true) {
          fail(
            'Review the ambiguous pending authorization. It will remain pending until the feed identifies or removes it.',
          );
        }
        if (decision == 'record' && source['transferKey'] != null && input['confirmSeparate'] != true) {
          fail('Review the transfer hint before treating this as income or spending.');
        }
        String from = accountId;
        String to = LocalLedger.text(
          input['categoryId'] ?? input['otherAccountId'] ?? '',
          'Category or destination',
          100,
          optional: true,
        );
        Json? pair;
        if (decision == 'transfer') {
          if (input['otherSourceId'] != null) {
            pair = transferCandidates(next, source).where((s) => s['id'] == input['otherSourceId']).firstOrNull;
            if (pair == null || pair['revision'] != input['expectedOtherSourceRevision']) {
              fail('Review both current transfer sides.');
            }
            if (duplicateCandidates(next, pair).isNotEmpty && input['confirmDuplicate'] != true) {
              fail(
                'The other transfer side may already be recorded. Review both sides before creating a separate transfer.',
              );
            }
            to = accountLink(next, pair)['accountId'] as String;
          }
          if ((source['signedMinor'] as int) > 0) {
            final destination = from;
            from = to;
            to = destination;
          }
        }
        afterTransaction = {
          'id': const Uuid().v4(),
          'operationId': operation,
          'kind': decision == 'transfer' ? 'transfer' : kind,
          'accountId': from,
          'counterpartyAccountId': to,
          'amountMinor': amount,
          'currency': 'USD',
          'effectiveDate': source['date'],
          'payee': source['description'],
          'notes': LocalLedger.text(input['notes'] ?? '', 'Notes', 500, optional: true),
          'splits': <Json>[],
          'voided': false,
          'version': 1,
          'createdUtc': DateTime.now().toUtc().toIso8601String(),
        };
        afterTransaction['postings'] = LocalLedger.postingsFor(afterTransaction, accounts, categories);
        transactions.add(afterTransaction);
        source['transactionId'] = afterTransaction['id'];
        if (pair != null) {
          final pairIndex = sources.indexWhere((s) => s['id'] == pair!['id']);
          sources[pairIndex] = {
            ...sources[pairIndex],
            'transactionId': afterTransaction['id'],
            'reviewedRevision': pair['revision'],
            'decision': 'transfer',
          };
        }
      }
    } else if (decision == 'correct' || decision == 'remove') {
      if (oldTransaction == null ||
          oldTransaction['version'] != input['expectedTransactionVersion'] ||
          oldTransaction['voided'] == true) {
        fail('The linked entry changed or is voided. Review it again.');
      }
      if (Reconciliation.locked(next, oldTransaction['id'])) {
        fail('Reopen every relevant statement before changing this reconciled entry.');
      }
      if (source['reviewedRevision'] == source['revision']) fail('This source revision was already reviewed.');
      if (decision == 'remove') {
        if (source['state'] != 'removed' || linkedSources.any((s) => s['state'] != 'removed')) {
          fail('Every linked source side must explicitly report removal before voiding this entry.');
        }
        afterTransaction = {...oldTransaction, 'voided': true, 'version': (oldTransaction['version'] as int) + 1};
      } else {
        if (source['state'] != 'posted') fail('Only a posted correction can replace a recorded value.');
        if (oldTransaction['kind'] != 'transfer' && oldTransaction['kind'] != kind) {
          fail('A correction cannot silently change income to spending. Keep the recorded entry and review manually.');
        }
        if (LocalLedger.rows(oldTransaction['splits']).isNotEmpty && oldTransaction['amountMinor'] != amount) {
          fail('This entry has user splits. Edit their exact amounts in Transactions first, then review again.');
        }
        if (oldTransaction['kind'] == 'transfer' &&
            linkedSources.any(
              (s) =>
                  s['state'] != 'posted' ||
                  (s['signedMinor'] as int).abs() != amount ||
                  ((s['signedMinor'] as int) < 0) != (effect(oldTransaction, accountLink(next, s)['accountId']) < 0),
            )) {
          fail('Both transfer sides must agree on direction and amount before correcting the paired entry.');
        }
        afterTransaction = {
          ...oldTransaction,
          'amountMinor': amount,
          'effectiveDate': source['date'],
          'version': (oldTransaction['version'] as int) + 1,
        };
        // User payee, categories, splits, notes, operation and schedule links survive.
        afterTransaction['postings'] = LocalLedger.postingsFor(afterTransaction, accounts, categories);
      }
      transactions[transactionIndex] = afterTransaction;
      for (var i = 0; i < sources.length; i++) {
        if (linkedSources.any((s) => s['id'] == sources[i]['id'])) {
          sources[i] = {...sources[i], 'reviewedRevision': sources[i]['revision'], 'decision': decision};
        }
      }
    } else if (decision == 'schedule') {
      if (oldTransaction == null || oldTransaction['version'] != input['expectedTransactionVersion']) {
        fail('Review the current recorded payment first.');
      }
      final selected =
          scheduleCandidates(
            next,
            source,
          ).where((s) => s['scheduleId'] == input['scheduleId'] && s['index'] == input['index']).firstOrNull;
      if (selected == null) fail('This scheduled match is no longer available.');
      _ScheduleRules.apply(
        next,
        'schedule-match',
        {
          ...selected,
          'operationId': operation,
          'confirmMatch': true,
          'expectedRevision': next['revision'],
          'transactionId': oldTransaction['id'],
          'expectedTransactionVersion': oldTransaction['version'],
        },
        operation,
        accounts,
        categories,
        transactions,
      );
      afterTransaction = transactions[transactionIndex];
    } else if (decision == 'dismiss-schedule') {
      if (oldTransaction == null) fail('Record or match the source before dismissing its schedule suggestion.');
      source['scheduleDismissedRevision'] = source['revision'];
    } else if (decision == 'ignore' || decision == 'keep') {
      if (decision == 'ignore' && oldTransaction != null) fail('Use Keep recorded entry for an already linked source.');
      if (decision == 'keep' && oldTransaction == null) fail('There is no linked entry to keep.');
      if (LocalLedger.text(input['reason'], 'Review reason', 300).isEmpty) fail('Enter a review reason.');
    } else {
      fail('Choose a supported review decision.');
    }
    // Schedule-only decisions must not acknowledge an outstanding correction.
    if (!['schedule', 'dismiss-schedule'].contains(decision)) {
      source['reviewedRevision'] = source['revision'];
      source['decision'] = decision == 'ignore' ? 'ignored' : decision;
    }
    sources[index] = source;
    next['bankSources'] = sources;
    return {
      'sourceBefore': before,
      'sourceAfter': source,
      'sourceChanges': [
        for (final s in sources)
          if (digest(originals[s['id']]) != digest(s)) {'before': originals[s['id']], 'after': s},
      ],
      'transactionBefore': oldTransaction,
      'transactionAfter': afterTransaction,
      'reason': input['reason'],
      'decision': decision,
    };
  }

  static void validate(Json data, List<Json> accounts, List<Json> transactions, Set<String> ids) {
    if ((data['schema'] as int) < LocalLedger.bankSchema) {
      for (final key in collections) {
        if (data.containsKey(key) && (data[key] is! List || (data[key] as List).isNotEmpty)) {
          fail('Bank records require the upgraded workspace format.');
        }
      }
      return;
    }
    for (final key in collections) {
      if (data[key] is! List || (data[key] as List).any((r) => r is! Map) || (data[key] as List).length > 50000) {
        fail('Invalid bank records.');
      }
      for (final record in list(data, key)) {
        if (!ids.add(LocalLedger.text(record['id'], 'Bank record identity', 100))) {
          fail('Duplicate bank record identity.');
        }
      }
    }
    final connections = list(data, 'bankConnections');
    if (connections.length > 1) fail('Only one fictional connection is supported.');
    for (final c in connections) {
      if (c['providerId'] != simulatedProvider ||
          c['institution'] != 'Fictional Orchard Bank' ||
          c['connected'] is! bool ||
          c['version'] is! int ||
          c['version'] < 1 ||
          !['idle', 'success', 'error'].contains(c['refreshStatus']) ||
          !(data['operations'] as Map).containsKey(c['operationId'])) {
        fail('Invalid simulated connection.');
      }
      LocalLedger.text(c['checkpoint'], 'Checkpoint', 200, optional: true);
      if ((c['refreshStatus'] == 'error') != (c['errorCode'] != null) ||
          (c['errorCode'] != null && !['interrupted', 'invalid-feed', 'save-failed'].contains(c['errorCode']))) {
        fail('Invalid refresh status.');
      }
      for (final key in ['lastAttemptUtc', 'lastSuccessUtc', 'dataTimestampUtc']) {
        if (c[key] != null) timestamp(c[key]);
      }
      if ((c['checkpoint'] == '') != (c['lastSuccessUtc'] == null) ||
          (c['lastSuccessUtc'] == null) != (c['dataTimestampUtc'] == null)) {
        fail('Invalid success checkpoint.');
      }
    }
    final links = list(data, 'bankAccounts');
    final linkKeys = <String>{}, accountIds = <String>{};
    for (final a in links) {
      final account = accounts.where((r) => r['id'] == a['accountId']).firstOrNull;
      LocalLedger.text(a['sourceAccountId'], 'Source account', 100);
      LocalLedger.text(a['name'], 'Source account name', 100);
      LocalLedger.date(a['historyFrom']);
      LocalLedger.minor(a['openingBalanceMinor'], signed: true);
      if (!connections.any((c) => c['id'] == a['connectionId']) ||
          account == null ||
          account['currency'] != a['currency'] ||
          account['type'] != a['type'] ||
          !accountIds.add(a['accountId'] as String) ||
          !linkKeys.add('${a['connectionId']}/${a['sourceAccountId']}')) {
        fail('Invalid or duplicated account link.');
      }
      for (final key in ['reportedBalanceMinor', 'availableBalanceMinor']) {
        if (a[key] != null) LocalLedger.minor(a[key], signed: true);
      }
      if (a['dataTimestampUtc'] != null) timestamp(a['dataTimestampUtc']);
      if ((a['reportedBalanceMinor'] == null) != (a['dataTimestampUtc'] == null)) {
        fail('Reported balance needs its timestamp.');
      }
    }
    final sources = list(data, 'bankSources');
    final linkedSides = <String>{};
    for (final s in sources) {
      _sourcePayload(payload(s));
      if (s['id'] != sourceKey(s['connectionId'], s['sourceAccountId'], s['sourceId']) ||
          !linkKeys.contains('${s['connectionId']}/${s['sourceAccountId']}') ||
          s['reviewedRevision'] is! int ||
          s['reviewedRevision'] < 0 ||
          s['reviewedRevision'] > s['revision'] ||
          s['scheduleDismissedRevision'] is! int ||
          s['scheduleDismissedRevision'] < 0 ||
          s['scheduleDismissedRevision'] > s['revision'] ||
          ![null, 'record', 'transfer', 'match', 'correct', 'remove', 'ignored', 'keep'].contains(s['decision'])) {
        fail('Invalid bank source relationship.');
      }
      if (s['supersededBy'] != null) {
        final successor = sources.where((r) => r['id'] == s['supersededBy']).firstOrNull;
        if (s['state'] == 'posted' ||
            s['transactionId'] != null ||
            successor == null ||
            successor['connectionId'] != s['connectionId'] ||
            successor['sourceAccountId'] != s['sourceAccountId'] ||
            successor['pendingSourceId'] != s['sourceId']) {
          fail('Invalid pending replacement.');
        }
      }
      if (s['pendingSourceId'] != null) {
        final predecessor =
            sources
                .where((r) => r['id'] == sourceKey(s['connectionId'], s['sourceAccountId'], s['pendingSourceId']))
                .firstOrNull;
        if (predecessor != null && predecessor['supersededBy'] != s['id']) {
          fail('Missing reciprocal pending replacement.');
        }
      }
      if (s['transactionId'] != null) {
        final t = transactions.where((t) => t['id'] == s['transactionId']).firstOrNull;
        final accountId = accountLink(data, s)['accountId'] as String;
        if (s['state'] == 'pending' ||
            t == null ||
            effect(t, accountId) == 0 ||
            !linkedSides.add('${t['id']}/$accountId')) {
          fail('Invalid or duplicated bank-to-ledger link.');
        }
      }
    }
    final batchKeys = <String>{};
    final checkpoints = <String, String>{};
    for (final b in list(data, 'bankBatches')) {
      LocalLedger.text(b['batchId'], 'Batch identity', 100);
      LocalLedger.text(b['checkpoint'], 'Checkpoint', 200);
      LocalLedger.text(b['fromCheckpoint'], 'Previous checkpoint', 200, optional: true);
      if (!connections.any((c) => c['id'] == b['connectionId']) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(b['digest'] as String? ?? '') ||
          !(data['operations'] as Map).containsKey(b['operationId']) ||
          !batchKeys.add('${b['connectionId']}/${b['batchId']}') ||
          (checkpoints[b['connectionId']] ?? '') != b['fromCheckpoint']) {
        fail('Invalid bank checkpoint history.');
      }
      checkpoints[b['connectionId'] as String] = b['checkpoint'] as String;
    }
    for (final c in connections) {
      if ((checkpoints[c['id']] ?? '') != c['checkpoint']) fail('Checkpoint is missing its committed batch.');
    }
  }
}
