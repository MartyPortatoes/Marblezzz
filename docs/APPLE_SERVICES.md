# Apple services integration

## Boundaries

`MarblezzzCore` is independent of GameKit, StoreKit and rendering. Its `PlayerObservation` contains one private hand, board state, card counts, public discards and turn number. It has no opponent hands, stock or random generator. Computer decisions are pure and repeatable.

Game Center transports a full versioned `MatchEnvelope`. This deliberately accepts client trust: a modified participant's app could inspect other hands or the stock. Normal UI and diagnostics do not expose those fields. There is no claim of server-enforced anti-cheat or protected competitive rankings.

Only `GKTurnBasedMatch.currentParticipant` may submit game state. Application seats are mapped to immutable Game Center participant indexes, so bots do not require Game Center identities. Invitees accept a purchase-gated lobby before cards are dealt. All participants receive stable seat mapping and room settings.

## Commit and recovery

Load fresh match data before a write; validate envelope versions and board/card invariants. Compare the UI's expected revision, reject stale actions, and attach a UUID operation identifier. Keep recent operation identifiers in the saved payload. If a response is lost, fetch the match and check for that operation before retrying. Per-match locking avoids concurrent local submissions.

This is not a compare-and-swap service: Game Center does not expose a server conditional-write primitive for custom match data. Two devices simultaneously using the same Game Center player remain a qualification scenario. Clients must resynchronize after conflicts, never promise a stronger multi-device guarantee than the service provides.

Completed exchanges must be merged before saving, passing or ending the match. Cancellation and readiness messages use the authenticated exchange sender as identity. Host cancellation uses a non-expiring control exchange; the current participant applies it and ends the match. The host sees an explicit pending status when finalization cannot occur immediately.

Seat changes increment a settings revision and clear readiness. An acceptance names the settings revision the player actually reviewed; stale acceptance exchanges cannot approve a changed table. Game Center identity changes close the currently displayed table and never reuse another identity's cache.

## Timer qualification

Game Center deadlines transfer transport authority. They do not run our bot. The receiving authorized client reconciles one expired game turn, runs subsequent preset computer seats, persists the result and passes to the next human. No app runs a background server while every device is closed.

The integration records Game Center participant status/outcome/deadline metadata in the in-app Diagnostics screen, never cards or stock. If the service returns `timeExpired` as a terminal participant outcome, code raises a concrete integration error rather than permanently replacing a player contrary to the agreed one-turn rule. This exact behavior must be qualified with real Game Center identities and devices before release.

A new application turn calls `endTurn` even if the next eligible human is the same participant, so the service deadline can restart without inventing a marble move. Ordinary refreshes use `saveCurrentTurn` and do not extend the deadline. Include same-participant consecutive turns and the final remaining human in the device feasibility gate.

## StoreKit

Products are non-consumables:

| ID | US launch price | Family Sharing |
| --- | --- | --- |
| `com.marblezzz.friends` | $4.99 | Enabled |
| `com.marblezzz.walnut` | $1.99 | Disabled |
| `com.marblezzz.coastal` | $1.99 | Disabled |

All access comes from verified `Transaction.currentEntitlements` and `Transaction.updates`. Apple's local verified transaction cache supports offline access; no unsigned UserDefaults purchase flag is used. Purchase cancellation grants nothing; pending transactions wait for approval; revocation removes access. Original appearance remains free. Cosmetic ownership never grants Friends access.

The `.storekit` file is for Xcode testing. Products, pricing, Family Sharing, localization and agreements must also be configured in App Store Connect. The app displays Apple's localized product price and disables purchase when product metadata is unavailable.

## Sources

- [Turn-based matches](https://developer.apple.com/documentation/gamekit/starting-turn-based-matches-and-passing-turns-between-players)
- [Turn forwarding](https://developer.apple.com/documentation/gamekit/gkturnbasedmatch/1520765-endturn)
- [Exchange timeouts](https://developer.apple.com/documentation/gamekit/exchange-timeouts)
- [Ending a match](https://developer.apple.com/documentation/gamekit/gkturnbasedmatch/endmatchinturn(withmatch:completionhandler:))
- [StoreKit entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
