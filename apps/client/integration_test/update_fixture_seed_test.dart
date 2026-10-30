// Hosted, fictional updater fixture only. Never imported by the production app.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String joinPath(String a, String b, [String? c, String? d]) =>
    [a, b, if (c != null) c, if (d != null) d].join(Platform.pathSeparator);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('seed a uniquely owned native next-launch update fixture', (tester) async {
    await tester.runAsync(() async {
      final env = Platform.environment;
      final output = env['BUDGETISM_TEST_UPDATE_SUPPORT_FILE'] ??
          (throw StateError('Fixture support output is required.'));
      expect(output, isNotNull);
      final savedPreference = File('$output.preferences.json');
      final prefs = await SharedPreferences.getInstance();
      if (env['BUDGETISM_TEST_UPDATE_CLEANUP'] == '1') {
        final original = jsonDecode(await savedPreference.readAsString()) as Map<String, dynamic>;
        if (original['present'] == true) {
          expect(await prefs.setBool('updates.automaticNextLaunch.v1', original['value'] as bool), isTrue);
        } else {
          expect(await prefs.remove('updates.automaticNextLaunch.v1'), isTrue);
        }
        return;
      }
      if (!await savedPreference.exists()) {
        await savedPreference.writeAsString(jsonEncode({
          'present': prefs.containsKey('updates.automaticNextLaunch.v1'),
          'value': prefs.getBool('updates.automaticNextLaunch.v1'),
          'identities': <String>[],
        }), flush: true);
      }
      final archive = env['BUDGETISM_TEST_UPDATE_ARCHIVE'];
      final version = env['BUDGETISM_TEST_UPDATE_VERSION'];
      final digest = env['BUDGETISM_TEST_UPDATE_SHA'];
      expect(archive, isNotNull);
      expect(version, matches(r'^0\.1\.0-dev\.28$'));
      expect(digest, matches(r'^[a-f0-9]{64}$'));
      expect(output, isNotNull);
      final support = await getApplicationSupportDirectory();
      await File(output).writeAsString(support.path, flush: true);
      final updates = Directory(joinPath(support.path, 'updates'));
      await updates.create(recursive: true);
      final pending = File(joinPath(updates.path, 'pending.json'));
      expect(await pending.exists(), isFalse, reason: 'Never replace another pending request');
      final package = Directory(joinPath(updates.path, 'packages', '$version-$digest'));
      final state = jsonDecode(await savedPreference.readAsString()) as Map<String, dynamic>;
      final identities = List<String>.from(state['identities'] as List);
      final identity = '$version-$digest';
      final attempted = File(joinPath(updates.path, 'attempted', '$identity.json'));
      if (!identities.contains(identity)) {
        expect(await package.exists(), isFalse, reason: 'Do not replace preexisting cached packages');
        expect(await attempted.exists(), isFalse, reason: 'Do not remove preexisting attempt state');
        identities.add(identity);
        state['identities'] = identities;
        await savedPreference.writeAsString(jsonEncode(state), flush: true);
      }
      await package.create(recursive: true);
      await File(archive!).copy(joinPath(package.path, 'Budgetism-Windows-x64.zip'));
      // Each script case is isolated. Only its exact previous fictional attempt may be reset.
      if (await attempted.exists()) {
        await attempted.delete();
      }
      await pending.writeAsString(jsonEncode({
        'updateProtocol': 1, 'clientApiContract': 1,
        'version': version, 'sha256': digest,
      }), flush: true);
      expect(await prefs.setBool('updates.automaticNextLaunch.v1', true), isTrue);
      await File(output).writeAsString(support.path, flush: true);
    });
  });
}
