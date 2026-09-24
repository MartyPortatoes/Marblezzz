# Marblezzz

Publication: [App Store Connect and TestFlight status](docs/ASC_STATUS.md).

A native iPhone and iPad partnership marble game. Built with SwiftUI, SpriteKit, Game Center, StoreKit 2, and a standalone Swift rules engine. Minimum iOS/iPadOS 18. The photographed 48-space board and confirmed rules are implemented in one shared package.

## Run

Open `Marblezzz.xcodeproj` in Xcode 27, choose **Marblezzz**, and run on an iPhone or iPad simulator. Solo requires neither an account nor a purchase. The shared development scheme uses `Marblezzz/Resources/Marblezzz.storekit` for local test purchases; these do not charge money.

For device builds, select your Apple Developer team and register the bundle identifier `com.marblezzz.app` with Game Center enabled. Real Game Center and App Store purchase testing also require App Store Connect configuration; see [release gates](docs/RELEASE_CHECKLIST.md).

Website: [Marblezzz](https://martyportatoes.github.io/Marblezzz/) · [Support](https://martyportatoes.github.io/Marblezzz/support/) · [Privacy](https://martyportatoes.github.io/Marblezzz/privacy/). Contact: Marblezzz@mattp.me.

The static website is in `site/` and publishes through GitHub Pages on changes to `main`. No app credentials or signing material belong in this repository. The [release automation](fastlane/README.md) provides a Marblezzz-specific version of the BillHive pre-ASC gate.

## Implemented

- Exact 5-marble, 48-space partnership rules, mandatory legal plays, public hand forfeiture, 5–4–4 dealing, and partner takeover.
- Free offline solo with Easy/Standard computers that cannot inspect other hands or the stock.
- Paid pass-and-play with private handoffs and atomic saved-game recovery.
- Game Center invitation/readiness lobby, human/computer seat mapping, saved tables, revision checks, timeout catch-up, resignation, host cancellation exchanges, and redacted diagnostics.
- StoreKit permanent Friends access, walnut/coastal cosmetic packs, verified entitlements, restoration, pending purchases, and refunds.
- Procedural wooden board and glass marbles; card/path previews, accessible legal move list, symbols alongside color, tutorial, sound/haptic settings, and background privacy.

Game Center source integration is not the same as verified multiplayer service behavior. The release checklist explicitly separates automated evidence from the required multi-account, physical-device and App Store Connect gates. The app stops rather than silently changing the rules if Game Center reports a timed-out player as permanently finished.

## Project structure

- `Packages/MarblezzzCore`: Foundation-only state, board, rules, bots, versioned sessions and persistence; Swift Testing tests.
- `Marblezzz`: SwiftUI interface, SpriteKit board, Game Center transport, StoreKit store and resources.
- `MarblezzzTests`: StoreKit integration tests using Apple's local testing service.
- `MarblezzzUITests`: actual application navigation, play, save/resume, private-hand and layout tests.
- `docs`: rules, service design, release preparation and verification record.

There is no third-party app runtime dependency, advertising SDK, analytics SDK, or custom server.

## Verify

```sh
cd Packages/MarblezzzCore
swift test --scratch-path /tmp/marblezzz-package-tests
```

```sh
xcodebuild -project Marblezzz.xcodeproj -scheme Marblezzz \
  -destination 'platform=iOS Simulator,name=Marblezzz iPhone QA' \
  -derivedDataPath /tmp/marblezzz-derived CODE_SIGN_IDENTITY=- test
```

Use a simulator name or UDID that exists on your Mac. Derived data deliberately lives outside the Documents folder to avoid Finder metadata interfering with ad-hoc signing. `scripts/verify.sh` runs the engine tests and an unsigned simulator build without requiring a specific simulator.

Use the iOS 27 simulator for StoreKit tests. In Xcode, check **Edit Scheme → Run → Options → StoreKit Configuration** is `Marblezzz.storekit`; if a fresh command-line simulator returns no products, run the app from Xcode once with that configuration before testing again. Keep ad-hoc signing enabled for the native test suite. The iOS 26.5 StoreKit test service returned an entitlement error on this machine; it was used for UI testing only.

The [verification record](docs/VERIFICATION.md) includes passing engine simulations, native purchase tests, iPhone/iPad UI evidence, screenshots, and the boundaries of that evidence. Required live-service and physical-device checks remain in the [release checklist](docs/RELEASE_CHECKLIST.md).

The checked-in Xcode project is ready to open. After adding or removing source files, regenerate it with `ruby scripts/generate_project.rb` (requires the `xcodeproj` gem, version 1.27.0). This does not change app runtime dependencies. The shipping icon matches `marketing/icons/Marblezzz-AppIcon-1024.png`; `scripts/generate_icon.swift` is the earlier procedural concept, not the shipping artwork.

UI-test flags are compiled only in Debug. Release builds never grant purchases from launch arguments. TestFlight uses actual App Store Connect sandbox products, not the bundled local StoreKit configuration.
