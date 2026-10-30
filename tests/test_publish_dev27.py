"""Pure publication gate tests. No GitHub/network calls or release writes."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('publish_dev27', Path(__file__).resolve().parents[1] / 'scripts/publish_dev27.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


def request():
    artifacts = {}
    for i, key in enumerate(p.ARTIFACT_NAMES, 1):
        a = dict(id=i, sha256='b' * 64)
        if key.endswith('Security'):
            a['reportSha256'] = 'c' * 64
        else:
            a.update(zipSha256='d' * 64, zipSize=123)
        artifacts[key] = a
    return dict(repository=p.REPO, version=p.VERSION, testedSha='a' * 40, buildRunId=42, artifacts=artifacts)


def run():
    return dict(id=42, head_sha='a' * 40, head_branch=p.BRANCH, path=p.WORKFLOW,
                event='push', status='completed', conclusion='success',
                repository=dict(full_name=p.REPO), head_repository=dict(full_name=p.REPO))


def scan():
    return dict(status='no-threats-detected', archiveSha256='d' * 64,
                scanUtc='2026-10-30T00:00:00Z', engine='fixture', signatures='fixture',
                scans=[dict(target=t, exitCode=0, output=['Scan finished. No threats found.'])
                       for t in ('archive-scan.txt', 'expanded-scan.txt')])


class PublicationGuards(unittest.TestCase):
    def test_valid_request(self):
        self.assertEqual(p.validate_request(request())['buildRunId'], 42)

    def test_wrong_request_or_extra_authority(self):
        for key, value in [('repository', 'elsewhere/project'), ('version', '1.0.0'),
                           ('buildRunId', True), ('testedSha', 'main'), ('deploy', True)]:
            r = request(); r[key] = value
            with self.assertRaises(ValueError): p.validate_request(r)

    def test_pin_required(self):
        for field, value in [('id', True), ('sha256', 'bad'), ('zipSize', -1)]:
            r = request(); r['artifacts']['client'][field] = value
            with self.assertRaises(ValueError): p.validate_request(r)

    def test_exact_successful_build(self):
        p.validate_run(run(), request())
        for key, value in [('id', 43), ('head_sha', 'f' * 40), ('head_branch', 'main'),
                           ('path', '.github/workflows/other.yml'), ('event', 'pull_request'),
                           ('conclusion', 'failure'), ('status', 'in_progress'),
                           ('repository', {'full_name': 'attacker/budgetism'})]:
            value_run = run(); value_run[key] = value
            with self.assertRaises(ValueError): p.validate_run(value_run, request())

    def test_artifact_provenance(self):
        a = dict(id=1, name=p.ARTIFACT_NAMES['client'], expired=False, digest='sha256:' + 'b' * 64,
                 workflow_run=dict(id=42, head_sha='a' * 40))
        p.validate_artifact(a, 'client', request())
        for key, value in [('expired', True), ('digest', 'sha256:' + 'c' * 64),
                           ('workflow_run', {'id': 43, 'head_sha': 'a' * 40}), ('name', 'foreign')]:
            bad = dict(a); bad[key] = value
            with self.assertRaises(ValueError): p.validate_artifact(bad, 'client', request())

    def test_payload_tampering(self):
        data = b'controlled zip bytes'
        pin = dict(zipSize=len(data), zipSha256=p.digest(data))
        p.validate_payload(data, pin)
        with self.assertRaises(ValueError): p.validate_payload(data + b'changed', pin)
        with self.assertRaises(ValueError): p.validate_payload(data, dict(pin, zipSha256='0' * 64))

    def test_artifact_ambiguous_member(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / 'artifact.zip'
            with zipfile.ZipFile(path, 'w') as z:
                z.writestr('first/defender-scan.json', '{}')
                z.writestr('second/defender-scan.json', '{}')
            with self.assertRaises(ValueError): p.safe_artifact_member(path, 'defender-scan.json')

    def test_both_exact_scans(self):
        raw = json.dumps(scan()).encode()
        p.validate_scan(raw, p.digest(raw), 'd' * 64)
        with self.assertRaises(ValueError): p.validate_scan(raw, '0' * 64, 'd' * 64)
        with self.assertRaises(ValueError): p.validate_scan(raw, p.digest(raw), 'e' * 64)
        for mutation in ('status', 'missing', 'exit', 'threat', 'bool'):
            s = scan()
            if mutation == 'status': s['status'] = 'incomplete'
            elif mutation == 'missing': s['scans'].pop()
            elif mutation == 'exit': s['scans'][0]['exitCode'] = 2
            elif mutation == 'bool': s['scans'][0]['exitCode'] = False
            else: s['scans'][0]['output'] = ['Scan finished', 'Threat Name: Example']
            raw = json.dumps(s).encode()
            with self.assertRaises(ValueError): p.validate_scan(raw, p.digest(raw), 'd' * 64)

    def test_only_request_diff(self):
        with patch.object(p, 'command', side_effect=[None, subprocess.CompletedProcess([], 0, p.REQUEST + '\n')]):
            p.validate_diff('a' * 40, 'b' * 40)
        with patch.object(p, 'command', side_effect=[None, subprocess.CompletedProcess([], 0, p.REQUEST + '\nscripts/publish_dev27.py\n')]):
            with self.assertRaises(ValueError): p.validate_diff('a' * 40, 'b' * 40)

    def test_existing_and_uncertain_are_never_absent(self):
        for code, output in [(0, b'HTTP/2.0 200 OK\n{}'), (1, b'HTTP/2.0 403 Forbidden\n{}'), (1, b'')]:
            with patch.object(p.subprocess, 'run', return_value=subprocess.CompletedProcess([], code, output, b'')):
                with self.assertRaises(ValueError): p.assert_absent('fixture')
        with patch.object(p.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, b'HTTP/2.0 404 Not Found\n{}', b'')):
            p.assert_absent('fixture')

    def test_post_publication_exact_assets_and_tag(self):
        payload = {name: name.encode() for name in p.ASSETS}
        release = dict(tag_name=p.TAG, prerelease=True, draft=False,
                       assets=[dict(name=n, state='uploaded', size=len(d), digest='sha256:' + p.digest(d)) for n, d in payload.items()])
        with patch.object(p, 'api', return_value={'object': {'type': 'commit', 'sha': 'a' * 40}}):
            p.verify_release(release, payload, 'a' * 40)
            bad = copy.deepcopy(release); bad['assets'][0]['digest'] = 'sha256:' + '0' * 64
            with self.assertRaises(ValueError): p.verify_release(bad, payload, 'a' * 40)
            bad = copy.deepcopy(release); bad['assets'].append(dict(name='source.zip'))
            with self.assertRaises(ValueError): p.verify_release(bad, payload, 'a' * 40)
        with patch.object(p, 'api', return_value={'object': {'type': 'commit', 'sha': 'f' * 40}}):
            with self.assertRaises(ValueError): p.verify_release(release, payload, 'a' * 40)

    def test_wrong_environment_never_calls_network(self):
        with patch.dict(p.os.environ, {}, clear=True), patch.object(p, 'api') as api:
            with self.assertRaises(ValueError): p.publish()
            api.assert_not_called()


if __name__ == '__main__':
    unittest.main()
