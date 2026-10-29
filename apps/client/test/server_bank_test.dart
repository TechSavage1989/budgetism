import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/server_bank.dart';
import 'package:budgetism/server_bank_widgets.dart';

const connectionId = '10000000-0000-4000-8000-000000000001';
const accountId = '10000000-0000-4000-8000-000000000002';
const ledgerId = '10000000-0000-4000-8000-000000000003';
const sourceId = '10000000-0000-4000-8000-000000000004';
const categoryId = '10000000-0000-4000-8000-000000000005';
Map<String, dynamic> bankState({bool pending = false, bool linked = false}) => {
  'storageReady': true,
  'connection': {
    'id': connectionId,
    'active': true,
    'version': 4,
    'lastSuccessUtc': '2026-10-29T12:00:00Z',
    'lastErrorCode': null,
  },
  'accounts': [
    {
      'id': accountId,
      'name': 'Fictional checking',
      'mask': '0001',
      'type': 'checking',
      'currency': 'USD',
      'supported': true,
      'available': true,
      'ledgerAccountId': ledgerId,
      'reportedBalanceMinor': 100000,
      'availableBalanceMinor': 100000,
      'balanceIssue': false,
    },
  ],
  'sources': [
    {
      'id': sourceId,
      'bankAccountId': accountId,
      'version': 1,
      'status': pending ? 'pending' : 'posted',
      'amountMinor': -1234,
      'date': '2026-10-29',
      'description': 'Fictional cafe',
      'superseded': false,
      'needsReview': !pending,
      'decision': linked ? 'recorded' : null,
      'reviewedVersion': null,
      'linkedJournalEntryId':
          linked ? '10000000-0000-4000-8000-000000000006' : null,
    },
  ],
  'totalSources': 1,
  'needsReviewCount': pending ? 0 : 1,
  'hasMore': false,
};
Map<String, dynamic> bankSnapshot() => {
  'accounts': [],
  'categories': [
    {
      'id': categoryId,
      'name': 'Fictional dining',
      'kind': 'Expense',
      'currency': 'USD',
    },
  ],
  'transactions': [],
};

class BankApiFixture extends FinanceApi {
  BankApiFixture() : super('https://fictional.example') {
    token = 'fictional-session';
  }
  final writes = <Map<String, dynamic>>[];
  int reads = 0;
  bool fail = false, pending = false;
  @override
  Future<Map<String, dynamic>> snapshot() async => bankSnapshot();
  @override
  Future<Map<String, dynamic>> bankRequest(
    String route, [
    Map<String, dynamic>? body,
    int? offset,
    int? version,
  ]) async {
    if (body == null) {
      reads++;
      return bankState(pending: pending);
    }
    writes.add({'route': route, ...body});
    if (fail) throw FinanceApiException('The operation did not finish.', 0);
    return {'connectionVersion': 5, 'ready': true};
  }
}

Widget bankPanel(BankApiFixture api) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ServerBankPanel(api: api, onChanged: () {}),
    ),
  ),
);

