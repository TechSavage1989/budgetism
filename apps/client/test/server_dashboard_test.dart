import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/server_dashboard.dart';
import 'package:budgetism/server_dashboard_widgets.dart';
import 'server_bank_test.dart'
    show bankState, accountId, ledgerId, sourceId, categoryId;

Map<String, dynamic> dashboardFixture() {
  final bank = bankState();
  return {
    'through': '2026-10-30',
    'currency': 'USD',
    'assetsMinor': 10500,
    'netBalanceMinor': 5850,
    'incomeMinor': 1000,
    'expenseMinor': 150,
    'netIncomeMinor': 850,
    'recordedCount': 6,
    'futureCount': 1,
    'accounts': [
      {
        'id': ledgerId,
        'name': 'Fictional checking',
        'type': 'checking',
        'archived': false,
        'balanceMinor': 10500,
      },
      {
        'id': '20000000-0000-4000-8000-000000000001',
        'name': 'Fictional card',
        'type': 'credit_card',
        'archived': true,
        'balanceMinor': -4650,
      },
    ],
    'recent': [
      {
        'id': sourceId,
        'kind': 'expense',
        'accountId': ledgerId,
        'accountName': 'Fictional checking',
        'counterpartyAccountId': categoryId,
        'counterpartyName': 'Fictional food',
        'amountMinor': -50,
        'date': '2026-10-29',
        'payee': 'Fictional refund',
      },
    ],
    'spendingCategories': [
      {
        'id': categoryId,
        'name': 'Fictional food',
        'amountMinor': 150,
        'entryCount': 2,
      },
    ],
    'spendingCategoryCount': 1,
    'bank': {
      'status': 'ready',
      'connection': bank['connection'],
      'accounts': bank['accounts'],
      'needsReviewCount': 1,
      'totalSources': 316,
    },
  };
}

class DashboardApiFixture extends FinanceApi {
  DashboardApiFixture() : super('https://fictional.example') {
    token = 'fictional-session';
  }
  int reads = 0, writes = 0;
  bool fail = false;
  @override
  Future<ServerDashboard> dashboard(String through) async {
    reads++;
    if (fail) throw StateError('fictional-secret-error');
    return ServerDashboard.parse(dashboardFixture(), through);
  }

  @override
  Future<void> createTransaction(Map<String, dynamic> data) async {
    writes++;
    throw StateError('No writes');
  }

  @override
  Future<Map<String, dynamic>> bankRequest(
    String route, [
    Map<String, dynamic>? body,
    int? offset,
    int? version,
  ]) async {
    writes++;
    throw StateError('Dashboard must not call bank operations');
  }
}

void main() {
  test(
    'bounded dashboard rejects unsafe amounts, dates, identities and false availability',
    () {
      expect(
        ServerDashboard.parse(
          dashboardFixture(),
          '2026-10-30',
        ).data['expenseMinor'],
        150,
      );
      for (final change in <void Function(Map<String, dynamic>)>[
        (d) => d['assetsMinor'] = 1.5,
        (d) => d['expenseMinor'] = 9007199254740992,
        (d) => d['through'] = '2026-10-31',
        (d) => d['recent'][0]['date'] = '2026-02-30',
        (d) => d['recent'][0]['date'] = '2026-10-31',
        (d) => d['recent'][0]['accountId'] = accountId,
        (d) => d['accounts'].add(d['accounts'][0]),
        (d) => d['bank']['status'] = 'disabled',
        (d) => d['bank']['needsReviewCount'] = -1,
      ]) {
        final d = dashboardFixture();
        change(d);
        expect(() => ServerDashboard.parse(d, '2026-10-30'), throwsA(anything));
      }
    },
  );
  test(
    'dashboard transport is read-only bounded HTTPS and rejects redirects/error details',
    () async {
      final api = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path, '/api/dashboard');
              expect(request.url.queryParameters, {'through': '2026-10-30'});
              expect(request.followRedirects, isFalse);
              expect(request.body, isEmpty);
              return http.Response(jsonEncode(dashboardFixture()), 200);
            }),
      )..token = 'fictional-session';
      expect(
        (await api.dashboard('2026-10-30')).data['bank']['totalSources'],
        316,
      );
      for (final code in [302, 401, 404, 503]) {
        final failed = FinanceApi(
          'https://fictional.example',
          previewClientFactory:
              () => MockClient(
                (_) async => http.Response('secret-provider-response', code),
              ),
        )..token = 'fictional';
        await expectLater(
          failed.dashboard('2026-10-30'),
          throwsA(
            isA<FinanceApiException>().having(
              (e) => e.message,
              'sanitized',
              isNot(contains('secret')),
            ),
          ),
        );
      }
      final plain = FinanceApi('http://fictional.example')..token = 'fictional';
      await expectLater(
        plain.dashboard('2026-10-30'),
        throwsA(isA<FinanceApiException>()),
      );
    },
  );
  test('dashboard rejects stale sessions and oversized bodies', () async {
    final pending = Completer<http.Response>();
    final api = FinanceApi(
      'https://fictional.example',
      previewClientFactory: () => MockClient((_) => pending.future),
    )..token = 'first';
    final result = api.dashboard('2026-10-30');
    api.token = 'second';
    pending.complete(http.Response(jsonEncode(dashboardFixture()), 200));
    await expectLater(result, throwsA(isA<FinanceApiException>()));
    final huge = FinanceApi(
      'https://fictional.example',
      previewClientFactory:
          () => MockClient(
            (_) async => http.Response('x' * (1024 * 1024 + 1), 200),
          ),
    )..token = 'fictional';
    await expectLater(
      huge.dashboard('2026-10-30'),
      throwsA(isA<FinanceApiException>()),
    );
  });
  testWidgets(
    'overview shows distinct recorded/provider scope, review navigation and clears failed results',
    (tester) async {
      tester.view.physicalSize = const Size(560, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = DashboardApiFixture();
      int? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerDashboardPanel(
                api: api,
                revision: 1,
                now: DateTime(2026, 10, 30),
                onNavigate: (i) => destination = i,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Net recorded balance'), findsOneWidget);
      expect(
        find.textContaining('future-dated recorded entries'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('dashboard-review')));
      await tester.tap(find.byKey(const Key('dashboard-review')));
      await tester.pump();
      expect(destination, 10);
      expect(find.textContaining('316 saved sources'), findsOneWidget);
      expect(api.writes, 0);
      api.fail = true;
      await tester.ensureVisible(find.byKey(const Key('dashboard-refresh')));
      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Net recorded balance'), findsNothing);
      expect(find.textContaining('Dashboard unavailable.'), findsOneWidget);
      expect(find.textContaining('fictional-secret-error'), findsNothing);
      expect(api.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
