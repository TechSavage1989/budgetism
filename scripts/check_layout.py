#!/usr/bin/env python3
"""Validate the reviewed root and native CI targets, including extracted source ZIPs."""
from __future__ import annotations
import argparse
import pathlib
import re
import subprocess
import tempfile

FILES = {'README.md', 'AGENTS.md', 'DEVELOPMENT_HANDOFF.md', '.gitignore'}
DIRS = {'apps','services','docs','scripts','tests','tools','assets','.github'}
GENERATED = {'.git', '.dart_tool', '.idea', '.vscode', 'build', 'bin', 'obj', '__pycache__'}

def native_targets(root: pathlib.Path) -> list[str]:
    workflow = root/'.github/workflows/build-checks.yml'
    if not workflow.is_file():
        return []
    issues = []
    pairs: dict[str, list[tuple[str, str]]] = {}
    for line in workflow.read_text(encoding='utf-8').splitlines():
        target = re.search(r'flutter test (integration_test/[^\s]+)', line)
        if target is None:
            continue
        name = target[1]
        relative = pathlib.PurePosixPath(name)
        if '..' in relative.parts or '\\' in name or not name.endswith('.dart'):
            issues.append(f'Unsafe native CI target: {name}')
            continue
        source = root/'apps/client'/name
        if not source.is_file():
            issues.append(f'Missing native CI target: {name}')
            continue
        declared = set(re.findall(r'String\.fromEnvironment\(\s*[\'\"]([^\'\"]+)', source.read_text(encoding='utf-8')))
        defines: dict[str, str] = {}
        for match in re.finditer(r'--dart-define=(?:"([^"]+)"|\'([^\']+)\'|(\S+))', line):
            value = next(part for part in match.groups() if part is not None)
            key, separator, setting = value.partition('=')
            if not separator or key in defines:
                issues.append(f'Invalid or duplicate native CI define: {name}: {key}')
            defines[key] = setting
        for key in defines.keys() - declared:
            issues.append(f'Unknown native CI define: {name}: {key}')
        phase_keys = {key for key in declared if key.endswith('_TEST_PHASE')}
        directory_keys = {key for key in declared if key.endswith('_TEST_DIRECTORY')}
        if phase_keys:
            if len(phase_keys) != 1 or len(directory_keys) != 1:
                issues.append(f'Ambiguous native restart test configuration: {name}')
                continue
            phase_key, directory_key = next(iter(phase_keys)), next(iter(directory_keys))
            phase, directory = defines.get(phase_key, ''), defines.get(directory_key, '')
            if phase not in {'write', 'read'} or not directory:
                issues.append(f'Missing explicit restart phase/directory: {name}')
                continue
            pairs.setdefault(name, []).append((phase, directory))
    for name, runs in pairs.items():
        if sorted(phase for phase, _ in runs) != ['read', 'write'] or len({directory for _, directory in runs}) != 1:
            issues.append(f'Native restart test needs write/read with one shared directory: {name}')
    return issues

def check(root: pathlib.Path) -> list[str]:
    unexpected=[]
    if (root/'.git').exists():
        try:
            out=subprocess.check_output(['git','-C',str(root),'ls-files','--','./'],text=True)
            tracked=[pathlib.PurePosixPath(x) for x in out.splitlines()]
            candidates={parts.parts[0] for parts in tracked if parts.parts}
        except (OSError, subprocess.CalledProcessError):
            candidates={p.name for p in root.iterdir()}
    else:
        candidates={p.name for p in root.iterdir()}
    for name in sorted(candidates):
        if name in GENERATED: continue
        path=root/name
        if path.is_dir():
            if name not in DIRS: unexpected.append(f'Unexpected root directory: {name}')
        elif name not in FILES:
            unexpected.append(f'Unexpected root file: {name}')
    for required in ('README.md','AGENTS.md','DEVELOPMENT_HANDOFF.md'):
        if not (root/required).is_file(): unexpected.append(f'Missing required guide: {required}')
    return unexpected + native_targets(root)

def self_test() -> None:
    with tempfile.TemporaryDirectory() as td:
        d=pathlib.Path(td)
        for name in ('README.md','AGENTS.md','DEVELOPMENT_HANDOFF.md'): (d/name).write_text('test')
        assert not check(d), 'clean fixture should pass'
        (d/'stray-root-report.txt').write_text('should not be tracked')
        assert any('stray-root-report.txt' in issue for issue in check(d)), 'negative control must fail'
        (d/'stray-root-report.txt').unlink()
        (d/'apps').mkdir()
        assert not check(d), 'expected source directory must pass'
        workflow=d/'.github/workflows/build-checks.yml'; workflow.parent.mkdir(parents=True)
        command='run: flutter test integration_test/fixture.dart -d windows'
        workflow.write_text(command)
        assert any('Missing native CI target' in issue for issue in check(d))
        source=d/'apps/client/integration_test/fixture.dart'; source.parent.mkdir(parents=True)
        source.write_text("const phase = String.fromEnvironment('FIX_TEST_PHASE');\n"
                          "const directory = String.fromEnvironment('FIX_TEST_DIRECTORY');\n")
        assert any('Missing explicit restart' in issue for issue in check(d))
        lines=[command+f' --dart-define=FIX_TEST_PHASE={phase} --dart-define="FIX_TEST_DIRECTORY=path with spaces"' for phase in ['write','read']]
        workflow.write_text('\n'.join(lines)); assert not check(d)
        workflow.write_text('\n'.join(lines).replace('FIX_TEST_PHASE','WRONG_TEST_PHASE'))
        assert any('Unknown native CI define' in issue for issue in check(d))
        workflow.write_text(lines[0]+'\n'+lines[1].replace('path with spaces','different path'))
        assert any('shared directory' in issue for issue in check(d))
        workflow.write_text('\n'.join(lines)); assert not check(d)
    print('PASS: root clutter, missing native test, wrong restart defines and mismatched directory negative controls.')

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--self-test', action='store_true')
    args=parser.parse_args()
    if args.self_test:self_test()
    root=pathlib.Path(__file__).resolve().parents[1]
    issues=check(root)
    for issue in issues:print('FAIL:',issue)
    if issues:raise SystemExit(1)
    print('PASS: root layout and native CI targets reviewed (works without Git metadata).')
