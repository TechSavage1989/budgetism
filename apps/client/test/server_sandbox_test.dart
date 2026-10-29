import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:budgetism/finance_api.dart';
import 'package:budgetism/server_sandbox.dart';

Map<String, dynamic> fictionalRow({
  String kind = 'added',
  int amount = -1234,
  bool pending = false,
}) => {
  'kind': kind,
  'accountId': 'fictional-account',
  'sourceId': 'fictional-source',
  'amountMinor': amount,
  'date': '2026-10-29',
  'description': 'Fictional cafe',
  'pending': pending,
  'pendingSourceId': pending ? null : 'fictional-pending',
};
Map<String, dynamic> fictionalPreview({
  bool ready = true,
  List<Object?>? rows,
}) => {
  'fictional': true,
  'ready': ready,
  'changes': rows ?? [fictionalRow()],
};

void main() {
  test(
    'preview preserves exact signed cents, calendar dates and pending identity',
    () {
      final p = SandboxPreview.fromJson(fictionalPreview());
      expect(p.ready, isTrue);
      expect(p.activity.single.amountMinor, -1234);
      expect(p.activity.single.date, '2026-10-29');
      expect(p.activity.single.pendingSourceId, 'fictional-pending');
      expect(() => p.activity.clear(), throwsUnsupportedError);
    },
  );
  test(
    'identity-only removal and initial not-ready response remain distinct',
    () {
      final p = SandboxPreview.fromJson(
        fictionalPreview(
          rows: [
            {'kind': 'removed', 'accountId': 'a', 'sourceId': 's'},
          ],
        ),
      );
      expect(p.activity.single.amountMinor, isNull);
      expect(
        SandboxPreview.fromJson(fictionalPreview(ready: false, rows: [])).ready,
        isFalse,
      );
    },
  );
  test(
    'rejects malformed, non-fictional, fractional, excessive and invalid date data',
    () {
      final cases = [
        {...fictionalPreview(), 'fictional': false},
        fictionalPreview(ready: false),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'amountMinor': 1.5},
          ],
        ),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'amountMinor': -9223372036854775808},
          ],
        ),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'date': '2026-02-30'},
          ],
        ),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'date': '0000-01-01'},
          ],
        ),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'accountId': ''},
          ],
        ),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'kind': 'unknown'},
          ],
        ),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'pending': 'false'},
          ],
        ),
        fictionalPreview(
          rows: [
            {...fictionalRow(), 'kind': 'removed'},
          ],
        ),
      ];
      for (final value in cases) {
        expect(() => SandboxPreview.fromJson(value), throwsFormatException);
      }
    },
  );
  test(
    'HTTPS bearer preview uses one explicit POST with redirects disabled',
    () async {
      var calls = 0;
      final api = FinanceApi(
        'https://fictional.example:55443',
        previewClientFactory:
            () => MockClient((r) async {
              calls++;
              expect(r.method, 'POST');
              expect(
                r.url.toString(),
                'https://fictional.example:55443/api/bank/sandbox/preview',
              );
              expect(r.headers['Authorization'], 'Bearer fictional-session');
              expect(r.followRedirects, isFalse);
              expect(r.body, isEmpty);
              return http.Response(jsonEncode(fictionalPreview()), 200);
            }),
      )..token = 'fictional-session';
      expect((await api.sandboxPreview()).activity.single.amountMinor, -1234);
      expect(calls, 1);
    },
  );
  test(
    'missing session and unsafe URL never create a network client',
    () async {
      http.Client forbidden() => throw StateError('Must not create transport');
      final missing = FinanceApi(
        'https://fictional.example',
        previewClientFactory: forbidden,
      );
      await expectLater(
        missing.sandboxPreview(),
        throwsA(isA<FinanceApiException>()),
      );
      for (final url in [
        'http://fictional.example',
        'https://user:private@fictional.example',
        'https://fictional.example?private=value',
      ]) {
        final api = FinanceApi(url, previewClientFactory: forbidden)
          ..token = 'fictional-session';
        await expectLater(
          api.sandboxPreview(),
          throwsA(isA<FinanceApiException>()),
        );
      }
    },
  );
  test('provider/server error bodies and redirects are never echoed', () async {
    for (final status in [302, 401, 404, 429, 502, 503]) {
      final api = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient(
              (_) async => http.Response(
                'fictional-sensitive-response',
                status,
                headers: {'location': 'https://other.example'},
              ),
            ),
      )..token = 'fictional-session';
      try {
        await api.sandboxPreview();
        fail('Expected failure');
      } on FinanceApiException catch (e) {
        expect(e.message, isNot(contains('fictional-sensitive-response')));
        expect(e.statusCode, status);
      }
    }
  });
  test('response size limit and malformed payload fail closed', () async {
    for (final body in ['x' * (4 * 1024 * 1024 + 1), '{broken']) {
      final api = FinanceApi(
        'https://fictional.example',
        previewClientFactory:
            () => MockClient((_) async => http.Response(body, 200)),
      )..token = 'fictional-session';
      await expectLater(
        api.sandboxPreview(),
        throwsA(isA<FinanceApiException>()),
      );
    }
  });
  test('response from a signed-out session is discarded', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = FinanceApi(
      'https://fictional.example',
      previewClientFactory:
          () => MockClient((_) {
            started.complete();
            return response.future;
          }),
    )..token = 'fictional-session';
    final future = api.sandboxPreview();
    final assertion = expectLater(future, throwsA(isA<FinanceApiException>()));
    await started.future;
    api.token = null;
    response.complete(http.Response(jsonEncode(fictionalPreview()), 200));
    await assertion;
  });
}
