# Marblezzz · App Store campaign

Cream, deep pine, warm maple, and four jewel-colored marbles. The campaign uses native app captures with editable typeset headlines.

- [iPhone campaign preview](previews/contact-iphone.png)
- [iPad campaign preview](previews/contact-ipad.png)
- [Social / launch artwork](exports/social-1600x900.png)
- [App icon, 1024 × 1024](icons/Marblezzz-AppIcon-1024.png)
- [Upload handoff](ASC_HANDOFF.md)
- [English App Store listing](metadata.en-US.json)
- [Asset validation](validation.json)

Upload the six numbered PNGs from `exports/iphone-6.9/` and `exports/ipad-13/`, in order. The contact sheets and social image are previews, not App Store screenshot uploads. The icon is supplied separately as a PNG and a drop-in asset catalog.

Edit headlines and supporting copy in [campaign.en-US.json](campaign.en-US.json). On macOS, run from the repository root:

```sh
swift marketing/tools/render_campaign.swift
python3 marketing/tools/validate_assets.py
```

The validator needs Pillow. The renderer uses macOS AppKit/Core Graphics and preserves source capture proportions. See [capture notes](tools/CAPTURE.md) for the reusable native capture workflow, and [generation prompts](assets/generation-prompts.json) for the icon and decorative artwork.
