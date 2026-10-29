import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/bank_widgets.dart';
import 'package:budgetism/local/bank_provider.dart';
import 'package:budgetism/local/ledger.dart';
import 'bank_test_helpers.dart';
import 'reconciliation_test.dart' show statementRequest;

Future<void> _open(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                onPressed: () => showDialog<void>(context: context, builder: (_) => child),
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await _tap(tester, find.byKey(Key(key)));
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mapping starts read-only and requires fictional and schema consent before save', (tester) async {
    var calls = 0;
    Json? submitted;
    await _open(
      tester,
      BankMappingDialog(
        snapshot: LocalLedger.empty().snapshot(),
        onSave: (input) async {
          calls++;
          submitted = input;
        },
      ),
    );
    expect(calls, 0);
    expect(tester.widget<FilledButton>(find.byKey(const Key('bank-mapping-save'))).onPressed, null);
    await _tap(tester, find.byKey(const Key('bank-fictional-consent')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('bank-mapping-save'))).onPressed, null);
    await _tap(tester, find.byKey(const Key('bank-upgrade-consent')));
    await _tap(tester, find.byKey(const Key('bank-mapping-save')));
    expect(calls, 1);
    expect(submitted!['confirmFictional'], true);
    expect(submitted!['accounts'].length, 3);
  });
  testWidgets('mapping cancel leaves older workspace and accounts unchanged on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(430, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await _open(
      tester,
      BankMappingDialog(
        snapshot: LocalLedger.empty().snapshot(),
        onSave: (_) async {
          calls++;
        },
      ),
    );
    await _tap(tester, find.text('Cancel'));
    expect(calls, 0);
    expect(tester.takeException(), null);
  });
  testWidgets('review requires category and explicit confirmation; only the selected record is saved', (tester) async {
    var l = bankFixture();
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('one', -1200, 'Fictional Cafe')]));
    final before = l.revision;
    await _open(
      tester,
      BankReviewDialog(
        snapshot: l.snapshot(),
        item: BankSync.inbox(l.data).single,
        onSave: (input) async {
          l = l.apply('bank-review', input);
        },
      ),
    );
    expect(tester.widget<FilledButton>(find.byKey(const Key('bank-review-save'))).onPressed, null);
    await _select(tester, 'bank-decision', 'Record with a category');
    await _select(tester, 'bank-category', 'Dining');
    await tester.enterText(find.byKey(const Key('bank-notes')), 'Fictional note');
    await tester.pumpAndSettle();
    expect(l.revision, before);
    await _tap(tester, find.byKey(const Key('bank-review-consent')));
    await _tap(tester, find.byKey(const Key('bank-review-save')));
    expect(BankSync.list(l.data, 'transactions').single['notes'], 'Fictional note');
    expect(l.revision, before + 1);
    expect(tester.takeException(), null);
  });
  testWidgets('failed review retry retains its operation identity and disables concurrent submit', (tester) async {
    var l = bankFixture();
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('one', -1200, 'Fictional Cafe')]));
    final inputs = <Json>[];
    final gate = Completer<void>();
    await _open(
      tester,
      BankReviewDialog(
        snapshot: l.snapshot(),
        item: BankSync.inbox(l.data).single,
        onSave: (input) async {
          inputs.add(input);
          if (inputs.length == 1) throw StateError('Fictional disk failure');
          await gate.future;
        },
      ),
    );
    await _select(tester, 'bank-decision', 'Record with a category');
    await _select(tester, 'bank-category', 'Dining');
    await _tap(tester, find.byKey(const Key('bank-review-consent')));
    await _tap(tester, find.byKey(const Key('bank-review-save')));
    expect(find.byKey(const Key('bank-review-error')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('bank-review-save')));
    expect(inputs.length, 2);
    expect(inputs[0], inputs[1]);
    expect(tester.widget<FilledButton>(find.byKey(const Key('bank-review-save'))).onPressed, null);
    gate.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('reconciled correction exposes keep and explains reopening; cannot apply correction', (tester) async {
    var l = bankFixture();
    l = l.apply('bank-refresh', sourceBatch(l, [SimulatedBankProvider.record('one', -1200, 'Fictional Cafe')]));
    l = recordSource(l, 'one');
    l = l.apply('reconcile', statementRequest(l, accountId: bankAccount(l), closing: 248800));
    l = l.apply(
      'bank-refresh',
      sourceBatch(l, [SimulatedBankProvider.record('one', -1300, 'Fictional Cafe', revision: 2)]),
    );
    var calls = 0;
    await _open(
      tester,
      BankReviewDialog(
        snapshot: l.snapshot(),
        item: BankSync.inbox(l.data).single,
        onSave: (_) async {
          calls++;
        },
      ),
    );
    expect(find.textContaining('Reopen all relevant statements'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('bank-decision')));
    expect(find.text('Apply amount / date correction'), findsNothing);
    await tester.tap(find.text('Keep the recorded entry unchanged').last);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Cancel'));
    expect(calls, 0);
  });
  testWidgets('paired transfer review is explicit and posts one transaction', (tester) async {
    var l = bankFixture();
    l = l.apply('bank-refresh', await simulatedBatch(l));
    final item = BankSync.inbox(l.data).firstWhere((r) => r['id'] == bankSource(l, 'card-out')['id']);
    await _open(
      tester,
      BankReviewDialog(
        snapshot: l.snapshot(),
        item: item,
        onSave: (input) async {
          l = l.apply('bank-review', input);
        },
      ),
    );
    await _select(tester, 'bank-decision', 'Record one transfer / card payment');
    await _tap(tester, find.byKey(const Key('bank-pair')));
    await tester.tap(find.textContaining('Fictional Orchard Card •').last);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('bank-review-consent')));
    await _tap(tester, find.byKey(const Key('bank-review-save')));
    expect(BankSync.list(l.data, 'transactions').single['kind'], 'transfer');
    expect(bankSource(l, 'card-out')['transactionId'], bankSource(l, 'card-in')['transactionId']);
  });
}
