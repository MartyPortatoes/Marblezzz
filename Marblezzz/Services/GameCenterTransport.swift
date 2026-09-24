import Foundation
import Combine
import SwiftUI
@preconcurrency import GameKit
import MarblezzzCore

@MainActor protocol MatchTransport: AnyObject {
    var playerID: String? { get }
    var authenticated: Bool { get }
    var identityChanges: AnyPublisher<String?, Never> { get }
    var matchEvents: PassthroughSubject<String, Never> { get }
    var matchActivations: PassthroughSubject<String, Never> { get }
    var hasFriendsAccess: () -> Bool { get set }
    var pendingSettings: MatchSettings? { get set }
    var pendingHostSeat: Seat { get set }
    func authenticate()
    func accept(id: String) async throws
    func load(id: String) async throws -> MatchEnvelope
    func submit(_ action: GameAction, matchID: String, revision: Int, operationID: UUID) async throws -> MatchEnvelope
    func ready(id: String, acceptingSettingsRevision: Int) async throws -> MatchEnvelope
    func swapSeats(id: String, first: Seat, second: Seat) async throws -> MatchEnvelope
    func resign(id: String) async throws
    func endGame(id: String) async throws -> Bool
}

struct OnlineTable: Identifiable {
    var id: String
    var title: String
    var detail: String
    var yourTurn: Bool
    var invitation: Bool
    var ended: Bool
}

private struct ControlMessage: Codable {
    enum Kind: String, Codable { case ready, cancel, swapSeats }
    var id = UUID()
    var kind: Kind
    var firstSeat: Seat?
    var secondSeat: Seat?
    var settingsRevision: Int?
}

