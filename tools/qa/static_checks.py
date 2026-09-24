#!/usr/bin/env python3
"""Release inputs checked without reading or printing credential values."""
import hashlib
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors = []

def check(ok, message):
    print(('PASS' if ok else 'FAIL') + ': ' + message)
    if not ok:
        errors.append(message)

files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
secret_name = re.compile(r'(^|/)(\.env(\.|$)|AuthKey_)|\.(p8|p12|pem|key|cer|mobileprovision|provisionprofile)$')
bad = [f for f in files if f and secret_name.search(f) and not f.endswith('.env.example')]
check(not bad, 'No tracked credentials or signing material' + (': ' + ', '.join(bad) if bad else ''))
secret_text = re.compile(rb'-----BEGIN (?:EC |RSA |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bAKIA[A-Z0-9]{16}\b')
hits = []
for name in files:
    p = ROOT / name
    if name and p.is_file() and p.stat().st_size < 2_000_000 and secret_text.search(p.read_bytes()):
        hits.append(name)
check(not hits, 'No secret signatures in tracked files' + (': ' + ', '.join(hits) if hits else ''))

project_text = (ROOT / 'Marblezzz.xcodeproj/project.pbxproj').read_text()
versions = set(re.findall(r'^\s*MARKETING_VERSION = ([^;]+);', project_text, re.MULTILINE))
builds = set(re.findall(r'^\s*CURRENT_PROJECT_VERSION = ([^;]+);', project_text, re.MULTILINE))
check(len(versions) == 1 and re.fullmatch(r'\d{2}\.\d{2}\.\d{2}', next(iter(versions), '')) is not None,
      'App version uses BillHive-style YY.MM.XX')
check(len(builds) == 1 and next(iter(builds), '').isdigit() and int(next(iter(builds), '0')) > 0,
      'App build number is a single positive integer')

for p in sorted((ROOT / 'Marblezzz').rglob('*')):
    if p.suffix in {'.plist', '.xcprivacy', '.entitlements', '.strings', '.stringsdict'}:
        result = subprocess.run(['plutil', '-lint', str(p)], capture_output=True, text=True)
        check(result.returncode == 0, 'Valid property list: ' + str(p.relative_to(ROOT)))
    if p.suffix in {'.xcstrings', '.storekit'}:
        try:
            json.loads(p.read_text())
            check(True, 'Valid JSON: ' + str(p.relative_to(ROOT)))
        except (ValueError, OSError):
            check(False, 'Valid JSON: ' + str(p.relative_to(ROOT)))

catalog = json.loads((ROOT / 'Marblezzz/Resources/Localizable.xcstrings').read_text())
languages = {lang for entry in catalog['strings'].values() for lang in entry.get('localizations', {})}
check(catalog['sourceLanguage'] == 'en' and languages <= {'en'}, 'English source catalog; no partial additional locales declared')

meta = json.loads((ROOT / 'marketing/metadata.en-US.json').read_text())['appStore']
for field, limit in {'name': 30, 'subtitle': 30, 'promotionalText': 170, 'description': 4000}.items():
    check(isinstance(meta.get(field), str) and 0 < len(meta[field]) <= limit, f'ASC {field} present and within {limit} characters')
check(0 < len(meta.get('keywords', '').encode()) <= 100, 'ASC keywords within 100 UTF-8 bytes')
for field in ['supportURL', 'privacyPolicyURL', 'marketingURL']:
    check(isinstance(meta.get(field), str) and meta[field].startswith('https://'), f'ASC {field} configured')

validation = json.loads((ROOT / 'marketing/validation.json').read_text())
check(validation.get('passed') is True and len(validation['screenshots']) == 12, 'Twelve validated campaign screenshots')
for item in validation['screenshots'] + [validation['icon']]:
    path = ROOT / 'marketing' / item['file']
    check(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], 'Current export: ' + item['file'])
icon = ROOT / 'Marblezzz/Assets.xcassets/AppIcon.appiconset/Icon.png'
check(icon.read_bytes() == (ROOT / 'marketing/icons/Marblezzz-AppIcon-1024.png').read_bytes(), 'Shipping app uses the validated campaign icon')
check(not (ROOT / 'MarblezzzUITests/MarketingCaptureTests.swift').exists(), 'Marketing capture harness excluded from normal test target')
print(f'\n{len(errors)} failed static checks')
sys.exit(bool(errors))
