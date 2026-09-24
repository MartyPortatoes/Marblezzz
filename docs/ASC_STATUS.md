# App Store Connect publication — September 24, 2026

Marblezzz **26.09.01 (7)** has been uploaded, processed by Apple, and added to the private internal TestFlight group for the account holder. Builds 1 through 6 remain in that group. The existing App Store draft was changed to 26.09.01 and now selects build 7. The app has not been submitted to App Review or released publicly.

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
| Version | 26.09.01, Prepare for Submission; manual release selected; build 7 attached |
| Build | `e36b88f0-dc22-49e8-83d2-bd61cc87e79b`, build 7, `VALID`; builds 1 through 6 remain available |
| TestFlight | Build 7 is `IN_BETA_TESTING` internally; `READY_FOR_BETA_SUBMISSION` externally |
| Tester delivery | Private Testing internal group (`fff70a5f-12db-485c-94f2-7431a225e643`) contains builds 1 through 7 and exactly one tester (account holder). Apple reports the tester as `INSTALLED`; this does not identify which build is installed. No external group or public link was created. |
| Test information | English TestFlight description, feedback contact, website/privacy URLs and What to Test notes saved |
| Export compliance | Build reports `usesNonExemptEncryption: false` |
| Game Center | Enabled on bundle identifier and the 26.09.01 App Store draft; real multiplayer qualification still pending |
| English listing | Name, subtitle, description, promotional text, keywords, copyright, support, marketing and privacy URLs saved |
| Screenshots | The existing App Store listing has six iPhone and six iPad images verified `COMPLETE` after the draft version change. Build-4 captures and twelve campaign exports passed local validation and visual review; the App Store listing images were not replaced in this update. |
| App icon | New opaque 1024-pixel artwork installed in the app and delivered with build 1 |
| Base price | Free, USA base price verified at 0.0 |
| Availability | 175 territories configured, including future territories; this is configuration, not public release |
| Age rating | Apple's calculated rating is 4+, Brazil L, Korea All; no contest-event, wagering, chat, broad UGC or objectionable-content features declared |
| Content rights | No third-party content declared; app artwork and native game presentation are original |
| Publisher business readiness | Free and paid agreements, bank account, US tax form and Digital Services Act status all Active; verified in ASC without accepting new terms |
| App Privacy | “Data Not Collected” published on September 24, 2026 after explicit publisher approval; ASC confirmed “Published a few seconds ago by Matthew Portelos” |

## In-app purchases

All three non-consumables have English names/descriptions, prices, territory availability, review notes, and complete review screenshots. Apple reports `READY_TO_SUBMIT`, which is not approval or a successful sandbox transaction.

| Product | Product ID | ASC ID | USA price | Family Sharing |
| --- | --- | --- | --- | --- |
| Friends | `com.marblezzz.friends` | `6815509523` | $4.99 | Enabled |
| Midnight walnut | `com.marblezzz.walnut` | `6815509582` | $1.99 | Disabled |
| Coastal oak | `com.marblezzz.coastal` | `6815509411` | $1.99 | Disabled |

Submit the first purchases with the first App Store version after service qualification. Actual sandbox purchase/restore, revocation and Family Sharing behavior remain unverified.

## Build evidence

Build 1's strict gate ran against clean committed source `cde37d7a83a15fa95818c39f2128ad32c10d2d0a`. Build 2's gate and signed archive ran against `47b734a`. Build 3's gate and signed archive ran against `789c374`. Build 4's gate and signed archive ran against `8cb66cb`. Build 5's gate and signed archive ran against `06af11f`. Build 6's gate and signed archive ran against clean committed source **`711302f`**. The build-6 IPA SHA-256 is `9c0cab909368af4522527b14e5625668ddf84669e9adcea9b936635339bcfadd`.

Build 7's strict gate and signed archive ran against clean committed source **`f7f3f7d`**. The build-7 IPA SHA-256 is `8386e366ef98c95efa8e88143a79d931ea7e5628f0068d5d7061457ffcae802c`. The IPA contains version `26.09.01` and build `7`; code-signature verification passed after extraction outside the file-provider workspace.

- Static resource, secret-file/signature, localization, listing-length and reviewed-image hash checks passed.
- Core engine: 35 test functions passed, including 60 seeded complete-game cases.
- Native unit tests: 23 model and 6 commerce tests passed, including sole-marble selection, Jack targeting, Ace/King exceptions, multiple marbles, and partner control.
- iPhone UI: all 12 tests passed in the final full run.
- Unsigned generic iOS Release build passed.
- Signed Release archive and IPA export passed using the Marblezzz AppStore profile.
- Build 6 passed the strict gate, including all native unit and UI tests on the iOS 27 iPhone simulator, and the unsigned Release device build. The new regression tests cover switching to another marble with the same card, switching to a marble that needs a different card, and preserving Jack swap targeting.
- The signed build-6 archive and IPA export passed with the Marblezzz AppStore profile. Apple accepted the IPA, processed build 6 as `VALID`, and saved its English What to Test note.
- The upload processed build 6, then a distribute-only call added it to Private Testing. App Store Connect readback verified build 6, its saved What to Test note, group association, one tester, and `IN_BETA_TESTING` internal state. No external beta review submission was made.
- Build 7 passed the strict gate, including rules engine tests, all 12 native UI tests and the unsigned Release device build. The signed archive exported successfully with the Marblezzz AppStore profile.
- Apple accepted and processed build 7 as `VALID`. A distribute-only call added it to Private Testing; readback verified the one-tester group, `IN_BETA_TESTING` internal state, and saved What to Test note. The existing App Store draft was changed to 26.09.01, build 7 was attached, and its listing localization, screenshots, Game Center enablement and manual release setting were verified.

Build-6 local evidence: ignored `artifacts/testflight-build-6/`. Build-7 local evidence: ignored `artifacts/release-26.09.01/`. The IPA and symbols are in ignored `build/`. Credentials, signing material and full logs are not published in the source repository. Earlier iPad and accessibility simulation evidence is recorded in [REVIEW_FIXES.md](REVIEW_FIXES.md).

## Remaining before App Review

Use [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md), especially:

1. Real iPhone/iPad play, oldest supported iOS 18, VoiceOver, Dynamic Type, app-switcher hand privacy and Instruments.
2. Two to four distinct Game Center accounts: invitations, readiness, full games, timeouts, return after timeout, resignations, cancellation, account/device switching and interrupted commits.
3. TestFlight/Apple sandbox purchases with the local StoreKit configuration disabled: purchase, cancel, pending approval, restore, refunds/revocation, cross-device access and Friends Family Sharing.
4. Keep publisher business requirements current; existing free/paid agreements, banking, US tax and Digital Services Act statuses were verified Active. No new agreements were accepted in this run.
5. Inventor playtest and rules sign-off, resolve findings, select the first purchases for submission, then submit for App Review.

Do not infer those real-device or real-service results from simulator tests, metadata completeness, Apple build processing or the website deployment.
