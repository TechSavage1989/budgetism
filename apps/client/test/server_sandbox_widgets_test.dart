import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/main.dart' show FinanceShell;
import 'package:budgetism/server_sandbox.dart';
import 'package:budgetism/server_sandbox_widgets.dart';
import 'server_sandbox_test.dart' show fictionalPreview, fictionalRow;

class PreviewApi extends FinanceApi {
  PreviewApi() : super('https://fictional.example') {
    token = 'fictional-session';
  }
  int previews = 0, writes = 0;
  Future<SandboxPreview> Function()? load;
  @override
  Future<SandboxPreview> sandboxPreview() async {
    previews++;
    return load == null ? SandboxPreview.fromJson(fictionalPreview()) : load!();
  }

  @override
  Future<Map<String, dynamic>> snapshot() async => {
    'accounts': [],
    'categories': [],
    'transactions': [],
  };
  @override
  Future<void> createAccount(Map<String, dynamic> data) async {
    writes++;
  }

  @override
  Future<void> createTransaction(Map<String, dynamic> data) async {
    writes++;
  }
}

Widget panel(PreviewApi api) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: ServerSandboxPanel(api: api)),
  ),
);

void main() {
  testWidgets(
    'navigation and waiting never retrieve or write; explicit button retrieves once',
    (tester) async {
      final api = PreviewApi();
      final pending = Completer<SandboxPreview>();
      api.load = () => pending.future;
      await tester.pumpWidget(panel(api));
      await tester.pump(const Duration(minutes: 1));
      expect(api.previews, 0);
      await tester.tap(find.byKey(const ValueKey('sandbox-load')));
      await tester.pump();
      expect(api.previews, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('sandbox-load')))
            .onPressed,
        isNull,
      );
      pending.complete(
        SandboxPreview.fromJson(
          fictionalPreview(rows: [fictionalRow(pending: true)]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fictional cafe'), findsOneWidget);
      expect(find.text('-\$12.34'), findsOneWidget);
      expect(find.textContaining('Pending · Added'), findsOneWidget);
      expect(api.writes, 0);
    },
  );
  testWidgets('failure clears old preview and never shows raw exceptions', (
    tester,
  ) async {
    final api = PreviewApi();
    await tester.pumpWidget(panel(api));
    await tester.tap(find.byKey(const ValueKey('sandbox-load')));
    await tester.pumpAndSettle();
    expect(find.text('Fictional cafe'), findsOneWidget);
    api.load = () async => throw StateError('fictional-sensitive-error');
    await tester.tap(find.byKey(const ValueKey('sandbox-load')));
    await tester.pumpAndSettle();
    expect(find.text('Fictional cafe'), findsNothing);
    expect(find.byKey(const ValueKey('sandbox-error')), findsOneWidget);
    expect(find.textContaining('fictional-sensitive-error'), findsNothing);
    expect(api.writes, 0);
  });
  testWidgets(
    'late response cannot appear after navigation disposes the preview',
    (tester) async {
      final api = PreviewApi();
      final pending = Completer<SandboxPreview>();
      api.load = () => pending.future;
      await tester.pumpWidget(panel(api));
      await tester.tap(find.byKey(const ValueKey('sandbox-load')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('Elsewhere')));
      pending.complete(SandboxPreview.fromJson(fictionalPreview()));
      await tester.pumpAndSettle();
      expect(find.text('Fictional cafe'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('not-ready and removals cannot look like posted purchases', (
    tester,
  ) async {
    final api = PreviewApi();
    api.load =
        () async =>
            SandboxPreview.fromJson(fictionalPreview(ready: false, rows: []));
    await tester.pumpWidget(panel(api));
    await tester.tap(find.byKey(const ValueKey('sandbox-load')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sandbox data is not ready'), findsOneWidget);
    api.load =
        () async => SandboxPreview.fromJson(
          fictionalPreview(
            rows: [
              {'kind': 'removed', 'accountId': 'a', 'sourceId': 's'},
            ],
          ),
        );
    await tester.tap(find.byKey(const ValueKey('sandbox-load')));
    await tester.pumpAndSettle();
    expect(find.text('Removed source record'), findsOneWidget);
    expect(find.text('\$0.00'), findsNothing);
    expect(api.writes, 0);
  });
  testWidgets(
    'server Connections opens the real panel without automatic provider retrieval',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PreviewApi();
      await tester.pumpWidget(
        MaterialApp(
          home: FinanceShell(
            api: api,
            username: 'Fictional',
            onLogout: () {},
            onToggleTheme: () {},
            onCheckUpdates: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Connections'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServerSandboxPanel), findsOneWidget);
      expect(api.previews, 0);
      expect(api.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
