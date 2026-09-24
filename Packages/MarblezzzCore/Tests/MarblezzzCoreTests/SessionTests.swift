import Foundation
import Testing
@testable import MarblezzzCore

private func online(_ time: TimeControl = .twoMinutes) throws -> MatchEnvelope {
    var settings = MatchSettings(mode: .online, humanSeats: [.red, .yellow], timeControl: time)
    settings.seats[0].playerID = "a"; settings.seats[1].playerID = "b"
    var session = MatchEnvelope(settings: settings, hostPlayerID: "a")
    try session.markReady(playerID: "a"); try session.markReady(playerID: "b")
    try session.start(seed: 14, now: Date(timeIntervalSince1970: 0))
    session.game = GameState(seed: 1, dealer: .blue)
    return session
}

@Test func lobbyWaitsForEveryone() throws {
    let session = try online()
    #expect(session.allReady)
    var notReady = MatchEnvelope(settings: session.settings, hostPlayerID: "a")
    try notReady.markReady(playerID: "a")
    #expect(throws: SessionError.notReady) { try notReady.start(seed: 1, now: Date()) }
    #expect(throws: SessionError.notReady) { try notReady.markReady(playerID: "stranger") }
}

@Test func duplicateActionDoesNotReplayAndStaleRevisionRejected() throws {
    var session = try online()
    let action = GameRules.legalActions(in: session.game!)[0], revision = session.revision, id = UUID()
    try session.play(action, by: "a", expectedRevision: revision, operationID: id, now: Date())
    let committed = session
    try session.play(action, by: "a", expectedRevision: revision, operationID: id, now: Date())
    #expect(session == committed)
    #expect(throws: SessionError.staleRevision) {
        try session.play(action, by: "a", expectedRevision: revision, operationID: UUID(), now: Date())
    }
}

@Test func lobbySeatChangesInvalidatePreviousAcceptance() throws {
    let started = try online()
    var lobby = MatchEnvelope(settings: started.settings, hostPlayerID: "a")
    lobby.settings.seats[0].participantIndex = 0
    lobby.settings.seats[1].participantIndex = 1
    try lobby.markReady(playerID: "a", acceptingSettingsRevision: 0)
    try lobby.markReady(playerID: "b", acceptingSettingsRevision: 0)
    #expect(lobby.allReady)
    #expect(throws: SessionError.notHost) { try lobby.swapLobbySeats(.red, .yellow, by: "b") }
    try lobby.swapLobbySeats(.red, .yellow, by: "a")
    #expect(lobby.settings.seats[0].playerID == "b")
    #expect(lobby.settings.seats[0].participantIndex == 1)
    #expect(lobby.settings.seats[1].playerID == "a")
    #expect(lobby.settings.seats[1].participantIndex == 0)
    #expect(lobby.readyPlayerIDs == ["a"])
    #expect(!lobby.allReady)
    #expect(throws: SessionError.staleRevision) { try lobby.markReady(playerID: "b", acceptingSettingsRevision: 0) }
    try lobby.markReady(playerID: "b", acceptingSettingsRevision: 1)
    #expect(lobby.allReady)
}

@Test(arguments: TimeControl.allCases) func timerPolicies(time: TimeControl) throws {
    var session = try online(time)
    let now = Date(timeIntervalSince1970: Double(time.rawValue + 1))
    let moves = try session.runAutomaticTurns(now: now, authorityPlayerID: "b", allowExpiredTurn: true, limit: 1)
    #expect(moves == (time == .unlimited ? 0 : 1))
    #expect(session.settings.seats[0].kind == .human)
    #expect(session.settings.seats[0].playerID == "a")
}

@Test func timeoutNeedsAuthorityAndDoesNotRunEarly() throws {
    var session = try online()
    #expect(try session.runAutomaticTurns(now: Date(timeIntervalSince1970: 100), authorityPlayerID: "a", allowExpiredTurn: true) == 0)
    #expect(throws: SessionError.unsafeTimeout) {
        try session.runAutomaticTurns(now: Date(timeIntervalSince1970: 121), authorityPlayerID: nil, allowExpiredTurn: true)
    }
}

@Test func timedResignationTransfersHostAndPreservesSeat() throws {
    var session = try online()
    let marbles = session.game?.marbles
    try session.resign(playerID: "a")
    #expect(session.hostPlayerID == "b")
    #expect(session.settings.seats[0].kind == .computer)
    #expect(session.game?.marbles == marbles)
    let revision = session.revision
    try session.resign(playerID: "a")
    #expect(session.revision == revision)
    try session.resign(playerID: "b")
    #expect(session.cancelled)
}

@Test func unlimitedResignationForfeitsTeam() throws {
    var session = try online(.unlimited)
    try session.resign(playerID: "a")
    #expect(session.game?.result == .forfeited(winner: 1))
}

@Test func hostOnlyCancellation() throws {
    var session = try online()
    #expect(throws: SessionError.notHost) { try session.cancel(by: "b") }
    try session.cancel(by: "a")
    #expect(session.cancelled)
    #expect(session.game?.result == .cancelled)
}

