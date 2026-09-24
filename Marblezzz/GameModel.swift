import SwiftUI
import Combine
import MarblezzzCore
import AudioToolbox

@MainActor final class GameModel: ObservableObject {
    @Published var session: MatchEnvelope?
    @Published var onlineMatchID: String?
    @Published var error: String?
    @Published var notice: String?
    @Published private(set) var busy = false
    @Published var handRevealed = false
    @Published var availableSaves = Set<PlayMode>()
    @Published var showStore = false
    @Published var showMatchmaker = false
    let purchases: PurchaseStore
    let transport: any MatchTransport
    let snapshots: SnapshotStore
    private var botTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    private var refreshDebounceTask: Task<Void, Never>?
    private var pendingMatchEvent: String?
    private var matchEventDispatch: UUID?
    private var generation = UUID()
    private var activeOperation: UUID?
    private var saveIndexRevision = 0
    var reduceMotion = false
    var soundEnabled = false
    var hapticsEnabled = true

    private struct Operation {
        let id = UUID()
        let generation: UUID
        let checksAccount: Bool
        let accountID: String?
        var matchID: String?
    }

    init(purchases: PurchaseStore, transport: any MatchTransport, snapshots: SnapshotStore? = nil) {
        self.purchases = purchases; self.transport = transport
        let directory = URL.applicationSupportDirectory.appendingPathComponent("Marblezzz", isDirectory: true)
        self.snapshots = snapshots ?? SnapshotStore(directory: directory)
        transport.hasFriendsAccess = { [weak purchases] in purchases?.hasFriends ?? false }
        transport.matchEvents.sink { [weak self] id in
            self?.queueMatchEvent(id)
        }.store(in: &subscriptions)
        transport.matchActivations.sink { [weak self] id in
            guard let self else { return }
            Task { await self.openOnline(id) }
        }.store(in: &subscriptions)
        transport.identityChanges.removeDuplicates().dropFirst().sink { [weak self] _ in
            guard let self else { return }
            self.clearPendingMatchEvents()
            if self.onlineMatchID != nil {
                self.leaveTable()
                self.notice = "The Game Center account changed. Open a table for your current account to continue."
            }
        }.store(in: &subscriptions)
        Task { await discoverSaves() }
    }
    var game: GameState? { session?.game }
    var viewingSeat: Seat? {
        guard let session, let game else { return nil }
        if session.settings.mode == .online {
            return session.settings.seats.first { $0.playerID == transport.playerID && $0.kind == .human }?.seat
        }
        return session.settings.seats[game.activeSeat.rawValue].kind == .human ? game.activeSeat : nil
    }
    var canPlay: Bool {
        guard !busy, let game, let seat = viewingSeat, game.result == nil, session?.cancelled == false else { return false }
        return game.activeSeat == seat && handRevealed && (session?.settings.mode == .solo || purchases.hasFriends)
    }
    var legalActions: [GameAction] { guard canPlay, let game else { return [] }; return GameRules.legalActions(in: game) }

