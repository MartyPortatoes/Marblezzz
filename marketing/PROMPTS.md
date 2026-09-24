# Marblezzz · Creative brief and prompt record

## Direction

A modern tabletop game with warm maple, deep pine, cream, muted gold, and four glass-marble colors. Use confident serif headlines, restrained supporting copy, generous space, and the real board as the focus. Preserve the product's existing visual identity. Avoid casino imagery, invented achievement badges, ratings, prize claims, or exaggerated competitive language.

## Screenshot copy

| Order | Headline | Supporting copy |
| --- | --- | --- |
| 1 | A little luck. All teamwork. | A card-powered marble game for a little friendly rivalry. |
| 2 | See your next move. | Choose a card. Preview your path. Then make your move. |
| 3 | Your seat. Anytime. | Play with computer players. Come back to your saved game. |
| 4 | Pass. Reveal. Play. | Keep your cards private. Share one device with friends. |
| 5 | Learn the table. | Learn the cards, the board, and how to play as a team. |
| 6 | Make it yours. | Find your favorite look. Explore optional board finishes. |

Screen 4 requires the visible footer **“Pass-and-play requires the Friends purchase.”** Screen 6 requires **“Optional finishes sold separately.”** [campaign.en-US.json](campaign.en-US.json) is the editable structured source for layout copy. The listing metadata mirrors the final captions.

## Capture and composition requirements

- Use actual current-app captures for all interface content. Surrounding artwork may be generated; do not regenerate or fabricate the app interface.
- Keep board geometry, cards, rules, player counts, legal-move controls, and privacy handoffs faithful to the captured app. Use fictional or default player names.
- iPhone output: 1320 × 2868 pixels. iPad output: 2064 × 2752 pixels. Use device-appropriate captures and layouts, not a stretched phone interface for iPad.
- Export opaque sRGB PNGs. Inspect every final image at full size and reduced product-page size; captions, cards, controls, and paid-feature footers must remain readable.
- Theme packs change all their cosmetic components together. Do not invent separate board, marble, or card-back customization controls.
- Keep online multiplayer/timer claims out of this screenshot sequence until the real-service release gates pass. Do not imply that solo/shared-device saves sync across devices.

The factual constraints follow Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [accurate-metadata guidelines](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata).

## Icon proposal requirements

Create a separate 1024 × 1024 opaque square proposal and sibling asset-catalog package. Use the game's marble/table identity and a simple composition legible at small sizes. Keep the outer canvas square; system masking supplies the rounded shape. Do not replace the checked-in app icon before selection. The image must not imply a different game board or unsupported mechanics.

## Image-generation prompts and outputs

The exact built-in image-generation prompts, reference paths, and output provenance are recorded in [assets/generation-prompts.json](assets/generation-prompts.json). No user-supplied API key was needed.

- Proposed icon: [icons/Marblezzz-AppIcon-1024.png](icons/Marblezzz-AppIcon-1024.png).
- Separate asset catalog: [icons/Marblezzz.appiconset](icons/Marblezzz.appiconset).
- Decorative campaign artwork: [assets/marble-key-art.png](assets/marble-key-art.png).

Generated art supplies the icon and surrounding campaign imagery. Screenshot interface content comes from actual current-app captures, with typography and composition added around it. Final screenshot files and validation are tracked in [ASC_HANDOFF.md](ASC_HANDOFF.md) and [metadata.en-US.json](metadata.en-US.json).
