import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/main.dart' show ConnectionScreen;
import 'package:budgetism/server_address.dart';

class AddressApiFixture extends FinanceApi {
  AddressApiFixture(super.serverUrl);
  int handshakes = 0, logins = 0;
  Future<bool> Function()? handshake;
  Future<String> Function()? authenticate;
  @override
  Future<bool> isInitialized() async {
    handshakes++;
    return handshake == null ? true : handshake!();
  }

  @override
  Future<String> login(String username, String password) async {
    logins++;
    return authenticate == null ? 'Fictional owner' : authenticate!();
  }
}

class LateAddressPreferences extends ServerAddressPreferences {
  final loaded = Completer<String?>();
  @override
  Future<String?> read() => loaded.future;
}

class FailingAddressPreferences extends ServerAddressPreferences {
  @override
  Future<void> save(String? address) async =>
      throw StateError('fictional-secret-bearing-error');
}

Widget addressScreen({
  ServerAddressPreferences? store,
  FinanceApi Function(String)? api,
  void Function(FinanceApi, String)? signedIn,
}) => MaterialApp(
  home: ConnectionScreen(
    addressPreferences: store,
    apiFactory: api,
    onSignedIn: signedIn ?? (_, _) {},
    onCheckUpdates: () {},
  ),
);
Finder addressField() => find.widgetWithText(TextField, 'Private server URL');
Future<void> press(WidgetTester tester, String label) async {
  await tester.pump();
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('only credential-free HTTPS addresses can be remembered', () async {
    for (final value in [
      'http://fictional.example',
      'https://name:password@fictional.example',
      'https://fictional.example/?secret=fictional',
      'https://fictional.example/#fictional',
      'https://fictional.example:0',
      'https://fictional.example:65536',
      'https://fictional.example/with space',
      '',
    ]) {
      expect(ServerAddressPreferences.canonical(value), isNull);
    }
    expect(
      ServerAddressPreferences.canonical(
        ' https://fictional.example/private/ ',
      ),
      'https://fictional.example/private',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance.theme', 'light');
    final store = ServerAddressPreferences();
    await store.save('https://fictional.example/');
    expect(await store.read(), 'https://fictional.example');
    await store.save(null);
    expect(await store.read(), isNull);
    expect(prefs.getString('appearance.theme'), 'light');
    expect(prefs.getKeys(), {'appearance.theme'});
  });
  testWidgets('remembered address loads without connecting or signing in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ServerAddressPreferences.defaultKey: 'https://fictional.example',
    });
    var calls = 0;
    await tester.pumpWidget(
      addressScreen(
        api: (url) {
          calls++;
          return AddressApiFixture(url);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(
      tester.widget<TextField>(addressField()).controller!.text,
      'https://fictional.example',
    );
    expect(calls, 0);
    expect(find.text('Forget saved address'), findsOneWidget);
  });
  testWidgets(
    'opt-in saves only the successful HTTPS address and never credentials',
    (tester) async {
      final api = AddressApiFixture('https://fictional.example');
      await tester.pumpWidget(addressScreen(api: (_) => api));
      await tester.pumpAndSettle();
      await tester.enterText(addressField(), 'https://fictional.example/');
      await press(tester, 'Remember server address on this device');
      await press(tester, 'Connect to server');
      await tester.enterText(
        find.widgetWithText(TextField, 'Username'),
        'fictional-owner',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'fictional-password-not-to-save',
      );
      await press(tester, 'Sign in');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {ServerAddressPreferences.defaultKey});
      expect(
        prefs.getString(ServerAddressPreferences.defaultKey),
        'https://fictional.example',
      );
      expect(api.logins, 1);
    },
  );
  testWidgets('default connection does not remember an address', (
    tester,
  ) async {
    await tester.pumpWidget(addressScreen(api: AddressApiFixture.new));
    await tester.pumpAndSettle();
    await tester.enterText(addressField(), 'https://fictional.example');
    await press(tester, 'Connect to server');
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
  testWidgets(
    'failed handshake preserves the last saved address and hides raw failures',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ServerAddressPreferences.defaultKey: 'https://saved.example',
      });
      final api = AddressApiFixture('https://failed.example')
        ..handshake =
            () async => throw StateError('fictional-secret-bearing-error');
      await tester.pumpWidget(addressScreen(api: (_) => api));
      await tester.pumpAndSettle();
      await tester.enterText(addressField(), 'https://failed.example');
      await press(tester, 'Connect to server');
      expect(
        (await SharedPreferences.getInstance()).getString(
          ServerAddressPreferences.defaultKey,
        ),
        'https://saved.example',
      );
      expect(
        find.textContaining('fictional-secret-bearing-error'),
        findsNothing,
      );
      expect(find.widgetWithText(TextField, 'Password'), findsNothing);
    },
  );
  testWidgets('late preference load cannot overwrite a typed address', (
    tester,
  ) async {
    final store = LateAddressPreferences();
    await tester.pumpWidget(addressScreen(store: store));
    await tester.pump();
    await tester.enterText(addressField(), 'https://typed.example');
    store.loaded.complete('https://previous.example');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(addressField()).controller!.text,
      'https://typed.example',
    );
  });
  testWidgets(
    'editing destination rejects a late handshake and clears credential fields',
    (tester) async {
      final pending = Completer<bool>();
      final old = AddressApiFixture('https://old.example')
        ..handshake = () => pending.future;
      await tester.pumpWidget(
        addressScreen(
          api: (url) => url == old.serverUrl ? old : AddressApiFixture(url),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(addressField(), old.serverUrl);
      await tester.ensureVisible(find.text('Connect to server'));
      await tester.tap(find.text('Connect to server'));
      await tester.pump();
      await tester.enterText(addressField(), 'https://new.example');
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Password'), findsNothing);
      await press(tester, 'Connect to server');
      await tester.enterText(
        find.widgetWithText(TextField, 'Username'),
        'fictional-owner',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'fictional-password',
      );
      await tester.enterText(addressField(), 'https://third.example');
      await press(tester, 'Connect to server');
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Username'))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Password'))
            .controller!
            .text,
        isEmpty,
      );
      expect(old.logins, 0);
    },
  );
  testWidgets(
    'forget removes only the saved address and failed saving does not block connection',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ServerAddressPreferences.defaultKey: 'https://saved.example',
        'appearance.theme': 'light',
      });
      await tester.pumpWidget(addressScreen());
      await tester.pumpAndSettle();
      await press(tester, 'Forget saved address');
      expect((await SharedPreferences.getInstance()).getKeys(), {
        'appearance.theme',
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        addressScreen(
          store: FailingAddressPreferences(),
          api: AddressApiFixture.new,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(addressField(), 'https://fictional.example');
      await press(tester, 'Remember server address on this device');
      await press(tester, 'Connect to server');
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(
        find.textContaining('preference could not be saved'),
        findsOneWidget,
      );
      expect(
        find.textContaining('fictional-secret-bearing-error'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'a completed login after disposal cannot sign in a different screen',
    (tester) async {
      final pending = Completer<String>();
      var callbacks = 0;
      final api = AddressApiFixture('https://fictional.example')
        ..authenticate = () => pending.future;
      await tester.pumpWidget(
        addressScreen(api: (_) => api, signedIn: (_, _) => callbacks++),
      );
      await tester.pumpAndSettle();
      await tester.enterText(addressField(), api.serverUrl);
      await press(tester, 'Connect to server');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(tester.widget<TextField>(addressField()).enabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete('Fictional owner');
      await tester.pumpAndSettle();
      expect(callbacks, 0);
    },
  );
}
