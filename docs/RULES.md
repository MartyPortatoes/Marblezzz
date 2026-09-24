# Marblezzz rules · version 1

Confirmed by the inventors' representative on September 20, 2026. These definitions supersede the original cheat sheet and preliminary clarifications.

## Board

Four players; five marbles each. Opposite colors are partners: Red + Green and Yellow + Blue. Clockwise shared track of 48 spaces. Each player has an off-board reserve, one track entry and five home spaces. First team with ten marbles home wins immediately.

Track indexes 0–47 start at Red's entry and increase clockwise. Entries: Red 0, Yellow 12, Green 24, Blue 36. Home gates: Red 47, Yellow 11, Green 23, Blue 35. A forward step from the gate enters home space 0. Home indexes increase toward the board center. The center is not a connecting space.

The photograph's track is the integer lattice path through `(0,5) → (5,5) → (5,0) → (7,0) → (7,5) → (12,5) → (12,7) → (7,7) → (7,12) → (5,12) → (5,7) → (0,7) → (0,5)`, counting each unique space once.

## Cards

| Rank | Action |
| --- | --- |
| Ace | Enter a reserve marble directly onto its colored entry, or move one forward |
| King | Enter only |
| Queen | Move forward 12 |
| Jack | Swap one controlled track marble with any other distinct track marble |
| 3 | Move backward 3, only from the track |
| 2, 4–10 | Move one marble forward by that number |

No split sevens, extra turns, jokers, draws or partner card exchanges. Suits distinguish cards but do not change actions.

## Movement

- Use the full distance. Opponents can be passed; friendly marbles block in both directions.
- Landing on an opponent captures it back to reserve. Landing on any friendly marble is illegal.
- Entry spaces have no protection. An entering marble may capture an opponent there.
- Reserve and home marbles cannot be captured or switched.
- A jack may switch two of your own track marbles. It still consumes the card and counts as a legal play. A marble cannot switch with itself.
- Backward 3 may cross the home gate and create a shortcut. No completed-lap requirement.
- Forward movement must turn into home. If the move cannot fit, it is illegal; another lap is not an option.
- Home requires exact movement, with no overshooting, passing, backward movement or exit.

## Hands and turns

Random first dealer. Clockwise play; player after dealer starts every hand. Deal five each, then four each, then four each, completing each hand before the next deal. After the full 52-card cycle, shuffle everything and rotate the dealer clockwise.

**If any card can legally be played, a legal card must be played.** A player may select among legal cards and actions but cannot discard an unplayable card instead. If no card can be played, reveal and discard the entire remaining hand and sit out until the next deal. Later board changes do not bring that player back into the hand.

Hands stay private, including between partners. Played cards and forfeited hands are public.

After all five of a player's marbles are home, that player uses their own cards on their own turns to control their partner's marbles. Ten team marbles home ends the match immediately, without another turn or deal.

## App-only room rules

Timers: 2 minutes, 10 minutes, 1 hour, 2 hours, 6 hours, 24 hours, 3 days, No Limit. Default No Limit. Settings are fixed at the first deal.

Timed rooms: a missed turn gets one computer action; the human remains in their seat. An explicit resignation permanently replaces the seat with a computer. If the host resigns, hosting transfers to the next human clockwise. Last human leaving ends the game.

No Limit: wait indefinitely; no automatic human-seat substitution. Explicit resignation forfeits that player's team. Preconfigured computer seats still play normally.

Only the host can end the entire game without a winner. Everyone can resign. With Apple-only storage, pending computer actions and out-of-turn cancellation complete when an authorized client connects.
