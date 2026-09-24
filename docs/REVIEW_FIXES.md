# Final review fixes

Follow-up to the [September 23, 2026 review](../artifacts/final-review-2026-09-23/REVIEW.md). This records implementation and regression coverage; it does not certify release readiness. The original review and [earlier verification record](VERIFICATION.md) remain historical evidence.

## Findings and changes

| Finding | Implemented change | Regression strategy |
| --- | --- | --- |
| 1. Malformed snapshots can crash | `GameState.validate()` requires stock counts of 32/16/0 and maximum hand sizes of 5/4/4. Completed envelopes always validate four ordered seats and the remaining settings; only the minimum human count is relaxed. | Decode malformed JSON with missing stock, oversized hands, missing/reordered/duplicate seats, and duplicate player IDs. Verify legitimate final resignation, snapshot recovery, and the complete 5–4–4 cycle. See [SessionTests.swift](../Packages/MarblezzzCore/Tests/MarblezzzCoreTests/SessionTests.swift). |
| 2. Late online responses can replace another table | Model operations capture generation, account, and match identity and check them after suspension. Each operation owns its loading state. Relevant Game Center events are coalesced into a follow-up refresh without cancelling an active load. | Suspend the real model's transport at readiness, seat changes, resignation, opening, end-game reload, and failed-commit recovery. Leave or switch accounts before completion. Also exercise overlapping notifications, events during readiness, unrelated tables, and pending-event cleanup. See [GameModelTests.swift](../MarblezzzTests/GameModelTests.swift). |
| 3. Starting over silently replaces progress | Resume is the primary action for an unfinished local game. Separate New Game actions require confirmation. `startLocal` also checks the persisted save before allowing replacement. | Verify unconfirmed starts preserve the saved envelope, confirmed starts create a new resumable game, and cancelling the UI confirmation preserves the existing hand. |
| 4. Essential text does not scale | Card glyphs and dimensions use scaled metrics. Player counts and the hand summary use semantic text styles; player summaries and cards adapt into rows as space requires. | Exercise a complete turn at maximum accessibility text size, plus default landscape, save/resume, and pass-and-play privacy. Inspect captures for clipping and control reachability. The maximum-text turn passes on iPhone and iPad; see the device results below. |
| 5. Seat and turn labels lack contrast | Seat/partner text and the online “Your turn” label use dark pine text; colored symbols retain seat identity. | Inspect table setup and online status at normal and accessibility sizes; retain color-independent symbols and accessibility labels. The live online list still requires device verification. |
| 6. Purchase outcomes appear offscreen | The storefront presents a visible “Store update” alert for purchase/restore results. New attempts clear stale messages; cancelled purchases do not report success or grant access. | Local StoreKit tests cover entitlement changes and pending approval. A UI test triggers Ask to Buy and checks the pending-result alert and dismissal. These use simulated transactions. |
| 7. Tutorial button titles disappear | Next and Let’s play explicitly use cream foreground text. Tutorial headings scale, and navigation stacks vertically at accessibility sizes. | Traverse all ten lessons and inspect the primary action at ordinary and accessibility text sizes. Navigation identifiers alone do not establish visual contrast. |

The decorative home board also skips unchanged SpriteKit frames and requests a render after content, geometry, or foreground changes. Gameplay keeps continuous rendering for movement. This addresses the review's efficiency opportunity; a battery or frame-time improvement has not been measured on hardware.

## Verification status

| Check | Status for these fixes |
| --- | --- |
| Core package | **35 test functions passed**, including 60 seeded full games and the new malformed-snapshot regressions. Command: `swift test --scratch-path /tmp/marblezzz-core-fixes-build`; log: `/tmp/marblezzz-core-fixes-tests.log`. |
| Native model and commerce | **13 model tests and 6 commerce tests passed.** The follow-up model run includes all three event-coalescing regressions. |
| iPhone UI | **All 9 scenarios passed across the initial and targeted follow-up runs.** The initial 6/8 result led to a visible two-action save alert and viewport-based test scrolling; both follow-up cases passed. The ninth test traversed all ten tutorial lessons at the largest text size. |
| iPad mini (A17 Pro), iPadOS 27 simulator | **All 9 UI tests passed in one final run**, including normal/maximum-text landscape gameplay, save/resume and cancellation, hand privacy, purchase feedback, and ordinary/maximum-text tutorial navigation. |
| Final Release build | **Unsigned generic-iOS Release build passed** after integration. The Release executable contains neither `--uitesting` nor `--friends-unlocked`. Signing, archive validation, and distribution remain separate gates. |

Local logs and screenshots are saved in [`artifacts/review-fixes-2026-09-23`](../artifacts/review-fixes-2026-09-23/). Result bundles are under `/tmp/marblezzz-review-fixes/`: `iphone-tests.xcresult`, `followup-tests.xcresult`, `iphone-tutorial-ax.xcresult`, and `ipad-tests.xcresult`. The initial bundle retains the two resolved UI failures. These ignored/local artifacts are evidence, not portable project dependencies.

Visual inspection confirms the home board renders, the five-card hand fits at default landscape size, scaled cards wrap and remain playable, seat labels are readable, the save alert exposes both choices, purchase feedback is visible, and tutorial navigation remains readable at ordinary and maximum text sizes. Maximum text requires scrolling, as expected. Physical VoiceOver operation remains unverified.

## Manual release gates

These remain open; use the full [release checklist](RELEASE_CHECKLIST.md) to record results.

- **Physical iPhone and iPad:** small and large layouts, both orientations, iPad resizing/multitasking, the oldest supported iOS version, maximum Dynamic Type, a complete VoiceOver turn, Reduce Motion, sound/haptic settings, and pass-and-play/app-switcher privacy. Profile idle rendering, animations, and repeated-game memory in Instruments.
- **At least two real Game Center accounts:** invitation and readiness, seat changes, complete matches, account/device switching, duplicate notifications, interrupted submissions, resignations/cancellation, and the two-minute timeout with the human returning on a later turn. Confirm the agreed timeout semantics against the real service.
- **Sandbox and TestFlight StoreKit:** disable the local `.storekit` configuration and verify actual products, purchase/cancellation/pending approval, restore across devices, offline ownership, refunds/revocation, Friends Family Sharing, and cosmetic isolation. Local StoreKit test success does not verify App Store Connect setup.
- **Distribution:** complete Apple configuration and metadata, produce and validate a signed Release archive, run TestFlight playtests, and resolve remaining findings before submission. No upload or publication is established by this record.
