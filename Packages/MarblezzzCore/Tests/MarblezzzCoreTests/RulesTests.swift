import Foundation
import Testing
@testable import MarblezzzCore

private func fixture(_ cards: [Card], positions: [Int: Position] = [:], actor: Seat = .red) -> GameState {
    var state = GameState(seed: 42, dealer: .blue)
    state.hands = Array(repeating: [], count: 4)
    state.hands[actor.rawValue] = cards
    state.hands[actor.next.rawValue] = [Card.deck.first { !cards.contains($0) }!]
    state.stock = Card.deck.filter { !state.hands.flatMap { $0 }.contains($0) }
    state.discards = []; state.activeSeat = actor
    for (id, position) in positions { state.marbles[id].position = position }
    return state
}

@Test func boardMatchesPhotograph() {
    #expect(BoardDefinition.track.count == 48)
    #expect(Set(BoardDefinition.track.map { "\($0.x),\($0.y)" }).count == 48)
    #expect(BoardDefinition.track[0] == BoardPoint(x: 0, y: 5))
    #expect(BoardDefinition.track[12] == BoardPoint(x: 7, y: 0))
    #expect(BoardDefinition.track[24] == BoardPoint(x: 12, y: 7))
    #expect(BoardDefinition.track[36] == BoardPoint(x: 5, y: 12))
    #expect(BoardDefinition.home(.red, 4) == BoardPoint(x: 5, y: 6))
}

@Test(arguments: [1, 13]) func entryCardsCaptureUnprotectedEntry(rank: Int) throws {
    let card = Card(rank)
    let state = fixture([card], positions: [5: .track(0)])
    let result = try GameRules.apply(GameAction(card: card, kind: .enter(0)), to: state).state
    #expect(result.marbles[0].position == .track(0))
    #expect(result.marbles[5].position == .reserve)
}

@Test(arguments: [1, 13]) func friendlyEntryIsBlocked(rank: Int) {
    let state = fixture([Card(rank)], positions: [10: .track(0)])
    #expect(GameRules.legalActions(in: state) == [GameAction(kind: .forfeitHand)])
}

@Test func aceHasBothChoicesKingOnlyEnters() {
    let state = fixture([Card(1), Card(13)], positions: [0: .track(9)])
    let actions = GameRules.legalActions(in: state)
    #expect(actions.contains(GameAction(card: Card(1), kind: .move(0, 1))))
    #expect(actions.contains(GameAction(card: Card(1), kind: .enter(1))))
    #expect(!actions.contains { $0.card?.rank == 13 && $0.kind == .move(0, 13) })
}

@Test(arguments: [2,4,5,6,7,8,9,10,12]) func numberCardsMoveExactValue(rank: Int) throws {
    let state = fixture([Card(rank)], positions: [0: .track(0)])
    let result = try GameRules.apply(GameAction(card: Card(rank), kind: .move(0, rank)), to: state).state
    #expect(result.marbles[0].position == .track(rank))
}

@Test(arguments: [1,10]) func friendlyBlocksInBothDirections(blocker: Int) {
    let forward = fixture([Card(4)], positions: [0: .track(4), blocker: .track(6)])
    #expect(!GameRules.legalActions(in: forward).contains(GameAction(card: Card(4), kind: .move(0,4))))
    let backward = fixture([Card(3)], positions: [0: .track(8), blocker: .track(6)])
    #expect(!GameRules.legalActions(in: backward).contains(GameAction(card: Card(3), kind: .move(0,-3))))
}

@Test func opponentsArePassedButOnlyDestinationCaptured() throws {
    let state = fixture([Card(4)], positions: [0: .track(4), 5: .track(6), 15: .track(8)])
    let next = try GameRules.apply(GameAction(card: Card(4), kind: .move(0,4)), to: state).state
    #expect(next.marbles[5].position == .track(6))
    #expect(next.marbles[15].position == .reserve)
}

@Test func threeShortcutAndCompulsoryHome() throws {
    var state = fixture([Card(3)], positions: [0: .track(0)])
    state = try GameRules.apply(GameAction(card: Card(3), kind: .move(0,-3)), to: state).state
    #expect(state.marbles[0].position == .track(45))
    let enterHome = fixture([Card(4)], positions: [0: .track(45)])
    let next = try GameRules.apply(GameAction(card: Card(4), kind: .move(0,4)), to: enterHome).state
    #expect(next.marbles[0].position == .home(1))
    let overshoot = fixture([Card(10)], positions: [0: .track(45)])
    #expect(GameRules.legalActions(in: overshoot) == [GameAction(kind: .forfeitHand)])
}

@Test func homeBlocksOvershootAndBackward() {
    let state = fixture([Card(3), Card(6), Card(4)], positions: [0: .home(0), 1: .home(2)])
    #expect(!GameRules.legalActions(in: state).contains { $0.sourceID == 0 })
}

