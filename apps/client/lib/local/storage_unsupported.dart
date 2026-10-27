import 'vault.dart';
const localStorageSupported = false;
Future<VaultStorage> openVaultStorage() => throw UnsupportedError('Saved local workspaces require the native application. Browser mode does not persist financial records.');