void main() {
  test(
    'state rejects fractional cents, invalid dates, duplicate sources and foreign accounts',
    () {
      expect(
        ServerBankState.parse(bankState()).sources.single['amountMinor'],
        -1234,
      );
      for (final change in <void Function(Map<String, dynamic>)>[
        (x) => x['sources'][0]['amountMinor'] = 1.1,
        (x) => x['sources'][0]['date'] = '2026-02-30',
        (x) =>
            x['sources'].add(Map<String, dynamic>.from(x['sources'][0] as Map)),
        (x) => x['sources'][0]['bankAccountId'] = 'foreign',
        (x) => x['storageReady'] = false,
      ]) {
        final data = bankState();
        change(data);
        expect(() => ServerBankState.parse(data), throwsFormatException);
      }
    },
  );
  test(
    'bank transport validates HTTPS, blocks redirects and excludes error bodies',
    () async {
      var calls = 0;
      final api = FinanceApi(
        'http://fictional.example',
        previewClientFactory:
            () => MockClient((_) async {
              calls++;
              return http.Response('{}', 200);
            }),
      )..token = 'fictional';
      await expectLater(
        api.bankRequest('state'),
        throwsA(isA<FinanceApiException>()),
      );
      expect(calls, 0);
      final redirect = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient((request) async {
              expect(request.followRedirects, isFalse);
              return http.Response(
                'fictional-secret',
                302,
                headers: {'location': 'https://elsewhere.example'},
              );
            }),
      )..token = 'fictional';
      await expectLater(
        redirect.bankRequest('refresh', {'operationId': 'fictional'}),
        throwsA(
          isA<FinanceApiException>().having(
            (e) => e.message,
            'safe message',
            'Server redirects are blocked.',
          ),
        ),
      );
    },
  );
  test(
    'bank transport refuses stale session and bounded malformed response',
    () async {
      late FinanceApi api;
      api = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient((_) async {
              api.token = 'new-session';
              return http.Response(jsonEncode(bankState()), 200);
            }),
      )..token = 'old-session';
      await expectLater(
        api.bankRequest('state'),
        throwsA(
          isA<FinanceApiException>().having(
            (e) => e.statusCode,
            'session guard',
            401,
          ),
        ),
      );
      final large = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient(
              (_) async => http.Response('x' * (4 * 1024 * 1024 + 1), 200),
            ),
      )..token = 'fictional';
      await expectLater(
        large.bankRequest('state'),
        throwsA(isA<FinanceApiException>()),
      );
    },
  );
  testWidgets(
    'navigation reads saved state only; refresh requires an explicit button and retry keeps operation identity',
    (tester) async {
      final api = BankApiFixture()..fail = true;
      await tester.pumpWidget(bankPanel(api));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 2));
      expect(api.reads, 1);
      expect(api.writes, isEmpty);
      await tester.tap(find.text('Refresh fictional sources'));
      await tester.pumpAndSettle();
      expect(api.writes.length, 1);
      final original = Map.of(api.writes.single);
      api.fail = false;
      await tester.tap(find.text('Retry unchanged action'));
      await tester.pumpAndSettle();
      expect(api.writes.length, 2);
      expect(api.writes.last, original);
      expect(find.text('Retry unchanged action'), findsNothing);
    },
  );
  testWidgets(
    'pending sources have no review button and loading does not post',
    (tester) async {
      final api = BankApiFixture()..pending = true;
      await tester.pumpWidget(bankPanel(api));
      await tester.pumpAndSettle();
      expect(find.text('Review'), findsNothing);
      expect(api.writes, isEmpty);
    },
  );
  testWidgets(
    'record requires category, duplicate and transfer review and explicit confirmation',
    (tester) async {
      final state = ServerBankState.parse(bankState());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerBankReviewDialog(
              state: state,
              source: state.sources.single,
              snapshot: bankSnapshot(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FilledButton apply() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply reviewed choice'),
      );
      expect(apply().onPressed, isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record new entry').last);
      await tester.pumpAndSettle();
      expect(apply().onPressed, isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fictional dining').last);
      await tester.pumpAndSettle();
      for (final text in [
        'I reviewed existing entries for duplicates.',
        'I reviewed transfers and card payments; this choice will not double-count them.',
        'Apply this explicit choice to the server’s fictional records.',
      ]) {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }
      expect(apply().onPressed, isNotNull);
    },
  );
  testWidgets('linked source offers keep with reason and no record choice', (
    tester,
  ) async {
    final state = ServerBankState.parse(bankState(linked: true));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServerBankReviewDialog(
            state: state,
            source: state.sources.single,
            snapshot: bankSnapshot(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep recorded entry unchanged'), findsOneWidget);
    expect(find.text('Record new entry'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply reviewed choice'),
          )
          .onPressed,
      isNull,
    );
  });
}
