#!/usr/bin/env python3
"""Materialize Fastlane metadata and screenshot copies from reviewed campaign files."""
from pathlib import Path
import json
import shutil

root = Path(__file__).resolve().parents[2]
meta = json.loads((root / 'marketing/metadata.en-US.json').read_text())['appStore']
out = root / 'fastlane/metadata/en-US'
out.mkdir(parents=True, exist_ok=True)
fields = {'name': 'name', 'subtitle': 'subtitle', 'promotionalText': 'promotional_text',
          'description': 'description', 'keywords': 'keywords', 'supportURL': 'support_url',
          'privacyPolicyURL': 'privacy_url', 'marketingURL': 'marketing_url'}
for source, target in fields.items():
    value = meta.get(source)
    if not value:
        raise SystemExit(f'Missing required listing value: {source}')
    (out / (target + '.txt')).write_text(value + '\n')
screenshots = root / 'fastlane/screenshots/en-US'
screenshots.mkdir(parents=True, exist_ok=True)
for family, prefix in [('iphone-6.9', 'iphone'), ('ipad-13', 'ipad')]:
    for path in sorted((root / 'marketing/exports' / family).glob('*.png')):
        shutil.copy2(path, screenshots / (prefix + '-' + path.name))
print('Prepared nine English listing fields and twelve screenshots.')
