import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'release_feed.dart';
import 'release_download.dart';
import 'update_startup.dart';
import 'update_pending.dart';

/// Injectable boundaries keep async preference/download races testable without
/// invoking native installers. Production installation remains startup-only.
class ClientUpdateActions {
  const ClientUpdateActions({required this.supported, required this.download,
    required this.prepare, required this.cancel, required this.attempted, required this.savePreference});
  final bool supported;
  final Future<String> Function(ReleaseInfo, void Function(double)) download;
  final Future<void> Function(ReleaseInfo, String, bool, bool) prepare;
  final Future<void> Function() cancel;
  final Future<bool> Function(ReleaseInfo) attempted;
  final Future<bool> Function(bool) savePreference;
  static ClientUpdateActions production() => ClientUpdateActions(
    supported: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
    download: (release, progress) => downloadVerifiedRelease(release, onProgress: progress),
    prepare: (release, path, retry, queue) => preparePendingClientUpdate(release, path, retry: retry, queue: queue),
    cancel: cancelPendingClientUpdate, attempted: isClientUpdateAttempted,
    savePreference: (enabled) async => (await SharedPreferences.getInstance()).setBool(automaticUpdatesPreference, enabled),
  );
}
