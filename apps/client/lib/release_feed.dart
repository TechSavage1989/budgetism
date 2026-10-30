import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const budgetismRepository = 'TechSavage1989/budgetism';
const budgetismVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0-dev.21');
const _releasesApi = 'https://api.github.com/repos/$budgetismRepository/releases?per_page=10';
const _windowsArchive = 'Budgetism-Windows-x64.zip';

/// Release metadata is public and contains no financial or authentication data.
/// SHA-256 proves byte consistency with GitHub's release metadata, not the
/// identity of the publisher. Code signing remains a separate release gate.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.url,
    required this.notes, required this.isPrerelease, this.archiveUrl, this.sha256});
  final String version;
  final String url;
  final String notes;
  final bool isPrerelease;
  final String? archiveUrl;
  final String? sha256;
  bool get hasVerifiedArchive => archiveUrl != null && sha256 != null;

  List<String> get whatsNew => notes.split('\n')
      .map((x) => x.trim().replaceFirst(RegExp(r'^[-*]\s*'), ''))
      .where((x) => x.isNotEmpty && !x.startsWith('#'))
      .take(3).toList();
  bool get hasMoreNotes => notes.trim().isNotEmpty &&
      notes.split('\n').map((x) => x.trim())
        .where((x) => x.isNotEmpty && !x.startsWith('#')).length > whatsNew.length;
}

enum ReleaseCheckStatus { checking, updateAvailable, current, noReleases, unavailable, throttled, error }

class ReleaseCheckResult {
  const ReleaseCheckResult(this.status, this.message, {this.latest, this.checkedAt});
  final ReleaseCheckStatus status;
  final String message;
  final ReleaseInfo? latest;
  final DateTime? checkedAt;
}

/// Single-flight, cached, rate-aware GitHub release checking.
/// Does not download, install, or restart the app.
class ReleaseFeed {
  ReleaseFeed({http.Client? client, required this.prefs, DateTime Function()? clock})
      : _client = client ?? http.Client(), _clock = clock ?? DateTime.now;
  final http.Client _client;
  final SharedPreferences prefs;
  final DateTime Function() _clock;
  Future<ReleaseCheckResult>? _pending;
  DateTime? _lastAttempt;
  DateTime? _retryAfter;
  ReleaseCheckResult? lastResult;

  DateTime? get lastAttempt => _lastAttempt;
  bool get isBusy => _pending != null;

  Future<ReleaseCheckResult> check({bool manual = false, bool focusReturn = false}) {
    if (_pending != null) return _pending!;
    final now = _clock();
    if (_retryAfter != null && now.isBefore(_retryAfter!)) {
      return Future.value(ReleaseCheckResult(ReleaseCheckStatus.throttled,
        'GitHub has limited update checks. Try again later.', latest: lastResult?.latest));
    }
    final interval = manual ? const Duration(seconds: 20)
        : focusReturn ? const Duration(minutes: 2)
        : const Duration(minutes: 5);
    if (_lastAttempt != null && now.difference(_lastAttempt!) < interval && lastResult != null) {
      return Future.value(lastResult!);
    }
    _lastAttempt = now;
    final attempt = _fetch(now);
    _pending = attempt;
    return attempt.whenComplete(() => _pending = null);
  }

