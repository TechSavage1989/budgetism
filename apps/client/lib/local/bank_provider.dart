import 'package:uuid/uuid.dart';
import 'ledger.dart';
import 'vault.dart';

/// Adapter boundary: no provider credentials or networking in this milestone.
abstract class BankProvider {
  String get providerId;
  Future<BankPage> fetch({required String checkpoint, String? pageToken});
}

class BankPage {
  BankPage({
    required this.batchId,
    required this.fromCheckpoint,
    required this.checkpoint,
    required this.dataTimestampUtc,
    required this.records,
    required this.balances,
    this.nextPageToken,
  });
  final String batchId, fromCheckpoint, checkpoint, dataTimestampUtc;
  final List<Json> records, balances;
  final String? nextPageToken;
}

class SimulatedBankProvider implements BankProvider {
  @override
  String get providerId => BankSync.simulatedProvider;
  static List<Json> get accounts => [
    {
      'sourceAccountId': 'orchard-checking',
      'name': 'Fictional Orchard Checking',
      'type': 'checking',
      'currency': 'USD',
      'historyFrom': '2026-10-01',
      'openingBalanceMinor': 250000,
    },
    {
      'sourceAccountId': 'orchard-savings',
      'name': 'Fictional Orchard Savings',
      'type': 'savings',
      'currency': 'USD',
      'historyFrom': '2026-10-01',
      'openingBalanceMinor': 100000,
    },
    {
      'sourceAccountId': 'orchard-card',
      'name': 'Fictional Orchard Card',
      'type': 'credit_card',
      'currency': 'USD',
      'historyFrom': '2026-10-01',
      'openingBalanceMinor': -10000,
    },
  ];
  static Json record(
    String id,
    int signed,
    String description, {
    String account = 'orchard-checking',
    String state = 'posted',
    int revision = 1,
    String date = '2026-10-02',
    String? pending,
    String? transfer,
  }) => {
    'sourceAccountId': account,
    'sourceId': id,
    'revision': revision,
    'state': state,
    'signedMinor': signed,
    'currency': 'USD',
    'date': date,
    'description': description,
    'pendingSourceId': pending,
    'transferKey': transfer,
  };
  static List<Json> initial() => [
    record('dining-auth', -2500, 'Fictional Peach Cafe', state: 'pending'),
    record('fuel-auth', -10000, 'Fictional Acorn Fuel', state: 'pending'),
    record('merchant', -1200, 'Fictional Birch Bokshop'),
    record('removed', -700, 'Fictional Cancelled Order'),
    record('rent', -90000, 'Fictional Orchard Rent'),
    record('save-out', -20000, 'Fictional savings transfer', transfer: 'saving-pair'),
    record('save-in', 20000, 'Fictional savings transfer', account: 'orchard-savings', transfer: 'saving-pair'),
    record('card-out', -5000, 'Fictional card payment', transfer: 'card-pair'),
    record('card-in', 5000, 'Fictional card payment', account: 'orchard-card', transfer: 'card-pair'),
    record('card-purchase', -3000, 'Fictional Willow Supplies', account: 'orchard-card'),
    record('ambiguous-auth', -900, 'Fictional Plum Market', state: 'pending'),
    record('ambiguous-posted', -900, 'Fictional Plum Market'),
    record('identical-a', -499, 'Fictional Twin Kiosk'),
    record('identical-b', -499, 'Fictional Twin Kiosk'),
  ];
  static List<Json> changes(int stage) =>
      stage == 1
          ? initial()
          : stage == 2
          ? [
            record('dining-posted', -2800, 'Fictional Peach Cafe', date: '2026-10-03', pending: 'dining-auth'),
            record('fuel-posted', -5432, 'Fictional Acorn Fuel', date: '2026-10-03', pending: 'fuel-auth'),
            record('merchant', -1200, 'Fictional Birch Bookshop', revision: 2),
            record('removed', -700, 'Fictional Cancelled Order', state: 'removed', revision: 2),
            record(
              'card-reversal',
              3000,
              'Fictional Willow Supplies refund',
              account: 'orchard-card',
              date: '2026-10-03',
            ),
          ]
          : stage == 3
          ? [
            record('merchant', -1350, 'Fictional Birch Bookshop', revision: 3),
            record('ambiguous-auth', -900, 'Fictional Plum Market', state: 'removed', revision: 2),
          ]
          : [];
  @override
  Future<BankPage> fetch({required String checkpoint, String? pageToken}) async {
    if (!['', '1', '2', '3'].contains(checkpoint) || (pageToken != null && pageToken != 'second')) {
      throw const FormatException('Unknown simulation checkpoint.');
    }
    final stage = checkpoint.isEmpty ? 1 : int.parse(checkpoint) + 1;
    final records = changes(stage);
    final middle = (records.length / 2).ceil();
    final second = pageToken != null;
    final upto = stage > 3 ? 3 : stage;
    final all = <String, Json>{};
    for (var i = 1; i <= upto; i++) {
      for (final s in changes(i)) {
        all['${s['sourceAccountId']}/${s['sourceId']}'] = s;
      }
    }
    final replaced =
        all.values
            .where((s) => s['pendingSourceId'] != null)
            .map((s) => '${s['sourceAccountId']}/${s['pendingSourceId']}')
            .toSet();
    final balances = <Json>[];
    for (final a in accounts) {
      var posted = a['openingBalanceMinor'] as int;
      var pending = 0;
      for (final s in all.values.where((s) => s['sourceAccountId'] == a['sourceAccountId'])) {
        if (s['state'] == 'posted') posted += s['signedMinor'] as int;
        if (s['state'] == 'pending' && !replaced.contains('${s['sourceAccountId']}/${s['sourceId']}'))
          pending += s['signedMinor'] as int;
      }
      balances.add({
        'sourceAccountId': a['sourceAccountId'],
        'currency': 'USD',
        'reportedBalanceMinor': posted,
        'availableBalanceMinor': a['type'] == 'credit_card' ? null : posted + pending,
      });
    }
    return BankPage(
      batchId: 'fictional-stage-$stage',
      fromCheckpoint: checkpoint,
      checkpoint: '$upto',
      dataTimestampUtc: '2026-10-0${upto + 2}T12:00:00.000Z',
      records: second ? records.skip(middle).toList() : records.take(middle).toList(),
      balances: second ? balances : [],
      nextPageToken: second ? null : 'second',
    );
  }
}

