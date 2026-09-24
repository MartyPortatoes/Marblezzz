# Native campaign capture

These sources are unretouched native simulator screenshots. Only the PNG's EXIF
orientation is applied to the pixel canvas on export. App text, controls, board
positions, and purchase screens are not painted or composited into the captures.

`CampaignFixture.swift` compiles alongside the five MarblezzzCore source files.
It advances real rule-engine actions from seeded deals, validates each resulting
state, and writes ordinary local SnapshotCodec saves. The selected game is seed
3 at turn 97, with seven marbles on the track and seven home. The nine of hearts
preview is the legal action `move(0, 9)`, moving red marble 1 to track space 33.
The shared-table copy uses four local humans named Alex, Sam, Jordan, and Casey.

`CampaignCapture.swift` is a temporary XCTest harness, intentionally outside the
production app and regular test target. Copy it to
`MarblezzzUITests/MarketingCaptureTests.swift`, run `ruby scripts/generate_project.rb`,
and build for testing. Install the app fresh in a dedicated simulator so its
finish preference starts at Original maple, then copy the two
generated JSON saves into its data container under
`Library/Application Support/Marblezzz`, then run only
`MarblezzzUITests/MarketingCaptureTests` with test-without-building. The fixture
files' base64 names are the app's normal persistence keys.

The harness uses StoreKit Test transactions for the app's actual Friends and
Walnut product identifiers. It selects the owned walnut finish through the real
table shop. These are local test purchases, not production purchase claims.
No online matches or remote players are represented.

Capture settings: portrait, light appearance, default Large text category,
status bar 9:41, full Wi-Fi, 100% battery. Devices are iPhone 18 Pro Max
(1320 × 2868) and iPad Pro 13-inch (M5), 2064 × 2752. Screens are:

1. A legitimate midgame against computers.
2. Nine of hearts selected with legal path and confirmation button.
3. Native home with Resume solo and Resume table.
4. Private pass-and-play handoff, with all cards concealed.
5. Opening tutorial lesson.
6. The same midgame with purchased Midnight walnut selected.
7. Bonus real shop showing the selected walnut finish.

Export attachments with `xcrun xcresulttool export attachments --path RESULT
--output-path RAW`. Run `export_captures.py RAW DESTINATION` with a Python runtime
that includes Pillow. Each destination's provenance JSON records the raw native
attachment filename and resulting dimensions.

After capturing, remove the temporary test source and run the project generator
again so the production project does not retain the marketing-only test.

Capture verification: the full iPhone run passed (47.943 seconds). The final
centered iPad run passed (26.082 seconds), with all seven attachments exported
and the board, cards, preview confirmation, and walnut finish visually checked.
The first iPad attempt reached screens 1–5, then failed because the capture
helper dragged outside the centered store sheet. The helper was corrected.

Capturing the 13-inch iPad also revealed an unused right gutter in the native
portrait game layout. The app's outer game stack was made full width, and a
fresh installation was captured again. The final source set contains the
centered native UI. The earlier images remain only in the local comparison
folder `/tmp/marblezzz-campaign/ipad-before-centering`.

For build 4, the seven native screens were recaptured on both devices from the
same validated seed-3 fixture after the card/marble selection update. The
temporary capture harness waited two seconds after each transition so scroll
indicators were absent from the iPhone previews. Both capture runs passed;
the source images and twelve campaign exports were visually reviewed, and
`validate_assets.py` passed. The App Store listing was not changed as part of
this TestFlight-only update.
