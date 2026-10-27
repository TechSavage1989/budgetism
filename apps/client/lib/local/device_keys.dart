import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'vault.dart';

/// Passwords are never stored. Only a randomly generated device-mode AES key
/// is persisted, under a per-vault random identifier, using the OS key store.
class SecureDeviceKeys implements DeviceKeyStore {
  const SecureDeviceKeys();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String name) => _storage.read(key: name);
  @override
  Future<void> write(String name, String value) => _storage.write(key: name, value: value);
  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}
