import XCTest
import Combine
import StoreKitTest
import MarblezzzCore
@testable import Marblezzz

@MainActor final class GameModelTests: XCTestCase {
    private var directory: URL!
    private var snapshots: SnapshotStore!
    private var transport: SuspendedMatchTransport!
    private var model: GameModel!
    private var purchaseSession: SKTestSession?

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "MarblezzzModelTests-\(UUID())", directoryHint: .isDirectory)
        snapshots = SnapshotStore(directory: directory)
        transport = SuspendedMatchTransport()
        model = GameModel(purchases: PurchaseStore(), transport: transport, snapshots: snapshots)
        model.hapticsEnabled = false
    }
    override func tearDown() async throws {
        model.leaveTable()
        transport.cancelPending()
        purchaseSession?.clearTransactions(); purchaseSession = nil
        model = nil; transport = nil; snapshots = nil
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        directory = nil
    }

    func testReadinessCannotReplaceNewLocalGame() async throws {
        let old = installOnlineTable("old")
        let request = Task { await model.readyOnline() }
        try await transport.waitFor(.ready, matchID: "old")
        model.leaveTable()
        await model.startLocal(MatchSettings())
        let newID = try XCTUnwrap(model.session?.id)
        transport.complete(.ready, matchID: "old", with: .envelope(old))
        await request.value
        XCTAssertEqual(model.session?.id, newID)
        XCTAssertNil(model.onlineMatchID)
        XCTAssertNil(model.notice)
    }

    func testSwapCompletionAfterAccountChangeIsDiscarded() async throws {
        let old = installOnlineTable("old")
        let request = Task { await model.swapOnlineSeats(.red, .yellow) }
        try await transport.waitFor(.swap, matchID: "old")
        transport.playerID = "different-account"
        transport.complete(.swap, matchID: "old", with: .envelope(old))
        await request.value
        XCTAssertNil(model.session)
        XCTAssertNil(model.onlineMatchID)
        XCTAssertTrue(model.notice?.contains("account changed") == true)
        XCTAssertFalse(model.busy)
    }

    func testResignCannotCloseNewLocalGame() async throws {
        _ = installOnlineTable("old")
        let request = Task { await model.resignOnline() }
        try await transport.waitFor(.resign, matchID: "old")
        model.leaveTable()
        await model.startLocal(MatchSettings())
        let newID = try XCTUnwrap(model.session?.id)
        transport.complete(.resign, matchID: "old", with: .none)
        await request.value
        XCTAssertEqual(model.session?.id, newID)
        XCTAssertNil(model.onlineMatchID)
    }

    func testEndGameReloadCannotReplaceNewLocalGame() async throws {
        let old = installOnlineTable("old")
        let request = Task { await model.endOnline() }
        try await transport.waitFor(.end, matchID: "old")
        transport.complete(.end, matchID: "old", with: .ended(true))
        try await transport.waitFor(.load, matchID: "old")
        model.leaveTable()
        await model.startLocal(MatchSettings())
        let newID = try XCTUnwrap(model.session?.id)
        transport.complete(.load, matchID: "old", with: .envelope(old))
        await request.value
        XCTAssertEqual(model.session?.id, newID)
        XCTAssertNil(model.notice)
    }

    func testOldOperationCannotClearNewRefreshBusyState() async throws {
        let old = installOnlineTable("old")
        let oldRequest = Task { await model.readyOnline() }
        try await transport.waitFor(.ready, matchID: "old")
        model.leaveTable()
        let new = installOnlineTable("new")
        let newRequest = Task { await model.refreshOnline() }
        try await transport.waitFor(.load, matchID: "new")
        transport.complete(.ready, matchID: "old", with: .envelope(old))
        await oldRequest.value
        XCTAssertTrue(model.busy, "The newer refresh still owns the loading state")
        XCTAssertEqual(model.session?.id, new.id)
        transport.complete(.load, matchID: "new", with: .envelope(new))
        await newRequest.value
        XCTAssertFalse(model.busy)
        XCTAssertEqual(model.onlineMatchID, "new")
    }

    func testRefreshFailureAfterLeavingDoesNotShowOldError() async throws {
        _ = installOnlineTable("old")
        let request = Task { await model.refreshOnline() }
        try await transport.waitFor(.load, matchID: "old")
        model.leaveTable()
        transport.fail(.load, matchID: "old")
        await request.value
        XCTAssertNil(model.error)
        XCTAssertNil(model.session)
        XCTAssertFalse(model.busy)
    }

    func testEventDuringRefreshQueuesAnotherLoadWithoutCancellingCurrentResult() async throws {
        var first = installOnlineTable("current")
        first.revision = 1
        var latest = first
        latest.revision = 2
        transport.matchEvents.send("current")
        try await transport.waitFor(.load, matchID: "current")
        transport.matchEvents.send("current")
        transport.matchEvents.send("unrelated")
        try await Task.sleep(for: .milliseconds(450))
        transport.complete(.load, matchID: "current", with: .envelope(first))
        try await transport.waitFor(.load, matchID: "current")
        XCTAssertEqual(model.session?.revision, 1, "A newer notification must not cancel the active load")
        transport.complete(.load, matchID: "current", with: .envelope(latest))
        try await waitUntilIdle()
        XCTAssertEqual(model.session?.revision, 2)
        XCTAssertFalse(transport.hasRequest(.load, matchID: "unrelated"))
    }

    func testEventDuringReadinessRefreshesAfterOperationFinishes() async throws {
        var accepted = installOnlineTable("current")
        try accepted.markReady(playerID: "player")
        var latest = accepted
        try latest.markReady(playerID: "friend")
        let request = Task { await model.readyOnline() }
        try await transport.waitFor(.ready, matchID: "current")
        transport.matchEvents.send("current")
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(transport.hasRequest(.load, matchID: "current"))
        transport.complete(.ready, matchID: "current", with: .envelope(accepted))
        await request.value
        try await transport.waitFor(.load, matchID: "current")
        transport.complete(.load, matchID: "current", with: .envelope(latest))
        try await waitUntilIdle()
        XCTAssertTrue(model.session?.allReady == true)
    }

    func testLeavingDiscardsRefreshQueuedDuringOperation() async throws {
        let old = installOnlineTable("old")
        let request = Task { await model.readyOnline() }
        try await transport.waitFor(.ready, matchID: "old")
        transport.matchEvents.send("old")
        try await Task.sleep(for: .milliseconds(450))
        model.leaveTable()
        await model.startLocal(MatchSettings())
        let newID = try XCTUnwrap(model.session?.id)
        transport.complete(.ready, matchID: "old", with: .envelope(old))
        await request.value
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(model.session?.id, newID)
        XCTAssertFalse(transport.hasRequest(.load, matchID: "old"))
        XCTAssertFalse(model.busy)
    }

    private func waitUntilIdle() async throws {
        for _ in 0..<200 {
            if !model.busy { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The model did not finish its operation")
        throw ModelTestFailure.operationDidNotFinish
    }

    func testUnconfirmedNewGamePreservesSavedGame() async throws {
        let saved = MatchEnvelope(settings: MatchSettings(), hostPlayerID: "local-0", seed: 108)
        try await snapshots.save(saved, key: PlayMode.solo.rawValue)
        await model.startLocal(MatchSettings())
        let preserved = try await snapshots.load(key: PlayMode.solo.rawValue)
        XCTAssertEqual(preserved, saved)
        XCTAssertNil(model.session)
        XCTAssertTrue(model.availableSaves.contains(.solo))
        XCTAssertTrue(model.notice?.contains("unfinished solo game") == true)
        XCTAssertFalse(model.busy)
    }

    func testConfirmedNewGameReplacesSaveAndResumes() async throws {
        let old = MatchEnvelope(settings: MatchSettings(), hostPlayerID: "local-0", seed: 108)
        try await snapshots.save(old, key: PlayMode.solo.rawValue)
        await model.startLocal(MatchSettings(), replacingSavedGame: true)
        let newID = try XCTUnwrap(model.session?.id)
        XCTAssertNotEqual(newID, old.id)
        let saved = try await snapshots.load(key: PlayMode.solo.rawValue)
        XCTAssertEqual(saved.id, newID)
        model.leaveTable()
        await model.resume(.solo)
        XCTAssertEqual(model.session?.id, newID)
        XCTAssertTrue(model.handRevealed)
        XCTAssertFalse(model.busy)
    }

    func testOpenCompletionAfterLeavingDoesNotLoadOldTable() async throws {
        try await unlockFriends()
        let request = Task { await model.openOnline("old") }
        try await transport.waitFor(.accept, matchID: "old")
        model.leaveTable()
        await model.startLocal(MatchSettings())
        let newID = try XCTUnwrap(model.session?.id)
        transport.complete(.accept, matchID: "old", with: .none)
        await request.value
        XCTAssertEqual(model.session?.id, newID)
        XCTAssertFalse(transport.hasRequest(.load, matchID: "old"))
        XCTAssertFalse(model.busy)
    }

    func testFailedCommitRecoveryCannotRestoreTableAfterLeaving() async throws {
        try await unlockFriends()
        var old = installOnlineTable("old")
        try old.markReady(playerID: "player")
        try old.markReady(playerID: "friend")
        try old.start(seed: 108, now: Date())
        old.game = GameState(seed: 108, dealer: .blue)
        model.session = old
        let action = try XCTUnwrap(model.legalActions.first)
        let request = Task { await model.commit(action) }
        try await transport.waitFor(.submit, matchID: "old")
        transport.fail(.submit, matchID: "old")
        try await transport.waitFor(.load, matchID: "old")
        model.leaveTable()
        await model.startLocal(MatchSettings())
        let newID = try XCTUnwrap(model.session?.id)
        transport.complete(.load, matchID: "old", with: .envelope(old))
        await request.value
        XCTAssertEqual(model.session?.id, newID)
        XCTAssertNil(model.onlineMatchID)
    }

    func testSoleOnBoardMarbleIsSelectedForOrdinaryCard() throws {
        let card = Card(4)
        var game = GameState(seed: 42, dealer: .blue)
        game.marbles[0].position = .track(3)
        game.hands[Seat.red.rawValue] = [card]
        let action = try XCTUnwrap(GameRules.legalActions(in: game).first { $0.card == card })

        let selection = try XCTUnwrap(GameTableView.impliedSelection(for: card, legalActions: GameRules.legalActions(in: game)))
        XCTAssertEqual(selection.sourceID, 0)
        XCTAssertEqual(selection.action, action)
    }

    func testSolePlayableMarbleIsSelectedWhenOthersAreOnBoard() throws {
        let card = Card(8)
        var game = GameState(seed: 42, dealer: .blue)
        game.marbles[0].position = .track(3)
        game.marbles[1].position = .home(4)
        game.hands[Seat.red.rawValue] = [card]
        let actions = GameRules.legalActions(in: game).filter { $0.card == card }
        let action = try XCTUnwrap(actions.first)
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(action.sourceID, 0)

        let selection = try XCTUnwrap(GameTableView.impliedSelection(for: card, legalActions: actions))
        XCTAssertEqual(selection.sourceID, 0)
        XCTAssertEqual(selection.action, action)
    }

    func testJackSelectsSoleSourceButStillRequiresTarget() throws {
        let card = Card(11)
        var game = GameState(seed: 42, dealer: .blue)
        game.marbles[0].position = .track(3)
        game.marbles[5].position = .track(15)
        game.hands[Seat.red.rawValue] = [card]

        let selection = try XCTUnwrap(GameTableView.impliedSelection(for: card, legalActions: GameRules.legalActions(in: game)))
        XCTAssertEqual(selection.sourceID, 0)
        XCTAssertNil(selection.action)
    }

    func testAceAndKingNeverUseImpliedSelection() {
        var game = GameState(seed: 42, dealer: .blue)
        game.marbles[0].position = .track(3)
        game.hands[Seat.red.rawValue] = [Card(1), Card(13)]
        let actions = GameRules.legalActions(in: game)

        XCTAssertNil(GameTableView.impliedSelection(for: Card(1), legalActions: actions))
        XCTAssertNil(GameTableView.impliedSelection(for: Card(13), legalActions: actions))
    }

    func testMultipleOnBoardMarblesRequireManualSelection() {
        let card = Card(4)
        var game = GameState(seed: 42, dealer: .blue)
        game.marbles[0].position = .track(3)
        game.marbles[1].position = .home(0)
        game.hands[Seat.red.rawValue] = [card]

        XCTAssertNil(GameTableView.impliedSelection(for: card, legalActions: GameRules.legalActions(in: game)))
    }

    func testImpliedSelectionUsesPartnerWhenControllingTheirMarbles() throws {
        let card = Card(4)
        var game = GameState(seed: 42, dealer: .blue)
        for index in 0..<5 { game.marbles[index].position = .home(index) }
        game.marbles[10].position = .track(24)
        game.hands[Seat.red.rawValue] = [card]

        let selection = try XCTUnwrap(GameTableView.impliedSelection(for: card, legalActions: GameRules.legalActions(in: game)))
        XCTAssertEqual(selection.sourceID, 10)
        XCTAssertEqual(selection.action, GameAction(card: card, kind: .move(10, 4)))
    }

    func testMarbleFirstCanChooseAnEntryCard() {
        let ace = Card(1), king = Card(13)
        var game = GameState(seed: 42, dealer: .blue)
        game.hands[Seat.red.rawValue] = [ace, king]
        let actions = GameRules.legalActions(in: game)

        XCTAssertEqual(GameTableView.action(for: ace, sourceID: 0, legalActions: actions),
                       GameAction(card: ace, kind: .enter(0)))
        XCTAssertEqual(GameTableView.action(for: king, sourceID: 0, legalActions: actions),
                       GameAction(card: king, kind: .enter(0)))
        XCTAssertNil(GameTableView.action(for: ace, sourceID: 5, legalActions: actions))
    }

    func testMarbleFirstJackStillNeedsASecondMarble() {
        let jack = Card(11)
        var game = GameState(seed: 42, dealer: .blue)
        game.marbles[0].position = .track(3)
        game.marbles[5].position = .track(15)
        game.hands[Seat.red.rawValue] = [jack]
        let actions = GameRules.legalActions(in: game)

        XCTAssertTrue(actions.contains(GameAction(card: jack, kind: .swap(0, 5))))
        XCTAssertNil(GameTableView.action(for: jack, sourceID: 0, legalActions: actions))
    }

    private func unlockFriends() async throws {
        let testSession = try SKTestSession(configurationFileNamed: "Marblezzz")
        purchaseSession = testSession
        testSession.resetToDefaultState(); testSession.disableDialogs = true; testSession.clearTransactions()
        _ = try await testSession.buyProduct(identifier: ProductID.friends)
        for _ in 0..<50 {
            await model.purchases.refreshEntitlements()
            if model.purchases.hasFriends { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ModelTestFailure.entitlementNotDelivered
    }
    private enum ModelTestFailure: Error { case entitlementNotDelivered, operationDidNotFinish }

    @discardableResult private func installOnlineTable(_ id: String) -> MatchEnvelope {
        var settings = MatchSettings(mode: .online, humanSeats: [.red, .yellow])
        settings.seats[0].playerID = transport.playerID
        settings.seats[0].participantIndex = 0
        settings.seats[1].playerID = "friend"
        settings.seats[1].participantIndex = 1
        let envelope = MatchEnvelope(settings: settings, hostPlayerID: transport.playerID!)
        model.onlineMatchID = id; model.session = envelope; model.handRevealed = true
        return envelope
    }
}

@MainActor private final class SuspendedMatchTransport: MatchTransport {
    enum Method: Hashable { case accept, load, submit, ready, swap, resign, end }
    enum Reply { case envelope(MatchEnvelope), ended(Bool), none }
    private struct Request: Hashable { let method: Method; let matchID: String }
    private enum TestError: Error { case network, unexpectedReply, requestNotReceived }
    private var requests: [Request: CheckedContinuation<Reply, any Error>] = [:]
    private let identity = CurrentValueSubject<String?, Never>("player")
    var playerID: String? {
        get { identity.value }
        set { identity.send(newValue) }
    }
    var authenticated: Bool { playerID != nil }
    var identityChanges: AnyPublisher<String?, Never> { identity.eraseToAnyPublisher() }
    let matchEvents = PassthroughSubject<String, Never>()
    let matchActivations = PassthroughSubject<String, Never>()
    var hasFriendsAccess: () -> Bool = { false }
    var pendingSettings: MatchSettings?
    var pendingHostSeat: Seat = .red
    func authenticate() {}
    func accept(id: String) async throws { _ = try await suspend(.accept, matchID: id) }
    func load(id: String) async throws -> MatchEnvelope { try await envelope(.load, matchID: id) }
    func submit(_ action: GameAction, matchID: String, revision: Int, operationID: UUID) async throws -> MatchEnvelope {
        try await envelope(.submit, matchID: matchID)
    }
    func ready(id: String, acceptingSettingsRevision: Int) async throws -> MatchEnvelope { try await envelope(.ready, matchID: id) }
    func swapSeats(id: String, first: Seat, second: Seat) async throws -> MatchEnvelope { try await envelope(.swap, matchID: id) }
    func resign(id: String) async throws { _ = try await suspend(.resign, matchID: id) }
    func endGame(id: String) async throws -> Bool {
        guard case .ended(let ended) = try await suspend(.end, matchID: id) else { throw TestError.unexpectedReply }
        return ended
    }
    func hasRequest(_ method: Method, matchID: String) -> Bool {
        requests[Request(method: method, matchID: matchID)] != nil
    }
    func waitFor(_ method: Method, matchID: String) async throws {
        for _ in 0..<200 {
            if hasRequest(method, matchID: matchID) { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Transport never received \(method) for \(matchID)")
        throw TestError.requestNotReceived
    }
    func cancelPending() {
        let pending = requests.values
        requests.removeAll()
        for continuation in pending { continuation.resume(throwing: CancellationError()) }
    }
    func complete(_ method: Method, matchID: String, with reply: Reply) {
        requests.removeValue(forKey: Request(method: method, matchID: matchID))?.resume(returning: reply)
    }
    func fail(_ method: Method, matchID: String) {
        requests.removeValue(forKey: Request(method: method, matchID: matchID))?.resume(throwing: TestError.network)
    }
    private func envelope(_ method: Method, matchID: String) async throws -> MatchEnvelope {
        guard case .envelope(let envelope) = try await suspend(method, matchID: matchID) else { throw TestError.unexpectedReply }
        return envelope
    }
    private func suspend(_ method: Method, matchID: String) async throws -> Reply {
        let request = Request(method: method, matchID: matchID)
        return try await withCheckedThrowingContinuation {
            requests[request] = $0
        }
    }
}
