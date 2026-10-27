import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/release_feed.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Semver numeric identifiers, prerelease and stable order', () {
    expect(compareVersions('0.1.0-alpha.10', '0.1.0-alpha.9'), greaterThan(0));
    expect(compareVersions('0.1.0', '0.1.0-rc.12'), greaterThan(0));
    expect(compareVersions('0.2.0', '0.1.99'), greaterThan(0));
    expect(compareVersions('v1.2.3', '1.2.3'), 0);
  });
  test('Empty GitHub releases does not falsely say current', () async {
    final prefs = await SharedPreferences.getInstance();
    final feed = ReleaseFeed(prefs: prefs,
      client: MockClient((request) async => http.Response('[]', 200,
        headers: {'etag': '"empty"'})));
    final result = await feed.check();
    expect(result.status, ReleaseCheckStatus.noReleases);
    expect(result.message, contains('No published'));
    feed.dispose();
  });
  test('304 uses validated cached response, without making extra calls', () async {
    final prefs = await SharedPreferences.getInstance();
    var requests = 0;
    final releases = jsonEncode([{
      'tag_name': 'v0.2.0', 'draft': false, 'prerelease': true,
      'html_url': 'https://github.com/TechSavage1989/budgetism/releases/tag/v0.2.0',
      'body': '- Improved dashboard',
      'assets': [{
        'name': 'Budgetism-Windows-x64.zip',
        'browser_download_url': 'https://github.com/TechSavage1989/budgetism/releases/download/v0.2.0/Budgetism-Windows-x64.zip',
        'digest': 'sha256:${'a'*64}'
      }]
    }]);
    final feed = ReleaseFeed(prefs: prefs, client: MockClient((req) async {
      requests++;
      if (requests == 1) return http.Response(releases, 200, headers: {'etag': '"v1"'});
      expect(req.headers['if-none-match'], '"v1"');
      return http.Response('', 304);
    }));
    final first = await feed.check();
    expect(first.status, ReleaseCheckStatus.updateAvailable);
    expect(first.latest!.hasVerifiedArchive, true);
    final second = await feed.check(manual: true);
    expect(requests, 1, reason: 'Manual check cooldown must avoid repeat requests');
    expect(second.status, ReleaseCheckStatus.updateAvailable);
    feed.dispose();
  });
  test('Rate limit is not shown as up-to-date', () async {
    final prefs = await SharedPreferences.getInstance();
    final feed = ReleaseFeed(prefs: prefs,
      client: MockClient((_) async => http.Response('', 429, headers: {'retry-after': '120'})));
    final result = await feed.check();
    expect(result.status, ReleaseCheckStatus.throttled);
    feed.dispose();
  });
  test('No checksum means no verified download', () async {
    final prefs = await SharedPreferences.getInstance();
    final jsonText = jsonEncode([{
      'tag_name':'v0.2.0', 'draft':false, 'prerelease':true,
      'html_url':'https://github.com/TechSavage1989/budgetism/releases/tag/v0.2.0',
      'assets':[{'name':'Budgetism-Windows-x64.zip',
        'browser_download_url':'https://github.com/TechSavage1989/budgetism/releases/download/v0.2.0/Budgetism-Windows-x64.zip'}]
    }]);
    final feed=ReleaseFeed(prefs:prefs,client:MockClient((_) async=>http.Response(jsonText,200)));
    final result=await feed.check();
    expect(result.status,ReleaseCheckStatus.updateAvailable);
    expect(result.latest!.hasVerifiedArchive,false);
    feed.dispose();
  });
}