  Future<ReleaseCheckResult> _fetch(DateTime time) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'Budgetism/$budgetismVersion',
      };
      final etag = prefs.getString('updates.etag');
      if (etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;
      final response = await _client.get(Uri.parse(_releasesApi), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 403 || response.statusCode == 429) {
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
        if (seconds != null && seconds >= 0) {
          _retryAfter = time.add(Duration(seconds: seconds));
        } else if (reset != null) {
          final resetTime = DateTime.fromMillisecondsSinceEpoch(reset * 1000);
          _retryAfter = resetTime.isAfter(time) ? resetTime : time.add(const Duration(minutes: 5));
        } else {
          _retryAfter = time.add(const Duration(minutes: 5));
        }
        return _remember(ReleaseCheckResult(ReleaseCheckStatus.throttled,
          'Update check limited by GitHub. No current-version claim can be made.'));
      }
      String body;
      if (response.statusCode == 304) {
        body = prefs.getString('updates.cachedReleases') ?? '';
        if (body.isEmpty) {
          await prefs.remove('updates.etag');
          return _remember(ReleaseCheckResult(ReleaseCheckStatus.error,
            'Update feed returned a cached response without local data. Retry later.'));
        }
      } else if (response.statusCode == 200) {
        body = response.body;
        if (body.length > 512 * 1024) throw const FormatException('Update feed is larger than expected.');
        final newEtag = response.headers['etag'];
        if (newEtag != null) await prefs.setString('updates.etag', newEtag);
        await prefs.setString('updates.cachedReleases', body);
      } else {
        return _remember(ReleaseCheckResult(ReleaseCheckStatus.error,
          'Unable to verify available updates (HTTP ${response.statusCode}).'));
      }
      final json = jsonDecode(body);
      if (json is! List) throw const FormatException('Invalid release feed format.');
      final releases = json.whereType<Map>().map(_parseRelease).whereType<ReleaseInfo>().toList();
      if (releases.isEmpty) {
        return _remember(ReleaseCheckResult(ReleaseCheckStatus.noReleases,
          'No published Budgetism releases exist yet.', checkedAt: time));
      }
      final previewChannel = budgetismVersion.contains('-');
      final eligible = releases.where((x) => previewChannel || !x.isPrerelease).toList();
      if (eligible.isEmpty) {
        return _remember(ReleaseCheckResult(ReleaseCheckStatus.noReleases,
          'No releases exist for this update channel.', checkedAt: time));
      }
      eligible.sort((a, b) => compareVersions(b.version, a.version));
      final newest = eligible.first;
      final result = compareVersions(newest.version, budgetismVersion) > 0;
      return _remember(ReleaseCheckResult(
        result ? ReleaseCheckStatus.updateAvailable : ReleaseCheckStatus.current,
        result ? 'Budgetism ${newest.version} is available.' : 'No newer published version found.',
        latest: newest, checkedAt: time));
    } catch (_) {
      return _remember(ReleaseCheckResult(ReleaseCheckStatus.unavailable,
        'Unable to check for updates. Connection or feed unavailable.'));
    }
  }

  ReleaseCheckResult _remember(ReleaseCheckResult result) { lastResult = result; return result; }

  ReleaseInfo? _parseRelease(Map source) {
    final tag = source['tag_name']?.toString() ?? '';
    final page = source['html_url']?.toString() ?? '';
    if (source['draft'] == true || !page.startsWith('https://github.com/$budgetismRepository/releases/tag/') ||
        !_validVersion(tag)) {
      return null;
    }
    final assets = source['assets'];
    String? url;
    String? sha;
    if (assets is List) {
      for (final raw in assets.whereType<Map>()) {
        if (raw['name'] != _windowsArchive) continue;
        final candidate = raw['browser_download_url']?.toString() ?? '';
        final digest = raw['digest']?.toString() ?? '';
        if (candidate.startsWith('https://github.com/$budgetismRepository/releases/download/') &&
            Uri.tryParse(candidate)?.host == 'github.com') {
          url = candidate;
          if (RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)) sha = digest.substring(7).toLowerCase();
        }
      }
    }
    return ReleaseInfo(version: tag.startsWith('v') ? tag.substring(1) : tag,
      url: page, notes: source['body']?.toString() ?? '',
      isPrerelease: source['prerelease'] == true, archiveUrl: url, sha256: sha);
  }

  void dispose() => _client.close();
}

bool _validVersion(String raw) =>
    RegExp(r'^v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(raw);

/// Compare numeric parts first, then stable versions above prereleases.
int compareVersions(String a, String b) {
  List<int> core(String v) => v.replaceFirst(RegExp(r'^v'), '').split('-').first
      .split('.').map((x) => int.tryParse(x) ?? 0).toList();
  final aa = core(a), bb = core(b);
  for (var i = 0; i < 3; i++) {
    final c = aa[i].compareTo(bb[i]);
    if (c != 0) return c;
  }
  final aPre = a.contains('-') ? a.split('-').skip(1).join('-') : '';
  final bPre = b.contains('-') ? b.split('-').skip(1).join('-') : '';
  if (aPre.isEmpty && bPre.isNotEmpty) return 1;
  if (bPre.isEmpty && aPre.isNotEmpty) return -1;
  if (aPre == bPre) return 0;
  final aParts = aPre.split('.'), bParts = bPre.split('.');
  for (var i = 0; i < aParts.length && i < bParts.length; i++) {
    final an = int.tryParse(aParts[i]), bn = int.tryParse(bParts[i]);
    final c = an != null && bn != null ? an.compareTo(bn)
        : an != null ? -1 : bn != null ? 1 : aParts[i].compareTo(bParts[i]);
    if (c != 0) return c;
  }
  return aParts.length.compareTo(bParts.length);
}