@Test(arguments: [1,5,10,15]) func jackSwitchesAnyOtherTrackMarble(target: Int) throws {
    let state = fixture([Card(11)], positions: [0: .track(3), target: .track(20)])
    let action = GameAction(card: Card(11), kind: .swap(0,target))
    #expect(GameRules.legalActions(in: state).contains(action))
    let next = try GameRules.apply(action, to: state).state
    #expect(next.marbles[0].position == .track(20))
    #expect(next.marbles[target].position == .track(3))
}

@Test func jackCannotUseHomeOrReserveOrOnlyOtherPlayers() {
    let state = fixture([Card(11)], positions: [0: .home(0), 5: .track(5), 15: .track(8)])
    #expect(GameRules.legalActions(in: state) == [GameAction(kind: .forfeitHand)])
    let ownTrack = fixture([Card(11)], positions: [0: .track(3), 10: .home(2)])
    #expect(GameRules.legalActions(in: ownTrack) == [GameAction(kind: .forfeitHand)])
}

@Test func mustPlayEvenSameColorJackSwap() {
    let state = fixture([Card(11)], positions: [0: .track(2), 1: .track(3)])
    #expect(throws: RuleError.mustPlay) { try GameRules.apply(GameAction(kind: .forfeitHand), to: state) }
}

@Test func cannotDiscardBadCardWhenAnotherIsPlayable() {
    let state = fixture([Card(1), Card(7)])
    #expect(throws: RuleError.mustPlay) { try GameRules.apply(GameAction(kind: .forfeitHand), to: state) }
    #expect(!GameRules.legalActions(in: state).contains { $0.card?.rank == 7 })
}

@Test func forfeitRevealsAllCardsAndSkipsUntilDeal() throws {
    let cards = [Card(4), Card(7)]
    let state = fixture(cards)
    let next = try GameRules.apply(GameAction(kind: .forfeitHand), to: state)
    #expect(next.state.hands[0].isEmpty)
    #expect(next.events.first?.cards == cards)
    #expect(next.state.discards == cards)
    #expect(next.state.activeSeat == .yellow)
}

@Test func partnerUsesOwnHandAndTurn() throws {
    var positions = Dictionary(uniqueKeysWithValues: (0..<5).map { ($0, Position.home($0)) })
    positions[10] = .track(30)
    let state = fixture([Card(2)], positions: positions)
    #expect(state.controlledSeat(for: .red) == .green)
    let next = try GameRules.apply(GameAction(card: Card(2), kind: .move(10,2)), to: state).state
    #expect(next.marbles[10].position == .track(32))
    #expect(next.hands[0].isEmpty)
}

@Test func tenthMarbleWinsImmediately() throws {
    var positions = Dictionary(uniqueKeysWithValues: (0..<5).map { ($0, Position.home($0)) })
    for index in 0..<4 { positions[10+index] = .home(index+1) }
    positions[14] = .track(23)
    let state = fixture([Card(1)], positions: positions)
    let next = try GameRules.apply(GameAction(card: Card(1), kind: .move(14,1)), to: state).state
    #expect(next.result == .won(team: 0))
    #expect(next.activeSeat == .red)
    #expect(next.handNumber == state.handNumber)
}

@Test func dealCycleAndDealerRotation() throws {
    var state = GameState(seed: 17, dealer: .blue)
    #expect(state.hands.map(\.count) == [5,5,5,5])
    #expect(state.stock.count == 32)
    // Cards are conserved while clearing each hand to drive the production deal transition.
    for stage in 0..<3 {
        state.discards += state.hands.flatMap { $0 }; state.hands = Array(repeating: [], count: 4)
        state.advanceTurn()
        #expect(state.dealIndex == (stage + 1) % 3)
        #expect(state.dealer == (stage == 2 ? .red : .blue))
        #expect(state.hands.map(\.count) == Array(repeating: stage == 2 ? 5 : 4, count: 4))
        try state.validate()
    }
}

@Test func observationHasNoOpponentHandDependency() {
    var a = GameState(seed: 12)
    let before = PlayerObservation(state: a, seat: a.activeSeat)
    a.hands[a.activeSeat.next.rawValue].swapAt(0, 1)
    a.stock.reverse()
    let after = PlayerObservation(state: a, seat: a.activeSeat)
    #expect(before == after)
    #expect(BotPlayer.choose(in: before) == BotPlayer.choose(in: after))
}

@Test(arguments: 0..<30, BotDifficulty.allCases) func seededFullGamesConserveAndFinish(seed: Int, difficulty: BotDifficulty) throws {
    var state = GameState(seed: UInt64(seed))
    for _ in 0..<5000 {
        if state.result != nil { break }
        let view = PlayerObservation(state: state, seat: state.activeSeat)
        let action = try #require(BotPlayer.choose(in: view, difficulty: difficulty))
        let next = try GameRules.apply(action, to: state).state
        let replay = try GameRules.apply(action, to: state).state
        #expect(next == replay)
        try next.validate()
        state = next
    }
    #expect(state.result != nil, "Seed \(seed) did not finish within 5,000 turns")
}
