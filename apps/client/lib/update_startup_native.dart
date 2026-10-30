import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'release_feed.dart';
import 'update_pending.dart';

Future<Directory> _root() async {
  final base = await getApplicationSupportDirectory();
  final root = Directory('${base.path}${Platform.pathSeparator}updates');
  await root.create(recursive: true);
  return root;
}
String _join(String a, String b) => '$a${Platform.pathSeparator}$b';
Future<Map<String, dynamic>> _readObject(File file) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file || await file.length() > 16384) {
    throw const FormatException('Invalid update metadata file.');
  }
  final value = jsonDecode(await file.readAsString());
  if (value is! Map) throw const FormatException('Invalid update metadata.');
  return Map<String, dynamic>.from(value);
}
Future<void> _writeObject(File file, Map<String, Object> value) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
  await temporary.writeAsString(jsonEncode(value), flush: true);
  await temporary.rename(file.path);
}
File _archive(Directory root, PendingClientUpdate update) =>
  File(_join(_join(_join(root.path, 'packages'), update.identity), 'Budgetism-Windows-x64.zip'));
File _blocked(Directory root, PendingClientUpdate update) => File(_join(_join(root.path, 'attempted'), '${update.identity}.json'));
List<String> _verificationArguments(PendingClientUpdate update, String archive) => [
  '--archive', archive, '--sha256', update.sha256, '--version', update.version,
  '--require-update-protocol', '$clientUpdateProtocol', '--require-client-api-contract', '$clientApiContract',
];

Future<String> _installedHelper() async {
  final executable = File(Platform.resolvedExecutable);
  final folder = executable.parent;
  final marker = await _readObject(File(_join(folder.path, 'app-release.json')));
  if (marker['appId'] != 'TechSavage1989.Budgetism' || marker['platform'] != 'windows-x64' ||
      marker['version'] != budgetismVersion || marker['updateProtocol'] != clientUpdateProtocol ||
      marker['clientApiContract'] != clientApiContract) {
    throw const FormatException('Current installation is not compatible with automatic updates.');
  }
  final helper = File(_join(folder.path, 'Budgetism-Updater.exe'));
  if (await FileSystemEntity.type(helper.path, followLinks: false) != FileSystemEntityType.file) {
    throw const FormatException('The installed update helper is unavailable.');
  }
  return helper.path;
}

Future<void> _verify(PendingClientUpdate update, File archive, String helper) async {
  final result = await Process.run(helper, [..._verificationArguments(update, archive.path), '--verify-only'])
    .timeout(const Duration(minutes: 2));
  if (result.exitCode != 0) {
    throw const FormatException('Package verification or client/API compatibility check failed.');
  }
}

Future<bool> isClientUpdateAttempted(ReleaseInfo release) async {
  if (!Platform.isWindows) return false;
  final update = PendingClientUpdate.fromRelease(release);
  return _blocked(await _root(), update).exists();
}

/// Only called after download; this never exits the app or accesses a workspace.
Future<void> preparePendingClientUpdate(ReleaseInfo release, String path, {bool retry = false, bool queue = true}) async {
  if (!Platform.isWindows) throw UnsupportedError('Windows updates only.');
  final update = PendingClientUpdate.fromRelease(release), root = await _root();
  if (compareVersions(update.version, budgetismVersion) <= 0) throw const FormatException('The update is not newer.');
  final expected = _archive(root, update);
  if (File(path).absolute.path.toLowerCase() != expected.absolute.path.toLowerCase() ||
      await FileSystemEntity.type(expected.path, followLinks: false) != FileSystemEntityType.file) {
    throw const FormatException('Update archive is outside owned staging.');
  }
  if (await _blocked(root, update).exists() && !retry) throw const FormatException('This update already had an installation attempt. Retry explicitly.');
  await _verify(update, expected, await _installedHelper());
  if (retry && await _blocked(root, update).exists()) await _blocked(root, update).delete();
  if (queue) await _writeObject(File(_join(root.path, 'pending.json')), update.toJson());
}

Future<void> cancelPendingClientUpdate() async {
  if (!Platform.isWindows) return;
  final file = File(_join((await _root()).path, 'pending.json'));
  if (await file.exists()) await file.delete();
}

