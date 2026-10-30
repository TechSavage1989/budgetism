import 'release_feed.dart';

const clientUpdateProtocol = 1;
const clientApiContract = 1;
const automaticUpdatesPreference = 'updates.automaticNextLaunch.v1';

/// Public distribution metadata only. Never includes server URLs, session data,
/// install paths, executable paths, workspace identifiers or financial records.
class PendingClientUpdate {
  const PendingClientUpdate({required this.version, required this.sha256});
  final String version, sha256;
  String get identity => '$version-$sha256';
  Map<String, Object> toJson() => {'updateProtocol': clientUpdateProtocol,
    'clientApiContract': clientApiContract, 'version': version, 'sha256': sha256};
  static PendingClientUpdate parse(Object? input) {
    if (input is! Map || input['updateProtocol'] != clientUpdateProtocol || input['clientApiContract'] != clientApiContract) {
      throw const FormatException('The pending update requires an unsupported update/API contract.');
    }
    const keys = {'updateProtocol', 'clientApiContract', 'version', 'sha256'};
    if (input.length != keys.length || input.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('Unexpected fields in pending update metadata.');
    }
    final version = input['version'], digest = input['sha256'];
    if (version is! String || !RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(version) ||
        version.length > 100 || digest is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Invalid pending update identity.');
    }
    return PendingClientUpdate(version: version, sha256: digest);
  }
  static PendingClientUpdate fromRelease(ReleaseInfo release) {
    if (!release.hasVerifiedArchive) throw const FormatException('A verified Windows archive is required.');
    return parse({'updateProtocol': clientUpdateProtocol, 'clientApiContract': clientApiContract,
      'version': release.version, 'sha256': release.sha256});
  }
}

class UpdateStartupResult {
  const UpdateStartupResult({this.message});
  final String? message;
}

/// A download cannot arm an older/withdrawn/different-asset feed selection.
/// A failed/unknown current check never grants fresh installation authority.
bool isCurrentDownloadSelection(ReleaseInfo downloaded, ReleaseCheckResult? current) {
  final latest = current?.latest;
  return current?.status == ReleaseCheckStatus.updateAvailable && latest != null &&
    latest.version == downloaded.version && latest.sha256 == downloaded.sha256 &&
    latest.archiveUrl == downloaded.archiveUrl && latest.hasVerifiedArchive;
}
