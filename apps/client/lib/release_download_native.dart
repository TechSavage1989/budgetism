import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'release_feed.dart';

const _maxBytes = 700 * 1024 * 1024;

/// Downloads a release only after GitHub supplies a SHA-256 digest. Ensures
/// redirects remain HTTPS and on GitHub's release-asset host allowlist.
/// Archive extraction and installation are intentionally delegated to a
/// separate Windows helper, never performed inside the running executable.
Future<String> downloadVerifiedRelease(ReleaseInfo release,
    {void Function(double)? onProgress}) async {
  if (!Platform.isWindows) throw UnsupportedError('Windows portable updates only.');
  if (!release.hasVerifiedArchive) throw const FormatException('No expected SHA-256 digest is available.');
  var uri = Uri.parse(release.archiveUrl!);
  if (!_allowed(uri, firstHop: true)) throw const FormatException('Untrusted release download URL.');

  final base = await getApplicationSupportDirectory();
  final stage = Directory('${base.path}${Platform.pathSeparator}updates${Platform.pathSeparator}staging');
  await stage.create(recursive: true);
  final pending = File('${stage.path}${Platform.pathSeparator}Budgetism-Windows-x64.zip.part');
  final completed = File('${stage.path}${Platform.pathSeparator}Budgetism-Windows-x64.zip');
  if (await pending.exists()) await pending.delete();
  final client = http.Client();
  try {
    http.StreamedResponse? response;
    for (var i = 0; i < 5; i++) {
      final request = http.Request('GET', uri)..followRedirects = false;
      response = await client.send(request).timeout(const Duration(seconds: 25));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final target = response.headers['location'];
        if (target == null) throw const FormatException('Missing redirect location.');
        final next = uri.resolve(target);
        if (!_allowed(next, firstHop: false)) throw const FormatException('Release redirected outside trusted hosts.');
        uri = next;
        await response.stream.drain<void>();
        continue;
      }
      break;
    }
    if (response == null || response.statusCode != 200) {
      throw HttpException('Unable to retrieve release asset (HTTP ${response?.statusCode ?? 'unknown'}).');
    }
    if (response.contentLength != null && response.contentLength! > _maxBytes) {
      throw const FormatException('Release package exceeds the maximum download size.');
    }
    var total = 0;
    final sink = pending.openWrite();
    try {
      await for (final data in response.stream.timeout(const Duration(seconds: 40))) {
        total += data.length;
        if (total > _maxBytes) throw const FormatException('Release exceeds maximum download size.');
        sink.add(data);
        final size = response.contentLength;
        if (size != null && size > 0) onProgress?.call((total / size).clamp(0, 1));
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    final digest = await sha256.bind(pending.openRead()).first;
    if (digest.toString().toLowerCase() != release.sha256) {
      throw const FormatException('Downloaded release failed SHA-256 validation.');
    }
    if (await completed.exists()) await completed.delete();
    await pending.rename(completed.path);
    onProgress?.call(1);
    return completed.path;
  } catch (_) {
    if (await pending.exists()) await pending.delete();
    rethrow;
  } finally {
    client.close();
  }
}

bool _allowed(Uri url, {required bool firstHop}) {
  if (url.scheme != 'https' || url.userInfo.isNotEmpty || (url.hasPort && url.port != 443)) return false;
  if (firstHop) {
    return url.host == 'github.com' &&
        url.path.startsWith('/TechSavage1989/budgetism/releases/download/');
  }
  return url.host == 'github.com' ||
      url.host == 'release-assets.githubusercontent.com' ||
      url.host == 'objects.githubusercontent.com';
}
