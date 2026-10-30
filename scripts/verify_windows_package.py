#!/usr/bin/env python3
"""Validate a portable package's identity, digest, paths and required native files."""
from __future__ import annotations
import argparse
import hashlib
import json
import pathlib
import stat
import struct
import tempfile
import zipfile

REQUIRED = {
    'Budgetism/Budgetism.exe', 'Budgetism/Budgetism-Updater.exe',
    'Budgetism/flutter_windows.dll', 'Budgetism/flutter_secure_storage_windows_plugin.dll',
    'Budgetism/file_selector_windows_plugin.dll', 'Budgetism/url_launcher_windows_plugin.dll',
    'Budgetism/sqlite3.dll', 'Budgetism/dartjni.dll',
    'Budgetism/data/app.so', 'Budgetism/data/icudtl.dat',
    'Budgetism/data/flutter_assets/AssetManifest.bin',
    'Budgetism/data/flutter_assets/NativeAssetsManifest.json',
    'Budgetism/app-release.json',
}

def verify(path: pathlib.Path, version: str, digest: str | None = None) -> str:
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest is not None and actual.lower() != digest.lower():
        raise ValueError('Package SHA-256 mismatch.')
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if len(entries) > 5000 or sum(e.file_size for e in entries) > 1024 * 1024 * 1024:
            raise ValueError('Archive exceeds size limits.')
        names: set[str] = set()
        for e in entries:
            parts = pathlib.PurePosixPath(e.filename).parts
            if not parts or parts[0] != 'Budgetism' or any(x in ('..', '.') for x in parts) or ':' in e.filename or '\\' in e.filename:
                raise ValueError('Unsafe archive path.')
            key = e.filename.casefold()
            if key in names or stat.S_ISLNK(e.external_attr >> 16):
                raise ValueError('Duplicate path or symbolic link.')
            names.add(key)
            suffix = pathlib.PurePosixPath(e.filename).suffix.lower()
            if suffix == '.exe' and e.filename not in {'Budgetism/Budgetism.exe', 'Budgetism/Budgetism-Updater.exe'}:
                raise ValueError('Unexpected executable.')
            if suffix in {'.sqlite3', '.sqlite', '.db', '.budgetism', '.key', '.pfx'}:
                raise ValueError('Financial data or private key must not be packaged.')
        missing = REQUIRED - set(archive.namelist())
        if missing:
            raise ValueError('Missing required runtime files: ' + ', '.join(sorted(missing)))
        identity = json.loads(archive.read('Budgetism/app-release.json').decode('utf-8-sig'))
        expected = {'appId': 'TechSavage1989.Budgetism', 'version': version,
                    'platform': 'windows-x64', 'executable': 'Budgetism.exe',
                    'updateProtocol': 1, 'clientApiContract': 1}
        if identity != expected:
            raise ValueError('Wrong package identity, version or platform.')
        for e in entries:
            if e.filename.lower().endswith(('.exe', '.dll')):
                data = archive.read(e)
                if len(data) < 64 or data[:2] != b'MZ':
                    raise ValueError('Invalid PE executable: ' + e.filename)
                offset = struct.unpack_from('<I', data, 0x3c)[0]
                if offset + 26 > len(data) or data[offset:offset+4] != b'PE\0\0' or struct.unpack_from('<H', data, offset+4)[0] != 0x8664:
                    raise ValueError('Wrong PE architecture: ' + e.filename)
                if struct.unpack_from('<H', data, offset+24)[0] != 0x20b:
                    raise ValueError('Expected PE32+ executable: ' + e.filename)
        if archive.testzip() is not None:
            raise ValueError('Archive CRC failure.')
    return actual

def self_test() -> None:
    with tempfile.TemporaryDirectory() as td:
        directory = pathlib.Path(td)
        pe = bytearray(128); pe[:2] = b'MZ'; struct.pack_into('<I', pe, 0x3c, 64)
        pe[64:68] = b'PE\0\0'; struct.pack_into('<H', pe, 68, 0x8664); struct.pack_into('<H', pe, 88, 0x20b)
        payload = {n: bytes(pe) if n.endswith(('.dll', '.exe')) else b'fixture' for n in REQUIRED}
        payload['Budgetism/app-release.json'] = json.dumps({'appId': 'TechSavage1989.Budgetism',
            'version': 'fixture', 'platform': 'windows-x64', 'executable': 'Budgetism.exe',
            'updateProtocol': 1, 'clientApiContract': 1}).encode()
        def create(name: str, files: dict[str, bytes]) -> pathlib.Path:
            path = directory / name
            with zipfile.ZipFile(path, 'w') as z:
                for key, value in files.items(): z.writestr(key, value)
            return path
        valid = create('valid.zip', payload)
        verify(valid, 'fixture')
        bad = dict(payload); del bad['Budgetism/flutter_secure_storage_windows_plugin.dll']
        try: verify(create('missing-dll.zip', bad), 'fixture')
        except ValueError as e: assert 'Missing required' in str(e)
        else: raise AssertionError('Missing secure-storage DLL was not detected.')
        try: verify(valid, 'wrong-version')
        except ValueError: pass
        else: raise AssertionError('Wrong version was not detected.')
        try: verify(valid, 'fixture', '0' * 64)
        except ValueError: pass
        else: raise AssertionError('Wrong digest was not detected.')
        for field in ('updateProtocol', 'clientApiContract'):
            bad = dict(payload)
            marker = json.loads(bad['Budgetism/app-release.json'])
            marker[field] = 2
            bad['Budgetism/app-release.json'] = json.dumps(marker).encode()
            try: verify(create(field + '.zip', bad), 'fixture')
            except ValueError: pass
            else: raise AssertionError('Unsupported update contract was not detected: ' + field)
    print('PASS: native dependency, version and digest negative controls.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', nargs='?', type=pathlib.Path)
    parser.add_argument('--version')
    parser.add_argument('--checksums', type=pathlib.Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test: self_test()
    if args.archive:
        if not args.version: parser.error('--version is required with an archive')
        digest = None
        if args.checksums:
            matches = [line.split()[0] for line in args.checksums.read_text(encoding='utf-8-sig').splitlines()
                       if len(line.split()) == 2 and line.split()[1].lstrip('*') == args.archive.name]
            if len(matches) != 1: raise ValueError('Expected exactly one checksum for the package.')
            digest = matches[0]
        print('PASS: package', args.version, verify(args.archive, args.version, digest))
    elif not args.self_test: parser.error('Provide an archive or --self-test')
