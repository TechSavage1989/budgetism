#!/usr/bin/env python3
"""Validate the reviewed repo root, including extracted source ZIPs without .git."""
from __future__ import annotations
import argparse
import pathlib
import shutil
import subprocess
import tempfile

FILES = {'README.md', 'AGENTS.md', 'DEVELOPMENT_HANDOFF.md', '.gitignore'}
DIRS = {'apps','services','docs','scripts','tests','tools','assets','.github'}
GENERATED = {'.git', '.dart_tool', '.idea', '.vscode', 'build', 'bin', 'obj', '__pycache__'}

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
    return unexpected

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
    print('PASS: layout negative control catches root clutter; clean fixture passes')

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--self-test', action='store_true')
    args=parser.parse_args()
    if args.self_test:self_test()
    root=pathlib.Path(__file__).resolve().parents[1]
    issues=check(root)
    for issue in issues:print('FAIL:',issue)
    if issues:raise SystemExit(1)
    print('PASS: root layout reviewed and valid (works without Git metadata)')