@MainActor final class GameCenterTransport: NSObject, ObservableObject, MatchTransport, @preconcurrency GKLocalPlayerListener {
    @Published private(set) var authenticated = false
    @Published private(set) var identity: String?
    @Published private(set) var tables: [OnlineTable] = []
    @Published var authenticationController: UIViewController?
    @Published var errorMessage: String?
    @Published private(set) var diagnostic = "No Game Center session yet."
    let matchEvents = PassthroughSubject<String, Never>()
    let matchActivations = PassthroughSubject<String, Never>()
    var hasFriendsAccess: () -> Bool = { false }
    var pendingSettings: MatchSettings?
    var pendingHostSeat: Seat = .red
    private var busyIDs = Set<String>()
    private var pendingSubmission: [String: UUID] = [:]
    var playerID: String? { identity }
    var identityChanges: AnyPublisher<String?, Never> { $identity.eraseToAnyPublisher() }

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                guard let self else { return }
                self.authenticationController = controller
                self.authenticated = GKLocalPlayer.local.isAuthenticated
                self.identity = self.authenticated ? GKLocalPlayer.local.gamePlayerID : nil
                if let error { self.errorMessage = error.localizedDescription }
                if self.authenticated {
                    GKLocalPlayer.local.unregisterListener(self)
                    GKLocalPlayer.local.register(self)
                    await self.refreshTables()
                } else { self.tables = [] }
            }
        }
    }
    func refreshTables() async {
        guard let accountID = playerID else { return }
        do {
            let matches = try await GKTurnBasedMatch.loadMatches()
            guard playerID == accountID else { return }
            tables = matches.map { match in
                let local = match.participants.first { $0.player?.gamePlayerID == playerID }
                let data = match.matchData.flatMap { try? SnapshotCodec.decode($0) }
                let ended = match.status == .ended || data?.isFinished == true
                let names = match.participants.compactMap { $0.player?.displayName }
                return OnlineTable(id: match.matchID, title: names.isEmpty ? "Invited table" : names.joined(separator: " · "),
                                   detail: ended ? "Finished" : (data?.game == nil ? "Waiting for the table" : "Hand \(data!.game!.handNumber)"),
                                   yourTurn: match.currentParticipant?.player?.gamePlayerID == playerID,
                                   invitation: local?.status == .invited, ended: ended)
            }.sorted { $0.yourTurn && !$1.yourTurn }
        } catch { errorMessage = error.localizedDescription }
    }
    func accept(id: String) async throws {
        guard hasFriendsAccess() else { throw CommerceError.friendsRequired }
        let match = try await GKTurnBasedMatch.load(withID: id)
        if match.participants.first(where: { $0.player?.gamePlayerID == playerID })?.status == .invited {
            try await match.acceptInvite()
        }
    }
    private func read(_ id: String) async throws -> (GKTurnBasedMatch, MatchEnvelope) {
        guard let playerID else { throw CommerceError.signInRequired }
        let match = try await GKTurnBasedMatch.load(withID: id)
        let data = try await match.loadMatchData()
        guard self.playerID == playerID else { throw CommerceError.signInRequired }
        diagnostic = "\(match.matchID)\nStatus: \(match.status.rawValue) · participants: \(match.participants.count)\nCurrent participant: \(match.participants.firstIndex { $0 === match.currentParticipant } ?? -1)\n" +
            match.participants.enumerated().map { "Seat \($0.offset): status \($0.element.status.rawValue), outcome \($0.element.matchOutcome.rawValue), deadline \($0.element.timeoutDate?.description ?? "none")" }.joined(separator: "\n")
        if let data, !data.isEmpty { return (match, try SnapshotCodec.decode(data)) }
        guard match.currentParticipant?.player?.gamePlayerID == playerID,
              var settings = pendingSettings, hasFriendsAccess() else { throw SessionError.notReady }
        let humanSeats = settings.seats.filter { $0.kind == .human }.map(\.seat)
        guard humanSeats.count == match.participants.count, humanSeats.contains(pendingHostSeat) else { throw SessionError.invalidSettings }
        let hostIndex = match.participants.firstIndex { $0.player?.gamePlayerID == playerID }!
        settings.seats[pendingHostSeat.rawValue].participantIndex = hostIndex
        var otherSeats = humanSeats.filter { $0 != pendingHostSeat }.makeIterator()
        for index in match.participants.indices where index != hostIndex {
            settings.seats[otherSeats.next()!.rawValue].participantIndex = index
        }
        var envelope = MatchEnvelope(settings: settings, hostPlayerID: playerID)
        bindParticipants(match, to: &envelope)
        try envelope.markReady(playerID: playerID)
        return (match, envelope)
    }
    private func bindParticipants(_ match: GKTurnBasedMatch, to envelope: inout MatchEnvelope) {
        for index in envelope.settings.seats.indices {
            guard let participantIndex = envelope.settings.seats[index].participantIndex,
                  match.participants.indices.contains(participantIndex),
                  let player = match.participants[participantIndex].player else { continue }
            envelope.settings.seats[index].playerID = player.gamePlayerID
            envelope.settings.seats[index].name = String(player.displayName.prefix(60))
        }
    }
    private func isAuthority(_ match: GKTurnBasedMatch) -> Bool { match.currentParticipant?.player?.gamePlayerID == playerID }

    func load(id: String) async throws -> MatchEnvelope {
        guard !busyIDs.contains(id) else { throw SessionError.staleRevision }
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        let (match, decoded) = try await read(id)
        var envelope = decoded
        bindParticipants(match, to: &envelope)
        guard match.status != .ended, isAuthority(match) else { return envelope }
        let prior = envelope
        try await reconcile(match, envelope: &envelope)
        if envelope != prior || match.matchData == nil || match.matchData?.isEmpty == true || shouldPass(match, envelope: envelope) {
            try await persist(envelope, in: match)
        }
        return envelope
    }
    private func reconcile(_ match: GKTurnBasedMatch, envelope: inout MatchEnvelope) async throws {
        guard isAuthority(match) else { throw SessionError.notYourTurn }
        let now = Date()
        for exchange in (match.exchanges ?? []).sorted(by: { $0.sendDate < $1.sendDate }) {
            guard let data = exchange.data, let request = try? JSONDecoder().decode(ControlMessage.self, from: data),
                  let sender = exchange.sender.player?.gamePlayerID else { continue }
            if !envelope.operationIDs.contains(request.id) {
                switch request.kind {
                case .ready:
                    if envelope.game == nil, let acceptedRevision = request.settingsRevision {
                        try? envelope.markReady(playerID: sender, acceptingSettingsRevision: acceptedRevision)
                    }
                case .cancel:
                    // The authenticated exchange sender, not a claimed payload field, supplies authority.
                    if sender == envelope.hostPlayerID { try envelope.cancel(by: sender) }
                case .swapSeats:
                    if sender == envelope.hostPlayerID, envelope.game == nil, request.settingsRevision == envelope.settingsRevision,
                       let first = request.firstSeat, let second = request.secondSeat {
                        try envelope.swapLobbySeats(first, second, by: sender)
                    }
                }
                envelope.operationIDs.append(request.id)
                envelope.operationIDs = Array(envelope.operationIDs.suffix(96))
            }
            if exchange.status == .active && exchange.recipients.contains(where: { $0.player?.gamePlayerID == playerID }) {
                try await exchange.reply(withLocalizableMessageKey: "Table updated", arguments: [], data: Data())
            }
        }
        for participant in match.participants {
            if participant.status == .declined && envelope.game == nil { envelope.cancelled = true }
            if participant.status == .done, let id = participant.player?.gamePlayerID {
                if participant.matchOutcome == .quit { try envelope.resign(playerID: id) }
                else if participant.matchOutcome == .timeExpired && !envelope.isFinished {
                    // Never silently turn a temporary timeout into permanent elimination.
                    throw GameCenterIntegrationError.timeoutEliminatedPlayer
                }
            }
        }
        if envelope.game == nil && envelope.allReady && !envelope.cancelled {
            try envelope.start(seed: UInt64.random(in: .min ... .max), now: now)
        }
        if !envelope.isFinished {
            let expired = envelope.deadline.map { $0 <= now } == true
            try envelope.runAutomaticTurns(now: now, authorityPlayerID: playerID, allowExpiredTurn: expired)
        }
    }
    private func shouldPass(_ match: GKTurnBasedMatch, envelope: MatchEnvelope) -> Bool {
        guard !envelope.isFinished else { return match.status != .ended }
        if envelope.game != nil { return envelope.currentPlayerID != playerID && envelope.currentPlayerID != nil }
        return envelope.readyPlayerIDs.contains(playerID ?? "") && !envelope.allReady
    }
    private func nextParticipants(_ match: GKTurnBasedMatch, envelope: MatchEnvelope) -> [GKTurnBasedParticipant] {
        if envelope.game == nil {
            return envelope.settings.seats.compactMap { slot in
                guard slot.kind == .human, !envelope.readyPlayerIDs.contains(slot.playerID ?? ""),
                      let index = slot.participantIndex, match.participants.indices.contains(index) else { return nil }
                let participant = match.participants[index]
                return participant.status == .done || participant.status == .declined ? nil : participant
            }
        }
        guard let game = envelope.game else { return [] }
        return (0..<4).compactMap { offset in
            let seat = Seat(rawValue: (game.activeSeat.rawValue + offset) % 4)!
            let slot = envelope.settings.seats[seat.rawValue]
            guard slot.kind == .human, let id = slot.playerID else { return nil }
            return match.participants.first { $0.player?.gamePlayerID == id && $0.status != .done }
        }
    }
    private func persist(_ envelope: MatchEnvelope, in match: GKTurnBasedMatch) async throws {
        guard isAuthority(match) else { throw SessionError.notYourTurn }
        let data = try SnapshotCodec.encode(envelope, maximumBytes: match.matchDataMaximumSize)
        let savedGame = match.matchData.flatMap { try? SnapshotCodec.decode($0).game }
        let beganNewTurn = envelope.game != nil && savedGame?.turn != envelope.game?.turn
        // Reply completion changes the exchange lists; fetch them again before the required merge.
        _ = try await match.loadMatchData()
        if let exchanges = match.completedExchanges, !exchanges.isEmpty {
            try await match.saveMergedMatch(data, withResolvedExchanges: exchanges)
        }
        if envelope.isFinished {
            for participant in match.participants where participant.matchOutcome == .none {
                let seat = envelope.settings.seats.first { $0.playerID == participant.player?.gamePlayerID }
                if let winner = envelope.game?.result?.winningTeam, let seat {
                    participant.matchOutcome = seat.seat.team == winner ? .won : .lost
                } else { participant.matchOutcome = .tied }
            }
            try await match.endMatchInTurn(withMatch: data)
        } else {
            let next = nextParticipants(match, envelope: envelope)
            if let first = next.first, first.player?.gamePlayerID != playerID || beganNewTurn {
                // Ending a genuine application turn also refreshes the service deadline when
                // the same human plays next (for example, everyone else forfeited their hand).
                let timeout = envelope.game == nil || envelope.settings.timeControl == .unlimited ? GKTurnTimeoutNone : Double(envelope.settings.timeControl.rawValue)
                try await match.endTurn(withNextParticipants: next, turnTimeout: timeout, match: data)
            } else { try await match.saveCurrentTurn(withMatch: data) }
        }
        pendingSettings = nil
    }
    func submit(_ action: GameAction, matchID: String, revision: Int, operationID: UUID) async throws -> MatchEnvelope {
        guard hasFriendsAccess() else { throw CommerceError.friendsRequired }
        guard !busyIDs.contains(matchID) else { throw SessionError.staleRevision }
        busyIDs.insert(matchID); defer { busyIDs.remove(matchID) }
        let (match, decoded) = try await read(matchID)
        var envelope = decoded
        if envelope.operationIDs.contains(operationID) { return envelope }
        guard isAuthority(match), let playerID else { throw SessionError.notYourTurn }
        try await reconcile(match, envelope: &envelope)
        if envelope.revision != revision {
            try await persist(envelope, in: match)
            throw SessionError.staleRevision
        }
        try envelope.play(action, by: playerID, expectedRevision: revision, operationID: operationID, now: Date())
        try envelope.runAutomaticTurns(now: Date(), authorityPlayerID: playerID)
        pendingSubmission[matchID] = operationID
        do { try await persist(envelope, in: match); pendingSubmission[matchID] = nil; return envelope }
        catch {
            // A lost response can follow a successful save. Read back before reporting failure.
            if let (_, saved) = try? await read(matchID), saved.operationIDs.contains(operationID) {
                pendingSubmission[matchID] = nil; return saved
            }
            throw error
        }
    }
    func ready(id: String, acceptingSettingsRevision: Int) async throws -> MatchEnvelope {
        guard hasFriendsAccess(), let playerID else { throw CommerceError.friendsRequired }
        guard !busyIDs.contains(id) else { throw SessionError.staleRevision }
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        let (match, decoded) = try await read(id)
        var envelope = decoded; bindParticipants(match, to: &envelope)
        guard envelope.settingsRevision == acceptingSettingsRevision else { throw SessionError.staleRevision }
        if isAuthority(match) {
            try envelope.markReady(playerID: playerID)
            try await reconcile(match, envelope: &envelope)
            try await persist(envelope, in: match)
        } else { try await send(.ready, in: match, settingsRevision: envelope.settingsRevision) }
        return envelope
    }
    func endGame(id: String) async throws -> Bool {
        guard !busyIDs.contains(id) else { throw SessionError.staleRevision }
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        let (match, decoded) = try await read(id)
        var envelope = decoded
        guard let playerID, playerID == envelope.hostPlayerID else { throw SessionError.notHost }
        if isAuthority(match) {
            try envelope.cancel(by: playerID)
            try await reconcile(match, envelope: &envelope)
            try await persist(envelope, in: match)
            return true
        }
        try await send(.cancel, in: match)
        return false
    }
    func swapSeats(id: String, first: Seat, second: Seat) async throws -> MatchEnvelope {
        guard !busyIDs.contains(id) else { throw SessionError.staleRevision }
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        let (match, decoded) = try await read(id)
        var envelope = decoded
        guard let playerID, playerID == envelope.hostPlayerID else { throw SessionError.notHost }
        if isAuthority(match) {
            try envelope.swapLobbySeats(first, second, by: playerID)
            try await reconcile(match, envelope: &envelope)
            try await persist(envelope, in: match)
        } else {
            try await send(.swapSeats, in: match, first: first, second: second, settingsRevision: envelope.settingsRevision)
        }
        return envelope
    }
    private func send(_ kind: ControlMessage.Kind, in match: GKTurnBasedMatch, first: Seat? = nil, second: Seat? = nil, settingsRevision: Int? = nil) async throws {
        let recipients = match.participants.filter {
            $0.player != nil && $0.player?.gamePlayerID != playerID && $0.status != .done && $0.status != .declined
        }
        guard !recipients.isEmpty else { throw SessionError.notReady }
        let data = try JSONEncoder().encode(ControlMessage(kind: kind, firstSeat: first, secondSeat: second, settingsRevision: settingsRevision))
        guard data.count <= match.exchangeDataMaximumSize else { throw SessionError.tooLarge }
        _ = try await match.sendExchange(to: recipients, data: data,
                                         localizableMessageKey: kind == .cancel ? "The host ended this table" : kind == .swapSeats ? "The host updated the table" : "A player is ready",
                                         arguments: [], timeout: GKExchangeTimeoutNone)
    }
    func resign(id: String) async throws {
        guard !busyIDs.contains(id) else { throw SessionError.staleRevision }
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        let (match, decoded) = try await read(id)
        var envelope = decoded
        guard let playerID else { throw CommerceError.signInRequired }
        if isAuthority(match) {
            try await reconcile(match, envelope: &envelope)
            try envelope.resign(playerID: playerID)
            if envelope.isFinished { try await persist(envelope, in: match) }
            else {
                try envelope.runAutomaticTurns(now: Date(), authorityPlayerID: playerID)
                let data = try SnapshotCodec.encode(envelope, maximumBytes: match.matchDataMaximumSize)
                _ = try await match.loadMatchData()
                if let completed = match.completedExchanges, !completed.isEmpty {
                    try await match.saveMergedMatch(data, withResolvedExchanges: completed)
                }
                try await match.participantQuitInTurn(with: .quit, nextParticipants: nextParticipants(match, envelope: envelope),
                                                       turnTimeout: envelope.settings.timeControl == .unlimited ? GKTurnTimeoutNone : Double(envelope.settings.timeControl.rawValue), match: data)
            }
        } else { try await match.participantQuitOutOfTurn(with: .quit) }
        await refreshTables()
    }

    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        matchEvents.send(match.matchID)
        if didBecomeActive { matchActivations.send(match.matchID) }
        Task { await refreshTables() }
    }
    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) { matchEvents.send(match.matchID) }
    func player(_ player: GKPlayer, receivedExchangeRequest exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch) {
        // Every recipient acknowledges controls; only the current participant applies and merges them.
        Task {
            if exchange.status == .active { try? await exchange.reply(withLocalizableMessageKey: "Table updated", arguments: [], data: Data()) }
            matchEvents.send(match.matchID)
        }
    }
    func player(_ player: GKPlayer, receivedExchangeReplies replies: [GKTurnBasedExchangeReply], forCompletedExchange exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch) {
        matchEvents.send(match.matchID)
    }
    func player(_ player: GKPlayer, receivedExchangeCancellation exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch) { matchEvents.send(match.matchID) }
    func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
        // Route Apple's quit request through our explicit confirmation UI.
        errorMessage = "Open this table and choose Resign to confirm leaving the game."
    }
}