@Test func versionedRoundTripAndSizeLimit() throws {
    let session = try online()
    let data = try SnapshotCodec.encode(session)
    #expect(try SnapshotCodec.decode(data) == session)
    #expect(throws: SessionError.tooLarge) { try SnapshotCodec.encode(session, maximumBytes: 20) }
    let future = Data("{\"schemaVersion\":9,\"rulesVersion\":9}".utf8)
    #expect(throws: SessionError.newerVersion) { try SnapshotCodec.decode(future) }
}

@Test(arguments: 0...1) func snapshotRejectsStockThatCannotSupplyTheNextDeal(dealIndex: Int) throws {
    var session = try online()
    var state = GameState(seed: 1, dealer: .blue)
    state.dealIndex = dealIndex
    state.handNumber = dealIndex + 1
    state.hands = [[Card(2)], [], [], []]
    state.stock = []
    state.discards = Card.deck.filter { $0 != Card(2) }
    session.game = state
    // Bypass the validating encoder to model malformed JSON received from disk or Game Center.
    let data = try JSONEncoder().encode(session)
    #expect(throws: RuleError.invalidState) { try SnapshotCodec.decode(data) }
}

@Test(arguments: 0...2) func snapshotRejectsMoreCardsThanWereDealt(dealIndex: Int) throws {
    var session = try online()
    var state = GameState(seed: 1, dealer: .blue)
    for _ in 0..<dealIndex {
        state.discards += state.hands.flatMap { $0 }
        state.hands = Array(repeating: [], count: 4)
        state.advanceTurn()
    }
    // Preserve both the stock and all 52 cards while giving one player an extra card.
    let extraCard = state.hands[1].removeLast()
    state.hands[0].append(extraCard)
    session.game = state
    let data = try JSONEncoder().encode(session)
    #expect(throws: RuleError.invalidState) { try SnapshotCodec.decode(data) }
}

@Test func snapshotsRoundTripThroughTheFiveFourFourDealCycle() throws {
    var session = try online()
    var state = GameState(seed: 1, dealer: .blue)
    for stage in 0...3 {
        session.game = state
        let decoded = try SnapshotCodec.decode(SnapshotCodec.encode(session))
        #expect(decoded == session)
        #expect(decoded.game?.stock.count == [32, 16, 0, 32][stage])
        #expect(decoded.game?.hands.map(\.count) == Array(repeating: stage == 0 || stage == 3 ? 5 : 4, count: 4))
        if stage < 3 {
            state.discards += state.hands.flatMap { $0 }
            state.hands = Array(repeating: [], count: 4)
            state.advanceTurn()
        }
    }
    #expect(state.dealer == .red)
}

@Test func completedTableWithNoHumansStillRoundTrips() throws {
    var session = try online()
    try session.resign(playerID: "a")
    try session.resign(playerID: "b")
    #expect(session.settings.humanCount == 0)
    #expect(session.isFinished)
    let decoded = try SnapshotCodec.decode(SnapshotCodec.encode(session))
    #expect(decoded == session)
    #expect(decoded.currentPlayerID == nil)

    session.cancelled = false
    session.game?.result = nil
    let unfinished = try JSONEncoder().encode(session)
    #expect(throws: SessionError.invalidSettings) { try SnapshotCodec.decode(unfinished) }
}

@Test(arguments: [[], [.red, .yellow, .green], [.yellow, .red, .green, .blue], [.red, .red, .green, .blue]] as [[Seat]])
func completedSnapshotRejectsMissingOrMisorderedSeats(seats: [Seat]) throws {
    var session = try online()
    try session.resign(playerID: "a")
    try session.resign(playerID: "b")
    session.settings.seats = seats.map { SeatConfiguration(seat: $0, kind: .computer, name: $0.name) }
    let data = try JSONEncoder().encode(session)
    #expect(throws: SessionError.invalidSettings) { try SnapshotCodec.decode(data) }
}

@Test func completedSnapshotStillRejectsDuplicatePlayerIDs() throws {
    var session = try online()
    try session.resign(playerID: "a")
    try session.resign(playerID: "b")
    session.settings.seats[1].playerID = session.settings.seats[0].playerID
    let data = try JSONEncoder().encode(session)
    #expect(throws: SessionError.invalidSettings) { try SnapshotCodec.decode(data) }
}

@Test func snapshotRecoversCorruptionWithoutDowngradingNewerFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SnapshotStore(directory: directory)
    let first = try online()
    try await store.save(first, key: "game")
    var second = first; second.revision += 1
    try await store.save(second, key: "game")
    let file = directory.appendingPathComponent(Data("game".utf8).base64EncodedString()).appendingPathExtension("json")
    try Data("corrupt".utf8).write(to: file)
    #expect(try await store.load(key: "game") == first)
    try Data("{\"schemaVersion\":99,\"rulesVersion\":1}".utf8).write(to: file)
    await #expect(throws: SessionError.newerVersion) { try await store.load(key: "game") }
    await #expect(throws: SessionError.newerVersion) { try await store.save(second, key: "game") }
    #expect(String(data: try Data(contentsOf: file), encoding: .utf8)?.contains("99") == true)
}
