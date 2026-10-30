import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/server_planning.dart';
import 'package:budgetism/server_planning_widgets.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/reports.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/planning.dart';
import 'package:budgetism/local/recurrence.dart';

const planCash = '40000000-0000-4000-8000-000000000001',
    planDebt = '40000000-0000-4000-8000-000000000002',
    planExpense = '40000000-0000-4000-8000-000000000003',
    planIncome = '40000000-0000-4000-8000-000000000004',
    planEquity = '40000000-0000-4000-8000-000000000005',
    planSchedule = '40000000-0000-4000-8000-000000000006';
Json planningFixture() {
  Json entry(
    int id,
    String kind,
    String account,
    String other,
    int amount,
    String date,
    int signed,
  ) => {
    'id': '50000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
    'operationId': 'fictional-$id',
    'kind': kind,
    'accountId': account,
    'counterpartyAccountId': other,
    'amountMinor': amount,
    'currency': 'USD',
    'effectiveDate': date,
    'payee': 'Fictional $kind',
    'notes': 'Fictional notes',
    'version': 1,
    'voided': false,
    'scheduleId': null,
    'occurrenceIndex': null,
    'postings': [
      {'ledgerId': account, 'amountMinor': signed},
      {
        'ledgerId':
            kind == 'expense' || kind == 'income' ? 'category:$other' : other,
        'amountMinor': -signed,
      },
    ],
  };
  return {
    'version': 0,
    'ledgerCursor': 7,
    'snapshot': {
      'schema': 8,
      'cursor': 0,
      'datedOpenings': true,
      'accounts': [
        {
          'id': planCash,
          'name': 'Fictional checking',
          'type': 'checking',
          'currency': 'USD',
          'archived': false,
          'openingBalanceMinor': 0,
        },
        {
          'id': planDebt,
          'name': 'Fictional card',
          'type': 'credit_card',
          'currency': 'USD',
          'archived': false,
          'openingBalanceMinor': 0,
        },
      ],
      'categories': [
        {
          'id': planExpense,
          'name': 'Fictional food',
          'kind': 'Expense',
          'currency': 'USD',
        },
        {
          'id': planIncome,
          'name': 'Fictional pay',
          'kind': 'Income',
          'currency': 'USD',
        },
      ],
      'transactions': [
        entry(1, 'opening', planCash, planEquity, 10000, '2026-09-01', 10000),
        entry(2, 'opening', planDebt, planEquity, 5000, '2026-09-01', -5000),
        entry(3, 'income', planCash, planIncome, 1000, '2026-10-01', 1000),
        entry(4, 'expense', planDebt, planExpense, 200, '2026-10-20', -200),
        entry(5, 'expense', planDebt, planExpense, -50, '2026-10-21', 50),
        entry(6, 'transfer', planCash, planDebt, 500, '2026-10-22', -500),
        entry(7, 'expense', planCash, planExpense, 999, '2026-10-31', -999),
      ],
      'budgets': [],
      'schedules': [
        {
          'id': planSchedule,
          'name': 'Fictional monthly bill',
          'kind': 'expense',
          'accountId': planCash,
          'counterpartyAccountId': planExpense,
          'amountMinor': 120,
          'currency': 'USD',
          'startDate': '2026-10-31',
          'frequency': 'monthly',
          'endDate': null,
          'paused': false,
          'version': 1,
          'payee': 'Fictional bill',
          'notes': '',
        },
      ],
      'occurrences': [],
      'labels': [],
      'savedViews': [],
      'annotations': [],
      'statements': [],
      'audit': [],
    },
  };
}

