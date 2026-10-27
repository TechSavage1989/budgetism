import 'dart:convert';
import 'package:http/http.dart' as http;

class FinanceApiException implements Exception {
  FinanceApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class FinanceApi {
  FinanceApi(this.serverUrl);
  final String serverUrl;
  bool get isDemo => false;
  String? token;

  Uri _uri(String path) {
    final base = serverUrl.trim().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
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

  Future<Map<String, dynamic>> snapshot() async =>
      Map<String, dynamic>.from(await request('GET', '/api/sync/snapshot') as Map);

  Future<void> createAccount(Map<String, dynamic> data) async =>
      request('POST', '/api/accounts', data);

  Future<void> createTransaction(Map<String, dynamic> data) async =>
      request('POST', '/api/transactions', data);
}
