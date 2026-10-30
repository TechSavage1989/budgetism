#!/usr/bin/env python3
"""One-shot, fail-closed publication of the tested dev.27 app-only prerelease.

Only the dedicated GitHub Actions push workflow may invoke publication. This
script never retries writes, deletes releases/tags, clobbers assets or deploys.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

REPO = 'TechSavage1989/budgetism'
BRANCH = 'development/coordinated-updates-dev27'
REQUEST = '.github/release-requests/dev27.json'
WORKFLOW = '.github/workflows/build-checks.yml'
VERSION = '0.1.0-dev.27'
TAG = 'v' + VERSION
ASSETS = ('Budgetism-Windows-x64.zip', 'Budgetism-API-Windows-x64.zip', 'checksums.sha256')
ARTIFACT_NAMES = {
    'client': 'Budgetism-Windows-x64-development',
    'api': 'Budgetism-API-Windows-x64-development',
    'clientSecurity': 'Budgetism-Windows-security-evidence',
    'apiSecurity': 'Budgetism-api-update-evidence',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def valid_hash(value):
    return isinstance(value, str) and re.fullmatch(r'[a-f0-9]{64}', value) is not None


def integer(value):
    return type(value) is int and value > 0


def validate_request(r):
    require(isinstance(r, dict) and set(r) == {'repository', 'version', 'testedSha', 'buildRunId', 'artifacts'}, 'Unexpected request fields')
    require(r['repository'] == REPO and r['version'] == VERSION, 'Wrong repository/version')
    require(isinstance(r['testedSha'], str) and re.fullmatch(r'[a-f0-9]{40}', r['testedSha']), 'Invalid tested commit')
    require(integer(r['buildRunId']), 'Invalid build run')
    require(isinstance(r['artifacts'], dict) and set(r['artifacts']) == set(ARTIFACT_NAMES), 'Exactly four pinned artifacts required')
    ids = set()
    for kind, a in r['artifacts'].items():
        expected = {'id', 'sha256', 'reportSha256'} if kind.endswith('Security') else {'id', 'sha256', 'zipSha256', 'zipSize'}
        require(isinstance(a, dict) and set(a) == expected, 'Unexpected artifact fields')
        require(integer(a['id']) and a['id'] not in ids, 'Invalid/repeated artifact ID')
        ids.add(a['id'])
        require(valid_hash(a['sha256']), 'Artifact digest required')
        if kind.endswith('Security'):
            require(valid_hash(a['reportSha256']), 'Scan report digest required')
        else:
            require(valid_hash(a['zipSha256']) and integer(a['zipSize']) and a['zipSize'] <= 700 * 1024**2, 'Inner ZIP identity required')
    return r


def validate_run(run, request):
    require(run.get('id') == request['buildRunId'] and type(run.get('id')) is int, 'Wrong workflow run')
    require(run.get('head_sha') == request['testedSha'] and run.get('head_branch') == BRANCH, 'Run is not the tested branch commit')
    require(run.get('path') == WORKFLOW and run.get('event') == 'push', 'Wrong build workflow/event')
    require(run.get('status') == 'completed' and run.get('conclusion') == 'success', 'Full build must have succeeded')
    require(run.get('repository', {}).get('full_name') == REPO and run.get('head_repository', {}).get('full_name') == REPO, 'Foreign run repository')


def validate_artifact(meta, kind, request):
    pinned = request['artifacts'][kind]
    require(meta.get('id') == pinned['id'] and type(meta.get('id')) is int and meta.get('name') == ARTIFACT_NAMES[kind], 'Wrong artifact identity')
    require(meta.get('expired') is False, 'Artifact expired')
    workflow = meta.get('workflow_run', {})
    require(workflow.get('id') == request['buildRunId'] and workflow.get('head_sha') == request['testedSha'], 'Artifact belongs to another run/commit')
    require(meta.get('digest') == 'sha256:' + pinned['sha256'], 'Artifact API digest does not match request')


def validate_scan(raw, expected_report_hash, package_hash):
    require(digest(raw) == expected_report_hash, 'Scan report digest mismatch')
    report = json.loads(raw.decode('utf-8-sig'))
    require(report.get('status') == 'no-threats-detected' and report.get('archiveSha256') == package_hash, 'Scan does not clear this exact archive')
    require(all(isinstance(report.get(k), str) and report[k] for k in ('scanUtc', 'engine', 'signatures')), 'Incomplete scan provenance')
    scans = report.get('scans')
    require(isinstance(scans, list) and len(scans) == 2 and {s.get('target') for s in scans} == {'archive-scan.txt', 'expanded-scan.txt'}, 'Both exact archive and extracted scans required')
    for scan in scans:
        require(type(scan.get('exitCode')) is int and scan['exitCode'] == 0, 'Defender failed')
        lines = scan.get('output')
        require(isinstance(lines, list) and all(isinstance(x, str) for x in lines), 'Invalid scan output')
        text = '\n'.join(lines)
        require(re.search(r'(scan finished|found no threats|no threats found)', text, re.I), 'Explicit completed scan evidence missing')
        require(not re.search(r'(Threat\s*:\s*\S|Threat\s+(ID|Name|Detected)\s*[:=]|Found\s+[1-9][0-9]*\s+threats)', text, re.I), 'Threat reported')


def validate_payload(data, pinned):
    require(len(data) == pinned['zipSize'] and digest(data) == pinned['zipSha256'], 'Exact inner ZIP changed')


def safe_artifact_member(archive, basename):
    with zipfile.ZipFile(archive) as z:
        infos = z.infolist()
        require(len(infos) <= 100 and sum(i.file_size for i in infos) <= 1500 * 1024**2, 'Artifact exceeds limits')
        require(len({i.filename.casefold() for i in infos}) == len(infos), 'Duplicate artifact paths')
        found = [i for i in infos if Path(i.filename).name == basename and not i.is_dir()]
        require(len(found) == 1, 'Required artifact member is absent or ambiguous')
        require(found[0].file_size <= 700 * 1024**2, 'Artifact member too large')
        # Read bytes only: no archive member is extracted to an attacker-selected path.
        return z.read(found[0])


def command(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def api(endpoint):
    result = command(['gh', 'api', '--hostname', 'github.com', endpoint], stdout=subprocess.PIPE)
    return json.loads(result.stdout)


def assert_absent(endpoint):
    result = subprocess.run(['gh', 'api', '--hostname', 'github.com', '--include', endpoint], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    headers = result.stdout.decode('utf-8', errors='replace')
    require(result.returncode != 0 and re.search(r'^HTTP/\S+ 404(?:\s|$)', headers, re.M), 'Tag/release exists or absence cannot be established; refuse publication')


def validate_diff(tested, event):
    command(['git', 'merge-base', '--is-ancestor', tested, event])
    changed = command(['git', 'diff', '--name-only', tested, event], stdout=subprocess.PIPE, text=True).stdout.splitlines()
    require(changed == [REQUEST], 'Only the release request may differ from the tested source')


def verify_release(release, expected_assets, tested):
    require(release.get('tag_name') == TAG and release.get('prerelease') is True and release.get('draft') is False, 'Unexpected published release state')
    assets = release.get('assets', [])
    require(len(assets) == len(ASSETS) and {a.get('name') for a in assets} == set(ASSETS), 'Unexpected/missing release assets')
    for asset in assets:
        data = expected_assets[asset['name']]
        require(asset.get('state') == 'uploaded' and type(asset.get('size')) is int and asset['size'] == len(data) and asset.get('digest') == 'sha256:' + digest(data), 'Published asset size/digest mismatch')
    ref = api(f'repos/{REPO}/git/ref/tags/{TAG}')['object']
    if ref['type'] == 'tag':
        ref = api(f'repos/{REPO}/git/tags/{ref["sha"]}')['object']
    require(ref['type'] == 'commit' and ref['sha'] == tested, 'Published tag does not point to tested commit')


def publish():
    require(os.environ.get('GITHUB_REPOSITORY') == REPO and os.environ.get('GITHUB_REF') == 'refs/heads/' + BRANCH and os.environ.get('GITHUB_EVENT_NAME') == 'push', 'Dedicated repository branch push required')
    event = os.environ.get('GITHUB_SHA', '')
    require(re.fullmatch(r'[a-f0-9]{40}', event), 'Missing event commit')
    head = command(['git', 'rev-parse', 'HEAD'], stdout=subprocess.PIPE, text=True).stdout.strip()
    require(head == event, 'Checkout must be the exact push event commit')
    command(['git', 'diff', '--quiet', 'HEAD', '--'])
    raw = Path(REQUEST).read_bytes()
    require(len(raw) < 16384, 'Request too large')
    request = validate_request(json.loads(raw))
    validate_diff(request['testedSha'], event)
    validate_run(api(f'repos/{REPO}/actions/runs/{request["buildRunId"]}'), request)
    prefix = f'repos/{REPO}'
    assert_absent(prefix + '/git/ref/tags/' + TAG)
    assert_absent(prefix + '/releases/tags/' + TAG)
    with tempfile.TemporaryDirectory(prefix='budgetism-publish-') as tmp:
        tmp = Path(tmp)
        artifacts = {}
        for kind, pin in request['artifacts'].items():
            validate_artifact(api(f'{prefix}/actions/artifacts/{pin["id"]}'), kind, request)
            path = tmp / (kind + '-artifact.zip')
            with path.open('xb') as out:
                # gh owns GitHub's authenticated redirect flow. Never forward a
                # token manually to a storage URL or read credential stores.
                command(['gh', 'api', '--hostname', 'github.com', f'{prefix}/actions/artifacts/{pin["id"]}/zip'], stdout=out)
            require(digest(path.read_bytes()) == pin['sha256'], 'Downloaded artifact digest mismatch')
            artifacts[kind] = path
        payload = {}
        for kind, name in (('client', ASSETS[0]), ('api', ASSETS[1])):
            data = safe_artifact_member(artifacts[kind], name)
            pin = request['artifacts'][kind]
            validate_payload(data, pin)
            target = tmp / name
            target.write_bytes(data)
            payload[name] = data
            if kind == 'client':
                command(['python', 'scripts/verify_windows_package.py', str(target), '--version', VERSION])
            else:
                command(['python', 'scripts/archive_api_update.py', '--verify', str(target)])
                with zipfile.ZipFile(target) as z:
                    manifest = json.loads(z.read('update-manifest.json').decode('utf-8-sig'))
                require(manifest['version'] == VERSION and manifest['sourceCommit'] == request['testedSha'], 'API payload provenance mismatch')
            security = request['artifacts'][kind + 'Security']
            report = safe_artifact_member(artifacts[kind + 'Security'], 'defender-scan.json')
            validate_scan(report, security['reportSha256'], pin['zipSha256'])
        checksums = ''.join(f'{digest(payload[name])}  {name}\n' for name in ASSETS[:2]).encode('ascii')
        payload[ASSETS[2]] = checksums
        (tmp / ASSETS[2]).write_bytes(checksums)
        notes = tmp / 'release-notes.txt'
        notes.write_text('Budgetism dev.27 development prerelease\n\nDesktop next-launch update and API-only program-update infrastructure. This is not a production release.\n\nExisting installations require a separately authorized verified bootstrap; publishing these files does not install or enable anything on Server2025. API updates require an existing compatible schema and protected recovery; no SQL migration is included. No real bank linkage, payments, credentials, database, server settings or keys are packaged.\n\nExecutables are unsigned. Exact archive/extracted Defender scans passed at build time; this is not publisher signing or universal security clearance.\n\nTested source: ' + request['testedSha'] + '\nBuild: https://github.com/' + REPO + '/actions/runs/' + str(request['buildRunId']) + '\n', encoding='utf-8')
        # Recheck immediately before the sole write. Never retry an uncertain
        # create/upload: a partial release must be inspected by the owner.
        assert_absent(prefix + '/git/ref/tags/' + TAG)
        assert_absent(prefix + '/releases/tags/' + TAG)
        print('All publication gates passed; one non-retried release create follows.', flush=True)
        try:
            command(['gh', 'release', 'create', TAG, '--repo', 'https://github.com/' + REPO,
                     '--target', request['testedSha'], '--title', 'Budgetism ' + VERSION,
                     '--prerelease', '--latest=false', '--notes-file', str(notes),
                     *[str(tmp / name) for name in ASSETS]])
            release = api(prefix + '/releases/tags/' + TAG)
            verify_release(release, payload, request['testedSha'])
        except Exception as error:
            raise RuntimeError('Publication may be partial or unverified. DO NOT RETRY, delete, or clobber; inspect the existing tag/release/assets first.') from error
        print('Verified prerelease tag and exactly three asset digests/sizes. No deployment performed.')


if __name__ == '__main__':
    publish()
