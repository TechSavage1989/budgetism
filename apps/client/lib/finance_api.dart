import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'server_sandbox.dart';

class FinanceApiException implements Exception {
  FinanceApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class FinanceApi {
  FinanceApi(this.serverUrl, {http.Client Function()? previewClientFactory})
    : _previewClientFactory = previewClientFactory ?? http.Client.new;
  final String serverUrl;
  final http.Client Function() _previewClientFactory;
  bool get isDemo => false;
  String? token;

  Uri _uri(String path) {
    final base = serverUrl.trim().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  void requireHttpsServer() {
    final base = Uri.tryParse(serverUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw FinanceApiException('Use a trusted private HTTPS server URL.', 0);
    }
  }

  Future<dynamic> request(String method, String path, [Map<String, dynamic>? body]) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      final uri = _uri(path);
      final encoded = body == null ? null : jsonEncode(body);
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
          break;
        default: throw ArgumentError('Unsupported request method.');
      }
      dynamic payload;
      try { payload = jsonDecode(response.body); } catch (_) { payload = null; }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = payload is Map ? (payload['error'] ?? payload['detail'])?.toString() : null;
        throw FinanceApiException(message ?? 'Server error (${response.statusCode})', response.statusCode);
      }
      return payload;
    } on FinanceApiException {
      rethrow;
    } catch (error) {
      throw FinanceApiException('Unable to reach your private server. Check its URL, VPN, and connection. ($error)', 0);
    }
  }

  Future<bool> isInitialized() async =>
      (await request('GET', '/api/setup/status') as Map)['initialized'] == true;

  Future<void> initialize(String username, String password, String bootstrapToken) async {
    await request('POST', '/api/setup/owner', {
      'username': username, 'password': password, 'bootstrapToken': bootstrapToken,
    });
  }

  Future<String> login(String username, String password) async {
    final data = await request('POST', '/api/auth/login', {
      'username': username, 'password': password,
    }) as Map;
    token = data['token'] as String;
    return data['username'] as String;
  }

  Future<void> logout() async {
    try { await request('POST', '/api/auth/logout', {}); } finally { token = null; }
  }

  Future<SandboxPreview> sandboxPreview() async {
    final session = token;
    if (session == null || session.isEmpty) {
      throw FinanceApiException('Sign in to your private server first.', 401);
    }
    requireHttpsServer();
    final client = _previewClientFactory();
    try {
      Future<SandboxPreview> fetch() async {
        final request = http.Request('POST', _uri('/api/bank/sandbox/preview'))
          ..followRedirects = false
          ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $session'});
        final response = await client.send(request);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final message = switch (response.statusCode) {
            401 || 403 => 'Your server session expired. Sign in again.',
            404 => 'This server does not support Sandbox previews yet.',
            429 => 'Too many preview requests. Wait before trying again.',
            503 => 'Sandbox preview is not configured on this server.',
            >= 300 && < 400 => 'Sandbox preview redirects are blocked.',
            _ => 'The server could not complete the Sandbox preview.',
          };
          throw FinanceApiException(message, response.statusCode);
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 4 * 1024 * 1024) {
            throw FinanceApiException('Sandbox preview exceeds the client size limit.', 0);
          }
          bytes.add(chunk);
        }
        final preview = SandboxPreview.fromJson(jsonDecode(utf8.decode(bytes.takeBytes())));
        if (token != session) {
          throw FinanceApiException('Your server session changed. Sign in again.', 401);
        }
        return preview;
      }
      return await fetch().timeout(const Duration(seconds: 95));
    } on FinanceApiException {
      rethrow;
    } on FormatException {
      throw FinanceApiException('The server returned an invalid Sandbox preview.', 0);
    } catch (_) {
      throw FinanceApiException('Unable to retrieve the Sandbox preview. Check HTTPS trust and your connection.', 0);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> snapshot() async =>
      Map<String, dynamic>.from(await request('GET', '/api/sync/snapshot') as Map);

  Future<void> createAccount(Map<String, dynamic> data) async =>
      request('POST', '/api/accounts', data);

  Future<void> createTransaction(Map<String, dynamic> data) async =>
      request('POST', '/api/transactions', data);
}
