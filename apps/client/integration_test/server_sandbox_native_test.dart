import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/main.dart' show FinanceShell;
import 'package:budgetism/server_sandbox.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import '../test/server_bank_test.dart' show bankState;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native server preview is explicit, clears failures, and preserves a separate encrypted workspace',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory dir;
      LocalVault? vault;
      const keys = SecureDeviceKeys();
      final api = FictionalServerApi();
      final capture = GlobalKey();
      try {
        await tester.runAsync(() async {
          dir = Directory.systemTemp.createTempSync(
            'budgetism-sandbox-isolation-',
          );
          vault = await LocalVault.open(
            SqliteVaultStorage(
              '${dir.path}${Platform.pathSeparator}fictional.sqlite3',
            ),
            '',
            create: true,
            requirePassword: false,
            deviceKeys: keys,
          );
          await vault!.apply('account', {
            'operationId': 'fictional-account',
            'name': 'Separate fictional local account',
            'type': 'checking',
            'currency': 'USD',
            'openingBalanceMinor': 10000,
          });
        });
        final before = await tester.runAsync(() => vault!.storage.read());
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: capture,
              child: FinanceShell(
                api: api,
                username: 'Fictional',
                onLogout: () {},
                onToggleTheme: () {},
                onCheckUpdates: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder nav(String name) => find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(name),
        );
        await tester.tap(nav('Connections'));
        await tester.pumpAndSettle();
        expect(api.previews, 0);
        await tester.tap(find.byKey(const ValueKey('sandbox-load')));
        await tester.pumpAndSettle();
        expect(api.previews, 1);
        expect(find.text('Fictional cafe'), findsOneWidget);
        expect(find.text('-\$12.34'), findsOneWidget);
        expect(find.text('\$0.29'), findsOneWidget);
        expect(find.textContaining('Pending · Added'), findsOneWidget);
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await tester.runAsync(() async {
          final file = File('build/sandbox-native-preview.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        api.fail = true;
        await tester.tap(find.byKey(const ValueKey('sandbox-load')));
        await tester.pumpAndSettle();
        expect(find.text('Fictional cafe'), findsNothing);
        expect(find.byKey(const ValueKey('sandbox-error')), findsOneWidget);
        await tester.tap(nav('Home'));
        await tester.pumpAndSettle();
        await tester.tap(nav('Connections'));
        await tester.pumpAndSettle();
        expect(api.previews, 2);
        expect(find.text('Fictional cafe'), findsNothing);
        expect(api.writes, 0);
        await tester.tap(nav('Needs Review'));
        await tester.pumpAndSettle();
        expect(find.text('Server Sandbox · durable review'), findsOneWidget);
        expect(api.bankWrites, isEmpty);
        expect(find.text('Fictional cafe'), findsOneWidget);
        final reviewImage = await boundary.toImage();
        final reviewBytes = await reviewImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        reviewImage.dispose();
        await tester.runAsync(
          () => File(
            'build/sandbox-native-review.png',
          ).writeAsBytes(reviewBytes!.buffer.asUint8List()),
        );
        api.bankFail = true;
        await tester.tap(find.text('Refresh fictional sources'));
        await tester.pumpAndSettle();
        final original = Map<String, dynamic>.from(api.bankWrites.single);
        api.bankFail = false;
        await tester.tap(find.text('Retry unchanged action'));
        await tester.pumpAndSettle();
        expect(api.bankWrites.last, original);
        expect(api.bankWrites.length, 2);
        await tester.tap(nav('Home'));
        await tester.pumpAndSettle();
        await tester.tap(nav('Needs Review'));
        await tester.pumpAndSettle();
        expect(find.text('Fictional cafe'), findsOneWidget);
        expect(api.bankWrites.length, 2);
        expect(await tester.runAsync(() => vault!.storage.read()), before);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          if (vault != null) {
            await vault!.setPasswordRequired(
              true,
              newPassword: 'fictional sandbox cleanup',
            );
            await vault!.close();
          }
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

class FictionalServerApi extends FinanceApi {
  FictionalServerApi() : super('https://fictional.example') {
    token = 'fictional-session';
  }
  int previews = 0, writes = 0;
  bool fail = false;
  bool bankFail = false;
  final bankWrites = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> bankRequest(
    String route, [
    Map<String, dynamic>? body,
    int? offset,
    int? version,
  ]) async {
    if (body == null) return bankState();
    bankWrites.add({'route': route, ...body});
    if (bankFail) throw FinanceApiException('Fictional lost response', 0);
    return {'connectionVersion': 5, 'ready': true};
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

  @override
  Future<SandboxPreview> sandboxPreview() async {
    previews++;
    if (fail) throw StateError('Fictional failure');
    Map<String, dynamic> row(
      String id,
      String description,
      int amount,
      bool pending,
    ) => {
      'kind': 'added',
      'accountId': 'fictional-account',
      'sourceId': id,
      'date': '2026-10-29',
      'description': description,
      'amountMinor': amount,
      'pending': pending,
    };
    return SandboxPreview.fromJson({
      'fictional': true,
      'ready': true,
      'changes': [
        row('fictional-one', 'Fictional cafe', -1234, false),
        row('fictional-two', 'Fictional refund', 29, false),
        row('fictional-three', 'Fictional pending purchase', -250, true),
        {
          'kind': 'removed',
          'accountId': 'fictional-other-account',
          'sourceId': 'fictional-removed',
        },
      ],
    });
  }
}