class BankRefreshService {
  BankRefreshService(this.vault);
  final LocalVault vault;
  bool busy = false;

  /// Pages never reach storage individually. The adapter's final page is the
  /// completeness boundary, and all pages must describe one consistent batch.
  Future<void> refresh(
    String connectionId, {
    BankProvider? provider,
    bool interruptAfterFirstPage = false,
    bool repeatLast = false,
  }) async {
    if (busy) throw StateError('A simulated refresh is already running.');
    busy = true;
    var phase = 'invalid-feed';
    try {
      await vault.refresh();
      final data = vault.ledger.data;
      final connection = BankSync.connection(data, connectionId);
      if (connection['connected'] != true) throw StateError('Reconnect the simulation first.');
      final adapter = provider ?? SimulatedBankProvider();
      if (adapter.providerId != connection['providerId'])
        throw const FormatException('Wrong provider for this connection.');
      final batches = BankSync.list(data, 'bankBatches').where((b) => b['connectionId'] == connectionId).toList();
      final start =
          repeatLast && batches.isNotEmpty
              ? batches.last['fromCheckpoint'] as String
              : connection['checkpoint'] as String;
      String? token;
      final seen = <String>{};
      BankPage? first;
      final records = <Json>[], balances = <Json>[];
      do {
        if (seen.length >= 100 || (token != null && !seen.add(token)))
          throw const FormatException('Repeated or excessive source pages.');
        final page = await adapter.fetch(checkpoint: start, pageToken: token);
        first ??= page;
        if (page.fromCheckpoint != start ||
            page.batchId != first.batchId ||
            page.checkpoint != first.checkpoint ||
            page.dataTimestampUtc != first.dataTimestampUtc) {
          throw const FormatException('Source pages changed during refresh.');
        }
        records.addAll(page.records);
        balances.addAll(page.balances);
        if (records.length > 2000 || balances.length > 100) throw const FormatException('Source batch is too large.');
        token = page.nextPageToken;
        if (interruptAfterFirstPage) {
          phase = 'interrupted';
          throw StateError('Fictional interruption after the first page.');
        }
      } while (token != null);
      final batch = <String, dynamic>{
        'batchId': first.batchId,
        'fromCheckpoint': first.fromCheckpoint,
        'checkpoint': first.checkpoint,
        'dataTimestampUtc': first.dataTimestampUtc,
        'complete': true,
        'records': records,
        'balances': balances,
      };
      phase = 'save-failed';
      await vault.apply('bank-refresh', {
        'operationId': const Uuid().v4(),
        'expectedRevision': data['revision'],
        'connectionId': connectionId,
        'atUtc': DateTime.now().toUtc().toIso8601String(),
        'batch': batch,
      });
    } catch (_) {
      // A failed commit may have succeeded on disk. Refresh first, never roll
      // back a checkpoint, and record only a sanitized connection-level issue.
      try {
        await vault.refresh();
        if (BankSync.connection(vault.ledger.data, connectionId)['connected'] == true) {
          await vault.apply('bank-failure', {
            'operationId': const Uuid().v4(),
            'expectedRevision': vault.ledger.revision,
            'connectionId': connectionId,
            'atUtc': DateTime.now().toUtc().toIso8601String(),
            'errorCode': phase,
          });
        }
      } catch (_) {
        /* The UI still reports failure when storage is unavailable. */
      }
      throw StateError('Simulated refresh did not finish. Saved records are retained. Retry from Connections.');
    } finally {
      busy = false;
    }
  }
}
