import 'package:shared_preferences/shared_preferences.dart';

// Connection metadata only. Never pass usernames, passwords, sessions or provider credentials.
class ServerAddressPreferences {
  ServerAddressPreferences({
    this.key = defaultKey,
    Future<SharedPreferences> Function()? load,
  }) : _load = load ?? SharedPreferences.getInstance;
  static const defaultKey = 'connection.httpsAddress.v1';
  final String key;
  final Future<SharedPreferences> Function() _load;
  Future<void> _writes = Future.value();

  static String? canonical(String value) {
    final text = value.trim();
    if (text.length > 2048 || RegExp(r'[\x00-\x20\\]').hasMatch(text)) {
      return null;
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      return null;
    }
    return uri
        .replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''))
        .toString();
  }

  Future<String?> read() async {
    await _writes;
    final saved = (await _load()).get(key);
    return saved is String ? canonical(saved) : null;
  }

  Future<void> save(String? address) {
    final normalized = address == null ? null : canonical(address);
    if (address != null && normalized == null) {
      throw const FormatException('Trusted HTTPS address required');
    }
    final write = _writes.then((_) async {
      final preferences = await _load();
      final ok =
          normalized == null
              ? await preferences.remove(key)
              : await preferences.setString(key, normalized);
      if (!ok) throw StateError('Address preference could not be saved');
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
