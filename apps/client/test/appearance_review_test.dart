import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/appearance.dart';
import 'package:budgetism/main.dart' show BudgetismApp;
import 'package:budgetism/review_filter.dart';
import 'package:budgetism/server_bank_widgets.dart';
import 'package:budgetism/batch_decision_dialog.dart';
import 'server_bank_test.dart'
    show BankApiFixture, bankState, accountId, sourceId;

Future<void> press(WidgetTester tester, String text) async {
  await tester.pump();
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'appearance retains legacy mode, rejects invalid/future settings and preserves unrelated preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'appearance.theme': 'light',
        'connection.httpsAddress.v1': 'https://fictional.example',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(AppAppearance.read(prefs).mode, ThemeMode.light);
      for (final raw in [
        'broken',
        '{"version":2}',
        '{"version":1,"mode":"dark","accent":"FF#FF00","compact":false,"highContrast":false}',
      ]) {
        await prefs.setString(AppearancePreferences.key, raw);
        expect(AppAppearance.read(prefs).mode, ThemeMode.light);
      }
      final value = const AppAppearance(
        mode: ThemeMode.system,
        accent: 0x123ABC,
        compact: true,
        highContrast: true,
      );
      await AppearancePreferences().save(value);
      expect(AppAppearance.read(prefs).toJson(), value.toJson());
      expect(
        prefs.getString('connection.httpsAddress.v1'),
        'https://fictional.example',
      );
      for (final bad in ['12345', '12345678', 'FF#FF00', 'nothex']) {
        expect(AppAppearance.parseAccent(bad), isNull);
      }
      expect(AppAppearance.parseAccent('#000000'), 0);
    },
  );
  test(
    'generated light and dark theme text remains readable for presets and extreme custom seeds',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      for (final seed in [
        ...AppAppearance.presets.values,
        0,
        0xFFFFFF,
        0x00FF00,
      ]) {
        for (final brightness in Brightness.values) {
          for (final high in [false, true]) {
            final scheme =
                AppAppearance(
                  accent: seed,
                  highContrast: high,
                ).theme(brightness).colorScheme;
            expect(
              contrast(scheme.primary, scheme.onPrimary),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              contrast(scheme.surface, scheme.onSurface),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
      }
    },
  );
  testWidgets(
    'appearance preview cancels without saving; Apply persists only appearance',
    (tester) async {
      await tester.pumpWidget(const BudgetismApp());
      await tester.pumpAndSettle();
      await press(tester, 'Appearance and themes');
      await press(tester, 'Ocean');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppearancePreferences.key), isFalse);
      await press(tester, 'Cancel');
      expect(prefs.containsKey(AppearancePreferences.key), isFalse);
      await press(tester, 'Appearance and themes');
      await tester.enterText(
        find.byKey(const Key('appearance-accent')),
        'GGGGGG',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('appearance-apply')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('appearance-accent')),
        '123ABC',
      );
      await tester.pump();
      await press(tester, 'Apply');
      expect(AppAppearance.read(prefs).accent, 0x123ABC);
      expect(
        jsonDecode(prefs.getString(AppearancePreferences.key)!)['version'],
        1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'review filters combine inclusive dates, account, direction and search without mutating input',
    () {
      final data = bankState();
      final row = Map<String, dynamic>.from(
        (data['sources'] as List).single as Map,
      );
      final rows = [
        row,
        {
          ...row,
          'id': 'b',
          'description': 'Fictional deposit',
          'amountMinor': 10000,
          'date': '2026-10-28',
        },
        {...row, 'id': 'c', 'status': 'pending', 'needsReview': false},
        {...row, 'id': 'd', 'date': null, 'status': 'removed'},
      ];
      final before = jsonEncode(rows);
      final filtered = const ReviewFilter(
        query: 'fictional cafe',
        direction: 'out',
        from: '2026-10-29',
        to: '2026-10-29',
        view: ReviewView.needsReview,
      ).apply(rows, {accountId: 'Checking'});
      expect(filtered.map((r) => r['id']), [sourceId]);
      expect(
        const ReviewFilter(
          order: ReviewOrder.largest,
        ).apply(rows, {}).first['id'],
        'b',
      );
      expect(
        const ReviewFilter(
          view: ReviewView.pending,
        ).apply(rows, {}).single['id'],
        'c',
      );
      expect(ReviewFilter.batchEligible(rows[2]), isFalse);
      expect(
        ReviewFilter.reopenEligible({
          ...row,
          'needsReview': false,
          'decision': 'ignored',
          'reviewedVersion': 1,
        }),
        isTrue,
      );
      expect(jsonEncode(rows), before);
    },
  );
  testWidgets(
    'filter changes clear selection; batch retry retains the exact reviewed operation',
    (tester) async {
      final api = _BatchFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerBankPanel(api: api, onChanged: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, 'Select visible eligible');
      expect(find.text('1 selected'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('review-search')), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(api.writes, isEmpty);
      await tester.enterText(find.byKey(const Key('review-search')), '');
      await tester.pumpAndSettle();
      await press(tester, 'Select visible eligible');
      await press(tester, 'Ignore selected');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('batch-apply')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for all selected decisions'),
        'Fictional duplicate',
      );
      await tester.pump();
      await press(
        tester,
        'I reviewed this selection and want to apply this reason to every selected source.',
      );
      api.fail = true;
      await press(tester, 'Apply selected decisions');
      final first = Map.of(api.writes.single);
      expect(first['route'], 'review-batch');
      api.fail = false;
      await press(tester, 'Retry unchanged action');
      expect(api.writes.last, first);
    },
  );
  testWidgets('keeping a batch requires loading the linked recorded entries', (
    tester,
  ) async {
    final row = Map<String, dynamic>.from(
      (bankState(linked: true)['sources'] as List).single as Map,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchDecisionDialog(
            action: 'keep',
            sources: [row],
            snapshot: {'transactions': []},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('batch-apply')))
          .onPressed,
      isNull,
    );
  });
}

class _BatchFixture extends BankApiFixture {
  @override
  Future<Map<String, dynamic>> bankRequest(
    String route, [
    Map<String, dynamic>? body,
    int? offset,
    int? version,
  ]) async {
    if (body == null) return {...bankState(), 'batchReviewSupported': true};
    return super.bankRequest(route, body, offset, version);
  }
}