/// The only installation entrypoint. main awaits it before creating any
/// ConnectionScreen, server client, vault, dialog or financial operation.
Future<UpdateStartupResult> applyPendingClientUpdate() async {
  if (!Platform.isWindows) return const UpdateStartupResult();
  if (Platform.environment['BUDGETISM_UPDATE_SKIP_ONCE'] == '1') {
    return UpdateStartupResult(message: Platform.environment['BUDGETISM_UPDATE_ROLLBACK'] == '1'
      ? 'Previous version restored after an update failure. Automatic retry is blocked; review Updates before retrying.' : null);
  }
  File? cancellation;
  Process? installer;
  String? requestId;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(automaticUpdatesPreference) != true) return const UpdateStartupResult();
    final root = await _root(), pending = File(_join((await _root()).path, 'pending.json'));
    if (!await pending.exists()) return const UpdateStartupResult();
    final update = PendingClientUpdate.parse(await _readObject(pending));
    if (compareVersions(update.version, budgetismVersion) <= 0) {
      await pending.delete();
      return const UpdateStartupResult(message: 'The queued update is already installed or older; it was not applied.');
    }
    if (await _blocked(root, update).exists()) {
      await pending.delete();
      return const UpdateStartupResult(message: 'The previous update attempt was not repeated. Your installed version is available; retry through Updates if needed.');
    }
    final id = const Uuid().v4();
    requestId = id;
    final attempt = Directory(_join(_join(root.path, 'attempts'), id));
    await attempt.create(recursive: true);
    // Consume before starting a helper. An interrupted attempt is never retried
    // by a subsequent automatic launch.
    await _writeObject(_blocked(root, update), {...update.toJson(), 'requestId': id});
    await pending.rename(_join(attempt.path, 'pending.json'));
    final archive = _archive(root, update), installedHelper = await _installedHelper();
    await _verify(update, archive, installedHelper);
    final helper = await File(installedHelper).copy(_join(attempt.path, 'Budgetism-Updater.exe'));
    final executable = File(Platform.resolvedExecutable);
    final admission = File(_join(attempt.path, 'admitted.json'));
    final result = File(_join(attempt.path, 'result.json'));
    cancellation = File(_join(attempt.path, 'cancel.json'));
    installer = await Process.start(helper.path, [..._verificationArguments(update, archive.path),
      '--install-dir', executable.parent.path, '--launch-name', executable.uri.pathSegments.last,
      '--parent-pid', '$pid', '--request-id', id, '--admission-file', admission.path, '--result-file', result.path, '--cancel-file', cancellation.path],
      mode: ProcessStartMode.normal);
    unawaited(installer.stdout.drain<void>().catchError((_) {}));
    unawaited(installer.stderr.drain<void>().catchError((_) {}));
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (await admission.exists()) {
        final accepted = await _readObject(admission);
        if (accepted['requestId'] != id || accepted['version'] != update.version || accepted['status'] != 'admitted') {
          throw const FormatException('Update admission did not match this attempt.');
        }
        // There are no mounted application screens or sessions at this point.
        exit(0);
      }
      if (await result.exists()) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await _writeObject(cancellation, {'requestId': id, 'status': 'cancelled'});
    return const UpdateStartupResult(message: 'The update could not safely start. The existing application was kept; no automatic retry will occur.');
  } catch (_) {
    if (cancellation != null && requestId != null) {
      try { await _writeObject(cancellation, {'requestId': requestId, 'status': 'cancelled'}); } catch (_) {
        // Without a durable cancellation, do not expose any financial screen
        // while the admitted helper could still observe this parent exiting.
        if (installer != null) await installer.exitCode;
      }
    }
    return const UpdateStartupResult(message: 'The queued update was not applied. Verification, compatibility or safe startup checks failed. The existing application is available.');
  }
}

/// The helper chooses the challenge. Never write a path outside this app's
/// update-attempt directory, even if environment variables were manipulated.
Future<void> markClientUpdateReady() async {
  if (!Platform.isWindows) return;
  final env = Platform.environment, path = Platform.environment['BUDGETISM_UPDATE_READY_PATH'];
  if (path == null) return;
  final nonce = env['BUDGETISM_UPDATE_READY_NONCE'], version = env['BUDGETISM_UPDATE_VERSION'];
  if (nonce == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(nonce) || version != budgetismVersion) return;
  try {
    final root = await _root(), file = File(path);
    final attempts = Directory(_join(root.path, 'attempts'));
    final parent = file.parent;
    if (file.uri.pathSegments.last != 'ready.json' ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(parent.uri.pathSegments.where((s) => s.isNotEmpty).last) ||
        parent.parent.absolute.path.toLowerCase() != attempts.absolute.path.toLowerCase() ||
        await FileSystemEntity.type(parent.path, followLinks: false) != FileSystemEntityType.directory) {
      return;
    }
    // Canonical parent containment also rejects junction/symlink escapes.
    final canonicalAttempts = (await attempts.resolveSymbolicLinks()).toLowerCase();
    final canonicalParent = Directory(await parent.resolveSymbolicLinks());
    if (canonicalParent.parent.path.toLowerCase() != canonicalAttempts) return;
    await _installedHelper();
    await _writeObject(file, {'version': budgetismVersion, 'nonce': nonce, 'pid': pid});
  } catch (_) { /* Missing readiness safely triggers helper rollback. */ }
}