class PlanningApiFixture extends FinanceApi {
  PlanningApiFixture() : super('https://fictional.example') {
    token = 'fictional-session';
  }
  Json state = planningFixture();
  final List<Json> writes = [];
  int reads = 0;
  bool failAfterCommit = false;
  final Map<String, Json> receipts = {};
  @override
  Future<Json> planningRequest([Json? body]) async {
    if (body == null) {
      reads++;
      return LocalLedger.clone(state);
    }
    writes.add(LocalLedger.clone(body));
    final operation = body['operationId'] as String;
    if (receipts.containsKey(operation)) {
      return LocalLedger.clone(receipts[operation]!);
    }
    final d = Map<String, dynamic>.from(body['data'] as Map),
        snapshot = state['snapshot'] as Map;
    if (body['action'] == 'budget') {
      snapshot['budgets'] = [
        {
          'id': 'fictional-budget',
          'month': d['month'],
          'categoryId': d['categoryId'],
          'amountMinor': d['amountMinor'],
          'rollover': d['rollover'],
          'removed': false,
          'version': 1,
        },
      ];
    }
    if (body['action'] == 'label') {
      snapshot['labels'] = [
        {
          'id': '60000000-0000-4000-8000-000000000001',
          'name': d['name'],
          'version': 1,
        },
      ];
    }
    if (body['action'] == 'view') {
      snapshot['savedViews'] = [
        {'id': '60000000-0000-4000-8000-000000000002', ...d, 'version': 1},
      ];
    }
    if (body['action'] == 'schedule-skip') {
      final due = Recurrence.at('2026-10-31', 'monthly', d['index'] as int)!;
      snapshot['occurrences'] = [
        {
          'id': '60000000-0000-4000-8000-000000000003',
          'scheduleId': planSchedule,
          'index': d['index'],
          'originalDueDate': due,
          'dueDate': due,
          'version': 1,
          'scheduleVersion': 1,
          'plannedAmountMinor': 120,
          'transactionId': null,
          'resolvedAtUtc': '2026-10-30T12:00:00Z',
          'status': 'skipped',
        },
      ];
    }
    if (body['action'] == 'category') {
      (snapshot['categories'] as List).add({
        'id': '60000000-0000-4000-8000-000000000004',
        'name': d['name'],
        'kind': d['kind'],
        'currency': 'USD',
        'archived': false,
      });
      state['ledgerCursor'] = (state['ledgerCursor'] as int) + 1;
    }
    state['version'] = (state['version'] as int) + 1;
    snapshot['cursor'] = state['version'];
    final result = {'version': state['version'], 'transactionId': null};
    receipts[operation] = result;
    if (failAfterCommit) {
      failAfterCommit = false;
      throw FinanceApiException('Fictional uncertain result.', 0);
    }
    return result;
  }

  @override
  Future<Json> bankRequest(
    String route, [
    Json? body,
    int? offset,
    int? version,
  ]) => throw StateError('Planning must not invoke provider operations.');
}

void main() {
  test(
    'server projection preserves dated openings, refunds, transfer sides and future forecasts',
    () {
      final data = ServerPlanningApi.validate(planningFixture());
      expect(
        LocalLedger.rows(data['transactions']).first.containsKey('scheduleId'),
        isFalse,
      );
      final report = ReportEngine.calculate(
        data,
        from: '2026-10-01',
        through: '2026-10-30',
        today: '2026-10-30',
      );
      expect(
        (
          report.starting,
          report.closing,
          report.income,
          report.expense,
          report.netIncome,
          report.transferCount,
        ),
        (5000, 5850, 1000, 150, 850, 1),
      );
      expect(
        report.balances.singleWhere((a) => a.id == planDebt).closing,
        -4650,
      );
      expect(
        BudgetEngine.calculate(data, '2026-10').spent,
        1149,
      ); // Entire budget month includes future recorded expenses.
      final forecast = PlanningEngine.forecast(
        data,
        today: '2026-10-30',
        days: 2,
      );
      expect(forecast.days.last.total({planCash, planDebt}), 4731);
      expect(data['transactions'], hasLength(7));
    },
  );
  test(
    'projection rejects unbalanced, fractional, duplicate and unsupported money',
    () {
      for (final change in <void Function(Json)>[
        (r) =>
            r['snapshot']['transactions'][0]['postings'][0]['amountMinor'] =
                10001,
        (r) => r['snapshot']['transactions'][0]['amountMinor'] = 1.5,
        (r) =>
            r['snapshot']['transactions'].add(r['snapshot']['transactions'][0]),
        (r) => r['snapshot']['accounts'][0]['currency'] = 'EUR',
      ]) {
        final d = planningFixture();
        change(d);
        expect(() => ServerPlanningApi.validate(d), throwsA(anything));
      }
    },
  );
  test(
    'uncertain planning commit retries original operation and versions without duplicate money',
    () async {
      final api = PlanningApiFixture(),
          workspace = ServerPlanningApi(PlanningApiFixture());
      final model = ServerPlanningApi(api);
      await model.refresh();
      api.failAfterCommit = true;
      final input = {
        'operationId': 'fictional-first',
        'month': '2026-10',
        'categoryId': planExpense,
        'expectedVersion': 0,
        'amountMinor': 5000,
        'rollover': 'none',
      };
      await expectLater(
        model.saveBudget(input),
        throwsA(isA<FinanceApiException>()),
      );
      await expectLater(
        model.saveBudget({...input, 'amountMinor': 6000}),
        throwsStateError,
      );
      await model.saveBudget({
        ...input,
        'operationId': 'fictional-new-dialog-retry',
      });
      expect(api.writes, hasLength(2));
      expect(api.writes[0], api.writes[1]);
      expect(api.receipts, hasLength(1));
      expect(model.planningSnapshot['budgets'], hasLength(1));
      expect(() => workspace.planningSnapshot, throwsStateError);
    },
  );
  test(
    'planning transport requires HTTPS, bounded replies, nonredirected bearer and sanitized errors',
    () async {
      final api = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient((r) async {
              expect(r.method, 'GET');
              expect(r.url.path, '/api/planning/state');
              expect(r.followRedirects, false);
              return http.Response(jsonEncode(planningFixture()), 200);
            }),
      )..token = 'fictional-token';
      expect((await api.planningRequest())['version'], 0);
      final redirect = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient(
              (_) async => http.Response('secret-provider-detail', 302),
            ),
      )..token = 'fictional';
      await expectLater(
        redirect.planningRequest(),
        throwsA(
          isA<FinanceApiException>().having(
            (e) => e.message,
            'sanitized',
            isNot(contains('secret')),
          ),
        ),
      );
      await expectLater(
        (FinanceApi('http://fictional.example')
          ..token = 'fictional').planningRequest(),
        throwsA(isA<FinanceApiException>()),
      );
    },
  );
  testWidgets(
    'server planning UI preserves explicit saves and read-only navigation',
    (tester) => runPlanningScenario(tester),
  );
}

