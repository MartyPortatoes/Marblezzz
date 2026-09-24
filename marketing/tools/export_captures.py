"""Export unchanged XCTest screenshots, physically normalizing EXIF orientation.

Usage: bundled-python export_captures.py exported-attachments destination
Run xcresulttool export attachments first. No app pixels are retouched.
"""
import json
import pathlib
import re
import sys
from PIL import Image, ImageOps

source, destination = map(pathlib.Path, sys.argv[1:])
destination.mkdir(parents=True, exist_ok=True)
manifest = json.loads((source / "manifest.json").read_text())
records = []

def visit(value):
    if isinstance(value, dict):
        name = value.get("suggestedHumanReadableName", value.get("name", ""))
        filename = value.get("exportedFileName", value.get("filename", ""))
        match = re.search(r"0[1-7]-(?:gameplay|preview|solo|handoff|tutorial|finish|shop)", name)
        if match and filename.endswith(".png"):
            original = source / filename
            output = destination / (match.group() + ".png")
            with Image.open(original) as image:
                upright = ImageOps.exif_transpose(image)
                upright.save(output, format="PNG", exif=b"")
                records.append({"file": output.name, "width": upright.width, "height": upright.height,
                                "raw": str(original), "pixels": "EXIF orientation normalized only"})
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(manifest)
(destination / "provenance.json").write_text(json.dumps(records, indent=2) + "\n")
print(json.dumps(records, indent=2))
