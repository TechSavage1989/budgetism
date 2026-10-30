"""Create/verify an exact API-only update ZIP; no database or installer payloads."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import tempfile
import zipfile

def member(name):
    if not isinstance(name, str) or not re.fullmatch(r'api/[A-Za-z0-9_.+\-]+', name):
        raise ValueError('Unsafe API member')
    leaf = name[4:]
    stem = leaf.split('.')[0].upper()
    if stem in {'CON', 'PRN', 'AUX', 'NUL'} or re.fullmatch(r'(COM|LPT)[1-9]', stem):
        raise ValueError('Reserved Windows API member')
    if not leaf.endswith('.dll') and leaf not in ('Budgetism.Api.exe', 'Budgetism.Api.deps.json',
            'Budgetism.Api.runtimeconfig.json', 'api-update-contract.json'):
        raise ValueError('Forbidden API member')

def validate(read, names):
    if len(names) != len(set(n.casefold() for n in names)):
        raise ValueError('Duplicate API archive member')
    m = json.loads(read('update-manifest.json').decode('utf-8-sig'))
    expected = dict(format=1, appId='budgetism-api', runtime='win-x64', apiMajor=1,
                    clientApiContract=1, bankSchema=1, planningSchema=1, updateContract=1,
                    requiresMigration=False)
    if any(type(m.get(k)) is not type(v) or m[k] != v for k, v in expected.items()):
        raise ValueError('Unsupported API contract')
    if not re.fullmatch(r'0\.1\.0-dev\.\d+', m.get('version', '')) or not re.fullmatch(r'[a-f0-9]{40}', m.get('sourceCommit', '')):
        raise ValueError('Invalid build identity')
    seen = {'update-manifest.json'}
    for f in m['files']:
        name = f['path']; member(name)
        if name.casefold() in {n.casefold() for n in seen}: raise ValueError('Duplicate manifest member')
        data = read(name)
        if type(f['size']) is not int or f['size'] != len(data) or hashlib.sha256(data).hexdigest() != f['sha256']:
            raise ValueError('Manifest content mismatch')
        seen.add(name)
    required = {'api/Budgetism.Api.exe', 'api/Budgetism.Api.dll', 'api/Budgetism.Api.deps.json',
                'api/Budgetism.Api.runtimeconfig.json', 'api/api-update-contract.json'}
    if not required <= seen or seen != set(names): raise ValueError('Missing or extra API content')
    inner = json.loads(read('api/api-update-contract.json').decode('utf-8-sig'))
    if inner != {k: v for k, v in m.items() if k != 'files'}: raise ValueError('Inner build contract mismatch')
    return m

def verify(path):
    with zipfile.ZipFile(path) as z:
        if len(z.infolist()) > 5000 or sum(i.file_size for i in z.infolist()) > 1024**3:
            raise ValueError('API archive too large')
        m = validate(z.read, z.namelist())
        if z.testzip() is not None: raise ValueError('API archive CRC failure')
    return m

def create(root, output):
    root = root.resolve()
    files = [p for p in root.rglob('*') if p.is_file()]
    if any(p.is_symlink() or not p.resolve().is_relative_to(root) for p in root.rglob('*')):
        raise ValueError('Linked package path')
    names = [p.relative_to(root).as_posix() for p in files]
    validate(lambda n: (root/n).read_bytes(), names)
    with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED) as z:
        for name in sorted(names): z.write(root/name, name)
    verify(output)
    print('PASS: exact API-only archive', hashlib.sha256(output.read_bytes()).hexdigest())

def self_test():
    contract = dict(format=1, appId='budgetism-api', version='0.1.0-dev.27', sourceCommit='a'*40,
                    runtime='win-x64', apiMajor=1, clientApiContract=1, bankSchema=1,
                    planningSchema=1, updateContract=1, requiresMigration=False)
    files = {f'api/{n}': b'fixture' for n in ('Budgetism.Api.exe', 'Budgetism.Api.dll',
             'Budgetism.Api.deps.json', 'Budgetism.Api.runtimeconfig.json')}
    files['api/api-update-contract.json'] = json.dumps(contract).encode()
    manifest = dict(contract, files=[dict(path=n, size=len(d), sha256=hashlib.sha256(d).hexdigest()) for n,d in files.items()])
    files['update-manifest.json'] = json.dumps(manifest).encode()
    validate(files.__getitem__, list(files))
    for change in ('tamper', 'extra', 'migration', 'future'):
        bad = dict(files)
        if change == 'tamper': bad['api/Budgetism.Api.dll'] = b'changed'
        elif change == 'extra': bad['api/secret.key'] = b'forbidden'
        else:
            m = json.loads(bad['update-manifest.json'])
            m['requiresMigration' if change == 'migration' else 'updateContract'] = True if change == 'migration' else 2
            bad['update-manifest.json'] = json.dumps(m).encode()
        try: validate(bad.__getitem__, list(bad))
        except ValueError: pass
        else: raise AssertionError('Negative control accepted: ' + change)
    print('PASS: API-only identity, tamper, extra-content, migration and future-contract guards')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('root', nargs='?', type=Path); p.add_argument('output', nargs='?', type=Path)
    p.add_argument('--verify', type=Path); p.add_argument('--self-test', action='store_true')
    a = p.parse_args()
    if a.self_test: self_test()
    if a.verify: print('PASS: API-only archive', verify(a.verify)['version'])
    if a.root and a.output: create(a.root, a.output)
    elif a.root or a.output: p.error('root and output are both required')