Future<void> runPlanningScenario(
  WidgetTester tester, {
  Future<void> Function(String)? capture,
  GlobalKey? captureKey,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = PlanningApiFixture();
  Future<void> page(int index) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: captureKey,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ServerWorkspacePanel(
                  key: const ValueKey('workspace'),
                  api: api,
                  page: index,
                  onChanged: () async {},
                  onNavigate: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  await page(3);
  await tester.ensureVisible(find.byTooltip('Edit Fictional food budget'));
  await tester.tap(find.byTooltip('Edit Fictional food budget'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Monthly allocation (USD)'),
    '50.00',
  );
  await press('Save budget');
  expect(api.writes.single['action'], 'budget');
  expect(api.writes.single['data']['amountMinor'], 5000);
  await capture?.call('server-budgets-native.png');
  for (final index in [4, 5, 6, 7, 2]) {
    await page(index);
    expect(tester.takeException(), isNull);
    if (index == 5 || index == 6) {
      expect(find.textContaining('Signed opening postings use their effective dates.'), findsOneWidget);
      expect(find.textContaining('Opening balances have no dates in this preview.'), findsNothing);
    }
    await capture?.call('server-planning-$index-native.png');
    if (index == 4) {
      await press('Skip');
      await press('Skip occurrence');
      expect(api.writes.last['action'], 'schedule-skip');
      expect(api.writes.last['data']['scheduleId'], planSchedule);
      expect(api.state['snapshot']['transactions'], hasLength(7));
    }
  }
  expect(api.writes, hasLength(2));
  await press('Create label');
  await tester.enterText(
    find.widgetWithText(TextField, 'Name'),
    'Fictional test label',
  );
  await press('Save');
  expect(api.writes.last['action'], 'label');
  await tester.enterText(
    find.byKey(const Key('server-activity-search')),
    'Fictional',
  );
  await tester.pumpAndSettle();
  await press('Save this search');
  await tester.enterText(
    find.widgetWithText(TextField, 'Name'),
    'Fictional saved search',
  );
  await press('Save');
  expect(api.writes.last['action'], 'view');
  expect(find.text('Fictional saved search'), findsOneWidget);
  await capture?.call('server-saved-search-native.png');
  final writes = api.writes.length;
  await press('Reset filters');
  await press('Fictional saved search');
  expect(api.writes.length, writes);
  await press('Manage server categories');
  await press('Add expense category');
  await tester.enterText(
    find.widgetWithText(TextField, 'Name'),
    'Fictional custom category',
  );
  await press('Save');
  expect(api.writes.last['action'], 'category');
  expect(api.state['snapshot']['transactions'], hasLength(7));
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}
