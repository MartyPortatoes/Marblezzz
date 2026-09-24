#!/usr/bin/env python3
"""Inspect App Store exports without modifying image pixels."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
targets = {"iphone-6.9": (1320, 2868), "ipad-13": (2064, 2752)}
checks = []
errors = []
for family, size in targets.items():
    paths = sorted((ROOT / "exports" / family).glob("*.png"))
    if len(paths) != 6:
        errors.append(f"{family}: expected 6 PNGs, found {len(paths)}")
    for path in paths:
        with Image.open(path) as im:
            im.load()
            check = {"file": str(path.relative_to(ROOT)), "pixels": list(im.size),
                     "mode": im.mode, "format": im.format,
                     "hasAlpha": "A" in im.getbands() or "transparency" in im.info,
                     "orientation": im.getexif().get(274, 1),
                     "hasColorProfile": bool(im.info.get("icc_profile")) or "srgb" in im.info,
                     "colorEncoding": "sRGB PNG chunk" if "srgb" in im.info else "ICC profile" if im.info.get("icc_profile") else "unspecified",
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            checks.append(check)
            if im.size != size or im.mode != "RGB" or check["hasAlpha"] or check["orientation"] != 1 or not check["hasColorProfile"]:
                errors.append(f"Invalid export: {path.name}: {check}")
icon = ROOT / "icons" / "Marblezzz-AppIcon-1024.png"
with Image.open(icon) as im:
    icon_check = {"file": str(icon.relative_to(ROOT)), "pixels": list(im.size),
                  "mode": im.mode, "hasAlpha": "A" in im.getbands(),
                  "sha256": hashlib.sha256(icon.read_bytes()).hexdigest()}
    if im.size != (1024, 1024) or im.mode != "RGB" or icon_check["hasAlpha"]:
        errors.append("Icon is not an opaque 1024 x 1024 RGB image")
metadata = json.loads((ROOT / "metadata.en-US.json").read_text())
limits = {"name": 30, "subtitle": 30, "promotionalText": 170, "description": 4000}
lengths = {key: len(metadata["appStore"][key]) for key in limits}
for key, limit in limits.items():
    if lengths[key] > limit:
        errors.append(f"Metadata {key} exceeds {limit} characters")
lengths["keywordsUTF8Bytes"] = len(metadata["appStore"]["keywords"].encode("utf-8"))
if lengths["keywordsUTF8Bytes"] > 100:
    errors.append("Keywords exceed 100 UTF-8 bytes")
report = {"passed": not errors, "screenshots": checks, "icon": icon_check,
          "metadataLengths": lengths, "errors": errors,
          "scope": "Local asset format and metadata checks; visual review is recorded separately. No ASC upload or signed-build claim."}
(ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"passed": report["passed"], "screenshots": len(checks), "errors": errors}, indent=2))
raise SystemExit(1 if errors else 0)
