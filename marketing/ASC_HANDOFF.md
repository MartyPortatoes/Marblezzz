# Marblezzz · App Store asset handoff

This package contains App Store artwork, the app's integrated icon, and English listing copy. Upload the numbered screenshots to their matching slots. Signing, service testing, and submission remain covered by the existing release checklist.

## Package manifest

[metadata.en-US.json](metadata.en-US.json) contains the English listing, six screenshot captions, disclosures, dimensions, and the final asset manifest. [validation.json](validation.json) records the format checks and SHA-256 hashes. [PROMPTS.md](PROMPTS.md) records the creative brief and generation instructions.

| Deliverable | Intended upload slot | Export target |
| --- | --- | --- |
| Six iPhone screenshots in `exports/iphone-6.9/` | iPhone 6.9-inch display | 1320 × 2868 pixels, portrait |
| Six iPad screenshots in `exports/ipad-13/` | iPad 13-inch display | 2064 × 2752 pixels, portrait |
| [New icon](icons/Marblezzz-AppIcon-1024.png) and [asset catalog](icons/Marblezzz.appiconset) | App icon for the next build | 1024 × 1024 pixels |

Exports use opaque PNG files and sRGB color. These are package production choices. Both screenshot dimensions are accepted by Apple's current specifications; the 13-inch set is required because the app supports iPad. A 6.5-inch iPhone set is the fallback when a 6.9-inch set is absent. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).

Apple permits up to ten screenshots per device size/localization. Upload each device's six files in numbered order. Use the highest required size for each device family; review any automatically scaled smaller presentations and supply distinct captures if their interface differs. [Upload instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots).

The [generation record](assets/generation-prompts.json) contains exact prompts and provenance for the icon and decorative campaign art. Built-in image generation was used without API-key setup. App interface content in the screenshot campaign comes from actual captures. Contact sheets and the 1600 × 900 social image are presentation previews, not substitutes for the individual App Store screenshot files.

## Copy and paid features

The sequence is teamwork, move preview, offline solo, pass-and-play, tutorial, and coordinated themes. Screenshots must show actual app use. Captions and surrounding artwork may frame the capture, but must not invent controls, alter the game state, or imply unavailable functionality. Use default or fictional player names. [Apple accurate-metadata requirements, 2.3.2–2.3.3 and 2.3.9](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata).

Keep these disclosures readable on the associated images:

- Pass-and-play: **Pass-and-play requires the Friends purchase.**
- Cosmetic themes: **Optional finishes sold separately.**

The description additionally explains that every online player needs Friends access; one purchase covers everyone sharing a device for pass-and-play. Midnight walnut and Coastal oak each change the board, marble finish, and card-back color as one theme. They are separate from Friends and do not offer independent component selectors. Two to four people means the total human players, including the host.

## Listing fields

Copy only the `appStore` values from the JSON into their matching App Store Connect fields. Keep the description's line breaks; no Markdown is required.

| Field | Prepared length | Limit |
| --- | --- | --- |
| Name | 9 characters | 30 |
| Subtitle | 28 characters | 30 |
| Promotional text | 160 characters | 170 |
| Description | 1,309 characters | 4,000 |
| Keywords | 74 UTF-8 bytes | 100 bytes |

Limits are from Apple's [app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) and [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) references. The listing now uses the Marblezzz GitHub Pages home, support, and privacy URLs. Support contact: Marblezzz@mattp.me.

## Icon handoff

The new icon has a full square canvas without baked outer rounded corners. Its image is installed in `Marblezzz/Assets.xcassets/AppIcon.appiconset/Icon.png`; this package includes matching PNG and asset catalog copies. Inspect the icon on-device and validate the signed archive. App Store Connect receives the icon through the uploaded build. [Configure an app icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

## Before publication

Complete the existing [release checklist](release-checklist.md), including real Game Center matches, sandbox purchases/restores, publisher details, public support/privacy URLs, and signed-build validation. The listing's online-play sentence is conditional on passing those service gates. Do not add claims of proven live multiplayer, automatic background play, reliable timeout substitution, server-enforced anti-cheat, or cross-device syncing of local games. Promote Friends Family Sharing only after its App Store Connect configuration and device behavior are verified.

## Final asset validation

- All twelve numbered screenshots passed: six at 1320 × 2868 and six at 2064 × 2752. Each is an upright, opaque RGB PNG with sRGB encoding.
- The new icon passed at 1024 × 1024, opaque RGB PNG with an sRGB profile. The included asset catalog contains the same image.
- Listing text passed the field-length limits above. Public URLs are configured in the metadata JSON.
- Both six-panel contact sheets and the launch banner were visually reviewed. The campaign preserves complete native captures; paid-feature disclosures are typeset outside the app UI.
- Native capture runs passed on iPhone 18 Pro Max and iPad Pro 13-inch (M5). See [capture notes](tools/CAPTURE.md), [iPhone provenance](source-captures/iphone/provenance.json), and [iPad provenance](source-captures/ipad/provenance.json).
- Capturing the large iPad revealed a portrait layout alignment issue. The game stack now fills the available width and centers its content; the final iPad images were recaptured after this fix. A subsequent unsigned generic iOS Release build succeeded.
- The temporary capture test was removed and the Xcode project regenerated. Reusable capture and rendering tools remain in this package.

On September 24, 2026, the signed 1.0 (1) build was uploaded and processed by Apple. Both six-image screenshot sets and English listing metadata are saved in App Store Connect. The website, support and privacy pages are live. See [publication status](PUBLICATION_STATUS.md) for verification and remaining device/service gates. Apple review and public App Store release have not occurred.
