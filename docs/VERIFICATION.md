# Verification record

Recorded September 20, 2026, with Xcode 27.0 (27A266a), Swift 6.4, and macOS 27. No production purchases, external publishing, or Apple account configuration were performed.

## Automated evidence

| Area | Result | Evidence |
| --- | --- | --- |
| Shared rules and session engine | 29 Swift Testing test functions passed, including 60 full-game simulations across Easy and Standard | `/tmp/marblezzz-core-final.log` |
| iPhone native suite | 12 passed, 0 failed, 0 skipped: 6 StoreKit integration tests and 6 UI tests | `/tmp/marblezzz-acceptance.xcresult` |
| iPhone landscape correction | Both landscape tests passed again after changing the layout to use the available aspect ratio; default text also asserts that the cards and turn title are immediately tappable/visible | `/tmp/marblezzz-landscape-final.xcresult` |
| iPad UI | Five UI tests passed as a suite; the additional default-text landscape test passed separately and passed again with the new hand-visibility assertion | `/tmp/marblezzz-ipad-ui.xcresult`, `/tmp/marblezzz-ipad-default.xcresult`, `/tmp/marblezzz-ipad-landscape-final.xcresult` |
| Release compilation | Unsigned arm64 iOS Release build passed; purchase test override arguments are absent from the Release executable | `/tmp/marblezzz-release-final.log` |

The iPhone simulator was an iPhone 18 Pro running iOS 27.0 (24A434). The iPad simulator was an iPad mini (A17 Pro) running iPadOS 26.5 (23F77). Deployment targets are iOS/iPadOS 18; compilation with that target does not constitute a runtime test on iOS 18.

Engine coverage includes card effects, friendly blocking in both directions, entry capture, same-color jack switches, the backward-three shortcut, exact home movement, mandatory play, public hand forfeiture, 5–4–4 dealing and dealer rotation, partner control, immediate victory, card/marble conservation, serialization and replay, observation privacy, all eight timers, resignation, host transfer, cancellation, stale readiness, duplicate operations, and corrupt/newer snapshot recovery. Seeded full games check that every bot action is legal and the game finishes while retaining state invariants.

Native StoreKit tests use `SKTestSession` and verified local transactions. They exercise product prices and Family Sharing configuration, Friends purchase and entitlement reload, refund removal, cosmetic isolation, purchase through the actual `PurchaseStore`, pending approval followed by approval, and failed/cancelled purchase access. StoreKit entitlement delivery is asynchronous; assertions wait for the actual updated entitlement. The local cancellation simulation sometimes returns a generic StoreKit service error, so this case establishes that no access is granted and busy state clears; the specific user-cancelled presentation still requires sandbox/device review.

UI tests exercise a real solo turn through the accessible card/move/confirmation controls, save and resume after termination, the Friends gate, pass-and-play hand hiding before reveal and after backgrounding, all ten tutorial lessons, and landscape at default and maximum accessibility text sizes. These tests do not claim that VoiceOver, all small-device layouts, or physical-device performance have been certified.

## Visual review

Screenshots are actual simulator output from the test runs. Portrait iPhone play, landscape iPhone/iPad play, private handoff, and the storefront were inspected. The final landscape correction places the board and cards beside each other on an iPhone; enlarged text and expanded legal-move controls remain scrollable. Player names can truncate at the largest text sizes, with full identities retained in their accessibility labels.

- [iPhone solo game](screenshots/iphone-solo.png)
- [iPhone landscape game](screenshots/iphone-landscape.png)
- [iPad landscape game](screenshots/ipad-landscape.png)
- [Private pass-and-play handoff](screenshots/private-handoff.png)

## Repeat locally

Run `scripts/verify.sh` for engine tests and a simulator build. Run the native test suite from the shared Marblezzz scheme or use the signed simulator command in the README. Choose an available simulator. Local test purchases are simulated and do not charge a payment method.

On this machine, StoreKit testing on iOS 26.5 failed inside Apple's testing service with `SKInternalErrorDomain Code=3` / `notEntitled`. The iOS 27 service passed after activating `Marblezzz.storekit` in the scheme and running once from Xcode. A fresh simulator may need this setup before command-line StoreKit tests can find products. See Apple's [StoreKit testing setup](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode) and [developer forum discussion of the testing service error](https://developer.apple.com/forums/thread/826971).

Copies of logs and machine-readable summaries are in the ignored local `artifacts/verification` directory. Full `.xcresult` bundles are retained at the paths above; those temporary paths are evidence from this machine, not portable project dependencies.

## Remaining release gates

Game Center integration is implemented and compiles, but no multi-account physical-device match was run. Invitations/readiness, mixed seats, live/asynchronous completion, notification delivery, deadline forwarding with human return, self-forwarding consecutive turns, uncertain network submissions, out-of-turn resignation/cancellation, and account changes require the explicit [feasibility checklist](RELEASE_CHECKLIST.md). The app reports a concrete integration error if Game Center makes a timed-out participant terminal; it does not silently change the agreed one-turn substitution rule.

The publishing team, App Store Connect app and products, provisioning, real sandbox restores and Family Sharing/revocation, oldest supported devices, complete VoiceOver/Reduce Motion sessions, performance profiling, support/privacy URLs, inventor rule sign-off, and TestFlight playtests remain unverified or unconfigured. This is an implemented development build with documented evidence, not a certified App Store release.
