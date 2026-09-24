# Release gates

Implementation, unsigned builds and simulator tests do not certify a commercial release. Record real evidence for every remaining gate below. Do not replace an unverified item with a green status based on compilation.

## Apple configuration

- [x] Publishing team `V25M7FFAP2`; bundle ID `com.marblezzz.app` registered with Game Center; Marblezzz ASC app record `6815504897` created.
- [x] Enable Game Center on the identifier and app record; create the App Store distribution profile and signed build.
- [x] Create the three non-consumables listed in APPLE_SERVICES.md. Enable Friends Family Sharing in App Store Connect.
- [x] Complete localized product metadata, price territories and purchase review screenshots; all three products report READY_TO_SUBMIT.
- [x] Confirm active free/paid agreements, banking, US tax and Digital Services Act status in the publisher account.
- [ ] Test actual sandbox products with the local StoreKit configuration disabled.

## Game Center feasibility harness

Use the built app with Diagnostics open in Settings and two to four distinct Game Center identities. Diagnostics list participant statuses, outcomes and deadlines. Record app versions, device/OS, match ID and timestamps; never attach hands or shuffled deck state.

| Scenario | Required evidence |
| --- | --- |
| 2 humans + 2 computers | Both accept setup; correct opposite teams; complete a full match |
| 3 humans + 1 computer | Stable participant mapping, correct hand privacy, no fake Game Center bot account |
| 4 humans | Complete live game and return to a saved game after backgrounding |
| Late/declined invitation | No first deal before all accept; declined lobby handled clearly |
| Host seat reassignment | Correct new mapping; friends accept changed setup again |
| Two-minute timeout | One bot move only; timed-out human remains eligible on later turns |
| All apps closed over deadline | No fabricated server simulation; a qualified client catches up on return |
| Consecutive turns for one human | Correct game turn count and a fresh service deadline, including the final remaining human |
| All 8 timer presets | Test clock boundaries automatically and short/long real service deadlines |
| No Limit | No timeout or bot replacement; resignation forfeits the team |
| Timed resignation | Permanent bot replacement; turn skips the resigned Game Center participant |
| Host resigns | Role transfers clockwise; remaining humans continue |
| Host cancels out of turn | Durable pending exchange, eventual closure, no awarded winner |
| Last human resigns | Match closes without an endless all-computer online session |
| Duplicate/reordered callbacks | No repeated actions; completed exchanges merged before end-turn |
| Network loss during commit | Read-back reconciliation prevents a blind duplicate submission |
| Same player on two devices | Conflict resynchronization, no private-cache crossover |

**Stop the online release gate if Game Center permanently eliminates a timed-out participant, prevents the required return behavior, or cannot preserve these semantics. Report the observed SDK/service behavior and revisit architecture with the user; do not silently alter the rules.**

## Device and gameplay QA

- [ ] Inventors independently compare complete games with RULES.md and sign off.
- [ ] Small iPhone, large iPhone and iPad, portrait and landscape.
- [ ] Oldest supported iOS 18 device/runtime in addition to current iOS versions.
- [ ] VoiceOver plays a complete turn using cards and the legal move list; rotor labels reveal no other hand.
- [ ] Maximum Dynamic Type, Reduce Motion, color-independent symbols, sound off, haptics off.
- [ ] Pass-and-play hides cards before handoff and in the app switcher.
- [ ] Recovery after termination, interrupted saves, corrupt primary snapshot and newer-version snapshot.
- [ ] Instruments: idle rendering, animation responsiveness, memory across repeated games and background transitions.

## Purchases and distribution

- [ ] Purchase/cancel/pending approval/refund/restore using sandbox on real devices.
- [ ] Friends Family Sharing gain and revocation using Sandbox Test Families.
- [ ] Cross-device restore; offline pass-and-play with an existing verified entitlement.
- [ ] Cosmetic purchase never unlocks Friends or changes rules; revoked theme returns to Original.
- [x] Add publisher/support contact to the release copy and publish support/privacy URLs.
- [x] Complete age rating, content rights and export-compliance declarations against the shipping app.
- [x] Publish the App Privacy declaration: Data Not Collected; verified in ASC after publisher approval.
- [x] Capture and upload six final App Store screenshots for each required iPhone/iPad size.
- [x] Archive signed Release and upload to TestFlight; Apple processed 1.0 builds 1 through 6 as VALID. Build 6 is in internal beta testing.
- [x] Keep private internal TestFlight access for the account holder only; the one-tester Private Testing group contains builds 1 through 6.
- [ ] Collect inventor/friend feedback and resolve findings.
- [ ] Submit for App Review only after all release gates pass.

See [ASC_STATUS.md](PUBLICATION_STATUS.md) for the created Apple records, processed build, published website and evidence. Unchecked gates remain unverified.
