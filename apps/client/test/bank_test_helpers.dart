import 'package:uuid/uuid.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/bank_provider.dart';

Json connectRequest(LocalLedger l) => {
  'operationId': const Uuid().v4(),
  'expectedRevision': l.revision,
  'providerId': BankSync.simulatedProvider,
  'confirmReviewed': true,
  'confirmFictional': true,
  'confirmBankUpgrade': true,
  'accounts': SimulatedBankProvider.accounts,
};
LocalLedger bankFixture([LocalLedger? original]) {
  final l = original ?? LocalLedger.empty();
  return l.apply('bank-connect', connectRequest(l));
}

Json bankSource(LocalLedger l, String id) =>
    BankSync.list(l.data, 'bankSources').firstWhere((s) => s['sourceId'] == id);
Json bankConnection(LocalLedger l) => BankSync.list(l.data, 'bankConnections').single;
String bankAccount(LocalLedger l, [String source = 'orchard-checking']) =>
    BankSync.list(l.data, 'bankAccounts').firstWhere((a) => a['sourceAccountId'] == source)['accountId'] as String;
Json sourceBatch(LocalLedger l, List<Json> records, {String? batchId, String? checkpoint, List<Json>? balances}) {
  final c = bankConnection(l);
  final id = batchId ?? const Uuid().v4();
  return {
    'operationId': const Uuid().v4(),
    'expectedRevision': l.revision,
    'connectionId': c['id'],
    'atUtc': '2026-10-29T12:00:00.000Z',
    'batch': {
      'batchId': id,
      'fromCheckpoint': c['checkpoint'],
      'checkpoint': checkpoint ?? id,
      'dataTimestampUtc': '2026-10-10T12:00:00.000Z',
      'complete': true,
      'records': records,
      'balances': balances ?? <Json>[],
    },
  };
}

Json reviewRequest(LocalLedger l, String sourceId, String decision, [Json extra = const {}]) {
  final source = bankSource(l, sourceId);
  final t = BankSync.list(l.data, 'transactions').where((t) => t['id'] == source['transactionId']).firstOrNull;
  return {
    'operationId': const Uuid().v4(),
    'expectedRevision': l.revision,
    'sourceId': source['id'],
    'expectedSourceRevision': source['revision'],
    'decision': decision,
    'confirmReviewed': true,
    'expectedTransactionVersion': t?['version'],
    ...extra,
  };
}

String bankCategory(LocalLedger l, [String kind = 'Expense']) =>
    BankSync.list(l.data, 'categories').firstWhere((c) => c['kind'] == kind)['id'];
LocalLedger recordSource(LocalLedger l, String sourceId, [Json extra = const {}]) =>
    l.apply('bank-review', reviewRequest(l, sourceId, 'record', {'categoryId': bankCategory(l), ...extra}));
Future<Json> simulatedBatch(LocalLedger l) async {
  final c = bankConnection(l), provider = SimulatedBankProvider();
  final first = await provider.fetch(checkpoint: c['checkpoint']);
  final last = await provider.fetch(checkpoint: c['checkpoint'], pageToken: first.nextPageToken);
  return {
    'operationId': const Uuid().v4(),
    'expectedRevision': l.revision,
    'connectionId': c['id'],
    'atUtc': '2026-10-29T12:00:00.000Z',
    'batch': {
      'batchId': first.batchId,
      'fromCheckpoint': first.fromCheckpoint,
      'checkpoint': first.checkpoint,
      'dataTimestampUtc': first.dataTimestampUtc,
      'complete': true,
      'records': [...first.records, ...last.records],
      'balances': [...first.balances, ...last.balances],
    },
  };
}
