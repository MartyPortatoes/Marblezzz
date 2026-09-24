# App Store Connect publication — September 24, 2026

Marblezzz **1.0 (1)** has been uploaded, processed by Apple, and attached to the draft App Store version. It is ready for internal TestFlight testing. It has not been submitted to App Review or released publicly.

## Published destinations

- [Source repository](https://github.com/MartyPortatoes/Marblezzz)
- [Marketing website](https://martyportatoes.github.io/Marblezzz/)
- [Support](https://martyportatoes.github.io/Marblezzz/support/) — Marblezzz@mattp.me
- [Privacy policy](https://martyportatoes.github.io/Marblezzz/privacy/)
- [App Store Connect](https://appstoreconnect.apple.com/apps/6815504897/distribution)
- [TestFlight](https://appstoreconnect.apple.com/teams/cb60c965-0b6c-4c8c-a21c-1290dd674a1e/apps/6815504897/testflight)

The website's home, support, privacy, stylesheet, icon, and gameplay image were fetched from production and matched to the local published files. Desktop and narrow mobile layouts were visually checked. GitHub Pages deployment [35952998519](https://github.com/MartyPortatoes/Marblezzz/actions/runs/35952998519) succeeded.

## Apple configuration and readback

| Item | Verified state |
| --- | --- |
| Publisher / team | Matthew Robert Portelos / `V25M7FFAP2` |
| App / bundle / SKU | `6815504897` / `com.marblezzz.app` / `marblezzz-ios` |
| Version | 1.0, Prepare for Submission; manual release selected |
| Build | `e930da14-2439-4ed0-9695-fef48b10d234`, build 1, `VALID`, `APP_STORE_ELIGIBLE` |
| TestFlight | `READY_FOR_BETA_TESTING` internally; `READY_FOR_BETA_SUBMISSION` externally |
| Tester delivery | No tester groups configured and no external invitations sent. Add chosen testers in TestFlight. Fastlane's generic “distributed” log does not establish tester access. |
| Export compliance | Build reports `usesNonExemptEncryption: false` |
| Game Center | Enabled on bundle identifier and version 1.0; real multiplayer qualification still pending |
| English listing | Name, subtitle, description, promotional text, keywords, copyright, support, marketing and privacy URLs saved |
| Screenshots | Six iPhone and six iPad images; all `COMPLETE`, local MD5 checksums matched, ordered 01–06; duplicate upload-retry records removed |
| App icon | New opaque 1024-pixel artwork installed in the app and delivered with build 1 |
| Base price | Free, USA base price verified at 0.0 |
| Availability | 175 territories configured, including future territories; this is configuration, not public release |
| Age rating | Apple's calculated rating is 4+, Brazil L, Korea All; no contest-event, wagering, chat, broad UGC or objectionable-content features declared |
| Content rights | No third-party content declared; app artwork and native game presentation are original |
| Publisher business readiness | Free and paid agreements, bank account, US tax form and Digital Services Act status all Active; verified in ASC without accepting new terms |
| App Privacy | “Data Not Collected” saved; final Publish confirmation pending |

## In-app purchases

All three non-consumables have English names/descriptions, prices, territory availability, review notes, and complete review screenshots. Apple reports `READY_TO_SUBMIT`, which is not approval or a successful sandbox transaction.

| Product | Product ID | ASC ID | USA price | Family Sharing |
| --- | --- | --- | --- | --- |
| Friends | `com.marblezzz.friends` | `6815509523` | $4.99 | Enabled |
| Midnight walnut | `com.marblezzz.walnut` | `6815509582` | $1.99 | Disabled |
| Coastal oak | `com.marblezzz.coastal` | `6815509411` | $1.99 | Disabled |

Submit the first purchases with the first App Store version after service qualification. Actual sandbox purchase/restore, revocation and Family Sharing behavior remain unverified.

## Build evidence

The strict gate ran against clean committed source **`cde37d7a83a15fa95818c39f2128ad32c10d2d0a`**. Subsequent publication documentation does not change the uploaded executable.

- Static resource, secret-file/signature, localization, listing-length and reviewed-image hash checks passed.
- Core engine: 35 test functions passed, including 60 seeded complete-game cases.
- Native unit tests: 13 model and 6 commerce tests passed.
- iPhone UI: all 9 tests passed in the final full run.
- Unsigned generic iOS Release build passed.
- Signed Release archive and IPA export passed using the Marblezzz AppStore profile.
- `fastlane beta_checked` exited successfully after Apple reported processing complete for version 1.0, build 1.

Final local evidence: `artifacts/pre-asc/` and `/tmp/marblezzz-pre-asc-qa/beta-checked.log`. The IPA and symbols are in ignored `build/`. Credentials, signing material and full logs are not published in the source repository. Earlier iPad and accessibility simulation evidence is recorded in [REVIEW_FIXES.md](REVIEW_FIXES.md).

## Remaining before App Review

Use [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md), especially:

1. Real iPhone/iPad play, oldest supported iOS 18, VoiceOver, Dynamic Type, app-switcher hand privacy and Instruments.
2. Two to four distinct Game Center accounts: invitations, readiness, full games, timeouts, return after timeout, resignations, cancellation, account/device switching and interrupted commits.
3. TestFlight/Apple sandbox purchases with the local StoreKit configuration disabled: purchase, cancel, pending approval, restore, refunds/revocation, cross-device access and Friends Family Sharing.
4. Keep publisher business requirements current; existing free/paid agreements, banking, US tax and Digital Services Act statuses were verified Active. No new agreements were accepted in this run.
5. Inventor playtest and rules sign-off, resolve findings, select the first purchases for submission, then submit for App Review.

Do not infer those real-device or real-service results from simulator tests, metadata completeness, Apple build processing or the website deployment.