    private func queueMatchEvent(_ id: String) {
        guard onlineMatchID == id || showMatchmaker || transport.pendingSettings != nil else { return }
        pendingMatchEvent = id
        refreshDebounceTask?.cancel()
        // Only this delay is cancellable by another event. The actual load has its
        // own operation and must finish before a queued refresh can be applied.
        refreshDebounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard let self, !Task.isCancelled else { return }
            self.refreshDebounceTask = nil
            self.drainPendingMatchEvent()
        }
    }
    private func drainPendingMatchEvent() {
        guard !busy, refreshDebounceTask == nil, pendingMatchEvent != nil, matchEventDispatch == nil else { return }
        let dispatch = UUID(), token = generation, account = transport.playerID
        matchEventDispatch = dispatch
        Task { [weak self] in
            guard let self, self.matchEventDispatch == dispatch else { return }
            self.matchEventDispatch = nil
            guard self.generation == token, self.transport.playerID == account,
                  !self.busy, self.refreshDebounceTask == nil, let id = self.pendingMatchEvent else { return }
            self.pendingMatchEvent = nil
            if self.onlineMatchID == id { await self.refreshOnline() }
            else if self.showMatchmaker || self.transport.pendingSettings != nil {
                self.showMatchmaker = false
                await self.openOnline(id)
            }
        }
    }
    private func clearPendingMatchEvents() {
        refreshDebounceTask?.cancel(); refreshDebounceTask = nil
        pendingMatchEvent = nil; matchEventDispatch = nil
    }
    private func beginOperation(checksAccount: Bool = false) -> Operation? {
        guard !busy else { return nil }
        let operation = Operation(generation: generation, checksAccount: checksAccount,
                                  accountID: transport.playerID, matchID: onlineMatchID)
        activeOperation = operation.id; busy = true
        return operation
    }
    private func isCurrent(_ operation: Operation) -> Bool {
        !Task.isCancelled && generation == operation.generation && activeOperation == operation.id &&
            onlineMatchID == operation.matchID && (!operation.checksAccount || transport.playerID == operation.accountID)
    }
    private func finish(_ operation: Operation) {
        // A response from a table we left must not unlock a newer request's controls.
        guard activeOperation == operation.id else { return }
        activeOperation = nil; busy = false
        drainPendingMatchEvent()
    }
    private func invalidateSessionWork() {
        generation = UUID(); botTask?.cancel()
        clearPendingMatchEvents()
        activeOperation = nil; busy = false
    }
    private func report(_ failure: any Error, for operation: Operation) {
        guard isCurrent(operation) else { return }
        error = failure.localizedDescription
    }

    func discoverSaves() async {
        let revision = saveIndexRevision
        var result = Set<PlayMode>()
        for mode in [PlayMode.solo, .passAndPlay] {
            if let save = try? await snapshots.load(key: mode.rawValue), !save.isFinished { result.insert(mode) }
        }
        guard revision == saveIndexRevision else { return }
        availableSaves = result
    }
    func startLocal(_ settings: MatchSettings, replacingSavedGame: Bool = false) async {
        guard settings.mode == .solo || purchases.hasFriends else { showStore = true; return }
        guard !busy else { return }
        invalidateSessionWork()
        guard var operation = beginOperation() else { return }
        defer { finish(operation) }
        do {
            guard settings.mode != .online else { throw SessionError.invalidSettings }
            try settings.validate()
            let existing: MatchEnvelope?
            do { existing = try await snapshots.load(key: settings.mode.rawValue) }
            catch SessionError.noSnapshot { existing = nil }
            guard isCurrent(operation) else { return }
            if existing?.isFinished == false && !replacingSavedGame {
                saveIndexRevision += 1
                availableSaves.insert(settings.mode)
                notice = "You have an unfinished \(settings.mode == .solo ? "solo game" : "pass-and-play game"). Resume it, or confirm starting a new game to replace it."
                return
            }
            let seed: UInt64
            #if DEBUG
            seed = ProcessInfo.processInfo.arguments.contains("--uitesting") ? 108 : UInt64.random(in: .min ... .max)
            #else
            seed = UInt64.random(in: .min ... .max)
            #endif
            let envelope = MatchEnvelope(settings: settings, hostPlayerID: "local-0", seed: seed)
            try await save(envelope, key: settings.mode.rawValue, generation: operation.generation)
            guard isCurrent(operation) else { return }
            onlineMatchID = nil; operation.matchID = nil
            session = envelope; handRevealed = settings.mode == .solo
            notice = nil; startBots()
        } catch { report(error, for: operation) }
    }
    func resume(_ mode: PlayMode) async {
        guard mode == .solo || purchases.hasFriends else { showStore = true; return }
        guard mode != .online, !busy else { return }
        invalidateSessionWork()
        guard var operation = beginOperation() else { return }
        defer { finish(operation) }
        do {
            let restored = try await snapshots.load(key: mode.rawValue)
            guard isCurrent(operation) else { return }
            onlineMatchID = nil; operation.matchID = nil
            session = restored; handRevealed = mode == .solo
            notice = nil; startBots()
        } catch { report(error, for: operation) }
    }
    func commit(_ action: GameAction) async {
        guard canPlay, var envelope = session, let seat = viewingSeat,
              let operation = beginOperation(checksAccount: onlineMatchID != nil) else { return }
        defer { finish(operation) }
        do {
            if let matchID = operation.matchID {
                let updated = try await transport.submit(action, matchID: matchID, revision: envelope.revision, operationID: UUID())
                guard isCurrent(operation) else { return }
                session = updated
            } else {
                try envelope.play(action, by: "local-\(seat.rawValue)", expectedRevision: envelope.revision, operationID: UUID(), now: Date())
                session = envelope
            }
            if session?.settings.mode == .passAndPlay { handRevealed = false }
            try await saveCurrentSession()
            guard isCurrent(operation) else { return }
            if hapticsEnabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
            if soundEnabled { AudioServicesPlaySystemSound(1104) }
            if operation.matchID == nil { startBots() }
        } catch {
            guard isCurrent(operation) else { return }
            self.error = error.localizedDescription
            if let matchID = operation.matchID, let reloaded = try? await transport.load(id: matchID) {
                guard isCurrent(operation) else { return }
                session = reloaded
            }
        }
    }
    private func startBots() {
        botTask?.cancel()
        guard session?.settings.mode != .online else { return }
        let token = generation
        botTask = Task {
            while !Task.isCancelled, self.generation == token, var envelope = self.session,
                  let game = envelope.game, !envelope.isFinished, envelope.settings.seats[game.activeSeat.rawValue].kind == .computer {
                do {
                    try await Task.sleep(for: .milliseconds(self.reduceMotion ? 30 : 420))
                    guard !Task.isCancelled, self.generation == token else { return }
                    try envelope.runAutomaticTurns(now: Date(), authorityPlayerID: nil, limit: 1)
                    self.session = envelope
                    try await self.saveCurrentSession()
                } catch is CancellationError { return }
                catch {
                    guard !Task.isCancelled, self.generation == token else { return }
                    self.error = error.localizedDescription; return
                }
            }
        }
    }
    func setActive(_ active: Bool) {
        if active {
            if onlineMatchID == nil && !busy { startBots() }
        } else {
            botTask?.cancel()
            if session?.settings.mode == .passAndPlay { handRevealed = false }
        }
    }
    private func saveCurrentSession() async throws {
        guard let session else { return }
        let key = onlineMatchID.map { "online-\(transport.playerID ?? "unknown")-\($0)" } ?? session.settings.mode.rawValue
        try await save(session, key: key, generation: generation)
    }
    private func save(_ envelope: MatchEnvelope, key: String, generation token: UUID) async throws {
        saveIndexRevision += 1
        try await snapshots.save(envelope, key: key)
        guard generation == token, !Task.isCancelled else { return }
        if envelope.settings.mode != .online {
            if envelope.isFinished { availableSaves.remove(envelope.settings.mode) }
            else { availableSaves.insert(envelope.settings.mode) }
        }
    }
    func beginOnline(_ settings: MatchSettings, hostSeat: Seat) {
        guard purchases.hasFriends else { showStore = true; return }
        guard transport.authenticated else { transport.authenticate(); return }
        transport.pendingSettings = settings; transport.pendingHostSeat = hostSeat; showMatchmaker = true
    }
    func openOnline(_ id: String) async {
        guard purchases.hasFriends else { showStore = true; return }
        guard !busy else { return }
        invalidateSessionWork()
        guard var operation = beginOperation(checksAccount: true) else { return }
        defer { finish(operation) }
        do {
            try await transport.accept(id: id)
            guard isCurrent(operation) else { return }
            let envelope = try await transport.load(id: id)
            guard isCurrent(operation) else { return }
            onlineMatchID = id; operation.matchID = id; session = envelope
            handRevealed = true; try await saveCurrentSession()
        } catch { report(error, for: operation) }
    }
    func refreshOnline() async {
        guard let matchID = onlineMatchID, let operation = beginOperation(checksAccount: true) else { return }
        defer { finish(operation) }
        do {
            let updated = try await transport.load(id: matchID)
            guard isCurrent(operation) else { return }
            session = updated; try await saveCurrentSession()
        } catch { report(error, for: operation) }
    }
    func readyOnline() async {
        guard let matchID = onlineMatchID, let settingsRevision = session?.settingsRevision,
              let operation = beginOperation(checksAccount: true) else { return }
        defer { finish(operation) }
        do {
            let updated = try await transport.ready(id: matchID, acceptingSettingsRevision: settingsRevision)
            guard isCurrent(operation) else { return }
            session = updated; notice = "Your table acceptance has been sent."
        } catch { report(error, for: operation) }
    }
    func swapOnlineSeats(_ first: Seat, _ second: Seat) async {
        guard let matchID = onlineMatchID, let operation = beginOperation(checksAccount: true) else { return }
        defer { finish(operation) }
        do {
            let updated = try await transport.swapSeats(id: matchID, first: first, second: second)
            guard isCurrent(operation) else { return }
            session = updated
            notice = "Seat changes are sent. Every friend must review and accept the updated table."
        } catch { report(error, for: operation) }
    }
    func resignOnline() async {
        guard let matchID = onlineMatchID, let operation = beginOperation(checksAccount: true) else { return }
        defer { finish(operation) }
        do {
            try await transport.resign(id: matchID)
            guard isCurrent(operation) else { return }
            leaveTable()
        } catch { report(error, for: operation) }
    }
    func endOnline() async {
        guard let matchID = onlineMatchID, let operation = beginOperation(checksAccount: true) else { return }
        defer { finish(operation) }
        do {
            let ended = try await transport.endGame(id: matchID)
            guard isCurrent(operation) else { return }
            if ended {
                let updated = try await transport.load(id: matchID)
                guard isCurrent(operation) else { return }
                session = updated
            }
            notice = ended ? "The table has ended." : "End Game is pending. The next authorized player to connect will finalize it."
        } catch { report(error, for: operation) }
    }
    func leaveTable() {
        invalidateSessionWork()
        session = nil; onlineMatchID = nil; handRevealed = false
    }
}
