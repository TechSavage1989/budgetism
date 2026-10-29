"""Negative controls run before any executable, database or secret creation."""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/test_private_server.ps1'
REQUIRED = ('api/Budgetism.Api.exe', 'postgresql/bin/initdb.exe',
            'postgresql/bin/pg_ctl.exe', 'postgresql/bin/postgres.exe',
            'Test-BudgetismServer.ps1')


class PackageGuards(unittest.TestCase):
    def run_guard(self, change, expected, port=None):
        with tempfile.TemporaryDirectory(prefix='budgetism-guard-') as directory:
            root = Path(directory)
            files = []
            for name in REQUIRED:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'fictional non-executable guard fixture')
                files.append({'path': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
            manifest = {'format': 1, 'files': files}
            change(root, manifest)
            (root / 'manifest.json').write_text(json.dumps(manifest), encoding='utf-8')
            args = ['powershell.exe', '-NoProfile', '-File', str(SCRIPT), '-PackageDirectory', str(root)]
            if port:
                args += ['-DatabasePort', str(port)]
            environment = {k: v for k, v in os.environ.items() if k.lower() != 'psmodulepath'}
            result = subprocess.run(args, capture_output=True, text=True, timeout=20, env=environment)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(expected, result.stdout + result.stderr)
            self.assertFalse((root / 'runs').exists())

    def test_tampered_file(self):
        self.run_guard(lambda r, m: (r / REQUIRED[0]).write_bytes(b'changed'), 'integrity check failed')

    def test_missing_file(self):
        self.run_guard(lambda r, m: (r / REQUIRED[0]).unlink(), 'Package file missing')

    def test_traversal(self):
        self.run_guard(lambda r, m: m['files'].append({'path': '../outside', 'sha256': '0'*64}), 'Unsafe package path')

    def test_missing_required(self):
        self.run_guard(lambda r, m: m['files'].pop(), 'Required package component')

    def test_occupied_port(self):
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            self.run_guard(lambda r, m: None, 'already occupied', listener.getsockname()[1])


if __name__ == '__main__':
    unittest.main()
