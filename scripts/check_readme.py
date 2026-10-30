#!/usr/bin/env python3
"""Check Budgetism's user-first README hierarchy, navigation and local links."""
from __future__ import annotations
import argparse
import pathlib
import re
import tempfile

HEADINGS = ['Features', 'Download', 'Requirements', 'Getting started', 'How to use',
            'Updates and settings', 'Troubleshooting', 'Development']
NAVIGATION = [('Download', 'download'), ('Get started', 'getting-started'),
              ('Features', 'features'), ('Updates', 'updates-and-settings'),
              ('Development', 'development')]

def slug(text: str) -> str:
    return re.sub(r'[^\w\- ]', '', text.lower()).replace(' ', '-')

def check(root: pathlib.Path) -> list[str]:
    path = root / 'README.md'
    if not path.is_file():
        return ['README.md is missing']
    text = path.read_text(encoding='utf-8')
    issues = []
    if len(re.findall(r'<h1\b|^# ', text, re.M)) != 1 or not re.search(
            r'<h1\s+align="center">Budgetism</h1>', text):
        issues.append('README needs exactly one centered Budgetism H1')
    headings = re.findall(r'^## (.+)$', text, re.M)
    if headings != HEADINGS:
        issues.append('README standard section names/order changed')
    nav = re.findall(r'<a href="#([^"]+)">([^<]+)</a>', text)
    if [(label, target) for target, label in nav] != NAVIGATION:
        issues.append('README navigation labels/order/anchors changed')
    anchors = {slug(h) for h in headings}
    for target, _ in nav:
        if target not in anchors:
            issues.append(f'Missing navigation anchor: {target}')
    for target in re.findall(r'\]\(([^)]+)\)', text):
        if '://' in target or target.startswith(('mailto:', '#')):
            continue
        relative = target.split('#', 1)[0]
        if relative and not (root / relative).is_file():
            issues.append(f'Missing README local link: {relative}')
    for command in re.findall(r'^```([^\n]*)$', text, re.M)[::2]:
        if not command.strip():
            issues.append('README command block needs a language label')
    return issues

def self_test(root: pathlib.Path) -> None:
    with tempfile.TemporaryDirectory() as temp:
        copy = pathlib.Path(temp)
        text = (root / 'README.md').read_text(encoding='utf-8')
        (copy / 'README.md').write_text(text, encoding='utf-8')
        for target in re.findall(r'\]\(([^)]+)\)', text):
            if '://' in target or target.startswith(('mailto:', '#')):
                continue
            path = copy / target.split('#', 1)[0]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        assert not check(copy), check(copy)
        for old, new in [('<h1 align="center">Budgetism</h1>', '# Budgetism'),
                         ('href="#download"', 'href="#missing"'),
                         ('## Features', '## Unapproved heading')]:
            (copy / 'README.md').write_text(text.replace(old, new, 1), encoding='utf-8')
            assert check(copy), f'Negative control was not detected: {new}'
        (copy / 'README.md').write_text(text + '\n[Missing](docs/not-there.md)\n', encoding='utf-8')
        assert check(copy), 'Missing local link was not detected'
    print('PASS: README hierarchy, navigation and missing-link negative controls')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    if args.self_test:
        self_test(root)
    issues = check(root)
    for issue in issues:
        print(issue)
    if issues:
        raise SystemExit(1)
    print('PASS: README standard hierarchy, navigation and local links')
