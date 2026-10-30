import 'release_feed.dart';
import 'update_pending.dart';

Future<UpdateStartupResult> applyPendingClientUpdate() async => const UpdateStartupResult();
Future<void> markClientUpdateReady() async {}
Future<void> preparePendingClientUpdate(ReleaseInfo release, String path, {bool retry = false, bool queue = true}) async =>
  throw UnsupportedError('Automatic installation is available only on Windows.');
Future<void> cancelPendingClientUpdate() async {}
Future<bool> isClientUpdateAttempted(ReleaseInfo release) async => false;
