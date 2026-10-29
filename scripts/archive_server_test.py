"""Archive only verified manifest entries; never include runtime test databases."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile

root = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8-sig'))
seen = set()
with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for entry in manifest['files']:
        name = entry['path']
        path = (root / name).resolve()
        if not path.is_relative_to(root) or name.startswith('runs/') or name in seen:
            raise ValueError('Unsafe or repeated archive entry')
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError('Manifest file changed')
        archive.write(path, name)
        seen.add(name)
    archive.write(root / 'manifest.json', 'manifest.json')
with zipfile.ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise ValueError('Archive CRC check failed')
print(f'Verified {len(seen)} manifested files; no test data included.')