enum CommerceError: String, LocalizedError {
    case friendsRequired = "The Friends unlock is required to play with friends."
    case signInRequired = "Sign in to Game Center to play online."
    var errorDescription: String? { rawValue }
}
enum GameCenterIntegrationError: String, LocalizedError {
    case timeoutEliminatedPlayer = "Game Center marked a timed-out player as finished. This conflicts with this table's one-turn substitution rule. The game has been left unchanged; please report this from Diagnostics."
    var errorDescription: String? { rawValue }
}

struct GameCenterMatchmaker: UIViewControllerRepresentable {
    let humanCount: Int
    let onDismiss: () -> Void
    let onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss, onError: onError) }
    func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest(); request.minPlayers = humanCount; request.maxPlayers = humanCount
        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.showExistingMatches = false; controller.matchmakingMode = .inviteOnly
        controller.turnBasedMatchmakerDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: GKTurnBasedMatchmakerViewController, context: Context) {}
    @MainActor final class Coordinator: NSObject, @preconcurrency GKTurnBasedMatchmakerViewControllerDelegate {
        let onDismiss: () -> Void; let onError: (String) -> Void
        init(onDismiss: @escaping () -> Void, onError: @escaping (String) -> Void) { self.onDismiss = onDismiss; self.onError = onError }
        func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) { onDismiss() }
        func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) {
            onError(error.localizedDescription); onDismiss()
        }
    }
}

struct HostedController: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
