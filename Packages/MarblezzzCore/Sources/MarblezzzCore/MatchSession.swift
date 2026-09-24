import Foundation

public enum PlayMode: String, Codable, CaseIterable, Sendable { case solo, passAndPlay, online }
public enum SeatKind: String, Codable, Sendable { case human, computer }
public enum TimeControl: Int, Codable, CaseIterable, Sendable, Identifiable {
    case twoMinutes = 120, tenMinutes = 600, oneHour = 3600, twoHours = 7200
    case sixHours = 21600, oneDay = 86400, threeDays = 259200, unlimited = 0
    public var id: Int { rawValue }
    public var label: String {
        switch self {
        case .twoMinutes: "2 minutes"
        case .tenMinutes: "10 minutes"
        case .oneHour: "1 hour"
        case .twoHours: "2 hours"
        case .sixHours: "6 hours"
        case .oneDay: "24 hours"
        case .threeDays: "3 days"
        case .unlimited: "No Limit"
        }
    }
    public func deadline(from date: Date) -> Date? { self == .unlimited ? nil : date.addingTimeInterval(Double(rawValue)) }
}

public struct SeatConfiguration: Codable, Equatable, Sendable, Identifiable {
    public var seat: Seat
    public var kind: SeatKind
    public var name: String
    public var playerID: String?
    public var participantIndex: Int?
    public var id: Int { seat.rawValue }
    public init(seat: Seat, kind: SeatKind, name: String, playerID: String? = nil) {
        self.seat = seat; self.kind = kind; self.name = name; self.playerID = playerID; self.participantIndex = nil
    }
}

public struct MatchSettings: Codable, Equatable, Sendable {
    public var mode: PlayMode
    public var seats: [SeatConfiguration]
    public var difficulty: BotDifficulty
    public var timeControl: TimeControl
    public init(mode: PlayMode = .solo, humanSeats: Set<Seat> = [.red], difficulty: BotDifficulty = .standard,
                timeControl: TimeControl = .unlimited) {
        self.mode = mode; self.difficulty = difficulty; self.timeControl = timeControl
        seats = Seat.allCases.map { seat in
            let human = humanSeats.contains(seat)
            return SeatConfiguration(seat: seat, kind: human ? .human : .computer,
                                     name: human ? seat.name : "\(seat.name) computer",
                                     playerID: mode == .online || !human ? nil : "local-\(seat.rawValue)")
        }
    }
    public var humanCount: Int { seats.filter { $0.kind == .human }.count }
    public func validate() throws {
        try validate(allowNoHumans: false)
    }
    fileprivate func validate(allowNoHumans: Bool) throws {
        let minimumHumans = allowNoHumans ? 0 : 1
        guard seats.map(\.seat) == Seat.allCases, (minimumHumans...4).contains(humanCount) else { throw SessionError.invalidSettings }
        if mode == .solo && humanCount != 1 { throw SessionError.invalidSettings }
        if mode == .passAndPlay && humanCount < 2 { throw SessionError.invalidSettings }
        if mode != .online && timeControl != .unlimited { throw SessionError.invalidSettings }
        let ids = seats.compactMap(\.playerID)
        guard ids.count == Set(ids).count else { throw SessionError.invalidSettings }
    }
}

public enum SessionError: String, Error, LocalizedError, Sendable {
    case newerVersion = "This game needs a newer version of Marblezzz. Update the app to continue."
    case invalidSettings = "The table setup is not valid."
    case notYourTurn = "The turn has changed. Refresh the game before playing."
    case staleRevision = "Another device updated this game. Your selection was not submitted."
    case notReady = "Every invited player must accept the table before dealing."
    case notHost = "Only the host can end this game."
    case tooLarge = "This match is larger than Game Center allows. It has not been submitted."
    case noSnapshot = "There is no saved game to resume."
    case unsafeTimeout = "Game Center has not transferred this turn yet. Refresh to continue."
    public var errorDescription: String? { rawValue }
}

public struct MatchEnvelope: Codable, Equatable, Sendable, Identifiable {
    public static let currentVersion = 1
    public var schemaVersion = currentVersion
    public var rulesVersion = 1
    public var id: UUID
    public var settings: MatchSettings
    public var hostPlayerID: String
    public var readyPlayerIDs: Set<String>
    public var resignedPlayerIDs: Set<String>
    public var game: GameState?
    public var revision: Int
    public var settingsRevision: Int = 0
    public var recentEvents: [GameEvent]
    public var operationIDs: [UUID]
    public var deadline: Date?
    public var createdAt: Date
    public var cancelled: Bool

    public init(settings: MatchSettings, hostPlayerID: String, seed: UInt64? = nil, now: Date = Date()) {
        self.id = UUID(); self.settings = settings; self.hostPlayerID = hostPlayerID
        readyPlayerIDs = []; resignedPlayerIDs = []; revision = 0; recentEvents = []; operationIDs = []
        createdAt = now; cancelled = false
        if settings.mode != .online, let seed {
            game = GameState(seed: seed)
            deadline = settings.timeControl.deadline(from: now)
        }
    }
    public var isFinished: Bool { cancelled || game?.result != nil }
    public var currentPlayerID: String? {
        guard let game else { return nil }
        let slot = settings.seats[game.activeSeat.rawValue]
        return slot.kind == .human ? slot.playerID : nil
    }
    public var allReady: Bool {
        let humans = settings.seats.filter { $0.kind == .human }
        return humans.allSatisfy { $0.playerID.map { readyPlayerIDs.contains($0) } ?? false }
    }
    public mutating func markReady(playerID: String, acceptingSettingsRevision: Int? = nil) throws {
        if let acceptingSettingsRevision, acceptingSettingsRevision != settingsRevision { throw SessionError.staleRevision }
        guard game == nil, !cancelled, settings.seats.contains(where: { $0.kind == .human && $0.playerID == playerID }) else { throw SessionError.notReady }
        if readyPlayerIDs.insert(playerID).inserted { revision += 1 }
    }
    public mutating func start(seed: UInt64, now: Date) throws {
        guard game == nil, !cancelled, allReady else { throw SessionError.notReady }
        game = GameState(seed: seed); revision += 1
        deadline = settings.timeControl.deadline(from: now)
        append(GameEvent(id: "start", text: "The table is ready. Five cards each. Let's play."))
    }
    public mutating func swapLobbySeats(_ first: Seat, _ second: Seat, by playerID: String) throws {
        guard playerID == hostPlayerID else { throw SessionError.notHost }
        guard game == nil, !cancelled, first != second,
              settings.seats[first.rawValue].kind == .human, settings.seats[second.rawValue].kind == .human else { throw SessionError.invalidSettings }
        let a = settings.seats[first.rawValue], b = settings.seats[second.rawValue]
        settings.seats[first.rawValue].name = b.name
        settings.seats[first.rawValue].playerID = b.playerID
        settings.seats[first.rawValue].participantIndex = b.participantIndex
        settings.seats[second.rawValue].name = a.name
        settings.seats[second.rawValue].playerID = a.playerID
        settings.seats[second.rawValue].participantIndex = a.participantIndex
        readyPlayerIDs = [hostPlayerID]
        revision += 1; settingsRevision += 1
        append(GameEvent(id: "seats-\(revision)", text: "The host changed seat assignments. Review the table and accept again."))
    }
    public mutating func play(_ action: GameAction, by playerID: String, expectedRevision: Int,
                              operationID: UUID, now: Date) throws {
        if operationIDs.contains(operationID) { return }
        guard expectedRevision == revision else { throw SessionError.staleRevision }
        guard !isFinished, let game, currentPlayerID == playerID else { throw SessionError.notYourTurn }
        let next = try GameRules.apply(action, to: game)
        self.game = next.state
        for event in next.events { append(event) }
        operationIDs.append(operationID); operationIDs = Array(operationIDs.suffix(96))
        revision += 1; deadline = settings.timeControl.deadline(from: now)
    }
    /// Caller must first reload Game Center and prove it currently owns the transport turn.
    /// A timeout is permission for one bot move, never a permanent seat conversion.
    @discardableResult public mutating func runAutomaticTurns(now: Date, authorityPlayerID: String?,
                                                             allowExpiredTurn: Bool = false, limit: Int = 256) throws -> Int {
        var count = 0
        var canSubstitute = allowExpiredTurn
        while let state = game, !isFinished, count < limit {
            let slot = settings.seats[state.activeSeat.rawValue]
            let timedOut = canSubstitute && settings.timeControl != .unlimited && deadline.map { $0 <= now } == true
            guard slot.kind == .computer || timedOut else { break }
            if settings.mode == .online && authorityPlayerID == nil { throw SessionError.unsafeTimeout }
            let view = PlayerObservation(state: state, seat: state.activeSeat)
            guard let action = BotPlayer.choose(in: view, difficulty: settings.difficulty) else { throw RuleError.invalidState }
            if timedOut && slot.kind == .human {
                append(GameEvent(id: "timeout-\(revision)", text: "Time expired: the computer plays one turn for \(slot.name)."))
                canSubstitute = false
            }
            let next = try GameRules.apply(action, to: state)
            game = next.state
            for event in next.events { append(event) }
            count += 1; revision += 1
            deadline = settings.timeControl.deadline(from: now)
        }
        return count
    }
    public mutating func resign(playerID: String) throws {
        guard !isFinished else { return }
        guard let index = settings.seats.firstIndex(where: { $0.playerID == playerID }) else { throw SessionError.notYourTurn }
        guard resignedPlayerIDs.insert(playerID).inserted else { return }
        let seat = settings.seats[index].seat
        append(GameEvent(id: "resign-\(revision)", text: "\(settings.seats[index].name) resigned."))
        if game == nil { cancelled = true }
        else if settings.timeControl == .unlimited { game?.result = .forfeited(winner: 1 - seat.team) }
        else {
            settings.seats[index].kind = .computer
            if settings.humanCount == 0 { cancelled = true; game?.result = .cancelled }
            else if hostPlayerID == playerID {
                var next = seat.next
                while settings.seats[next.rawValue].kind != .human { next = next.next }
                hostPlayerID = settings.seats[next.rawValue].playerID!
            }
        }
        revision += 1
    }
    public mutating func cancel(by playerID: String) throws {
        guard playerID == hostPlayerID else { throw SessionError.notHost }
        guard !isFinished else { return }
        cancelled = true; game?.result = .cancelled; revision += 1
        append(GameEvent(id: "cancel-\(revision)", text: "The host ended this game. No winner was awarded."))
    }
    public mutating func append(_ event: GameEvent) { recentEvents.append(event); recentEvents = Array(recentEvents.suffix(32)) }
    public func validate() throws {
        guard schemaVersion <= Self.currentVersion, rulesVersion <= 1 else { throw SessionError.newerVersion }
        guard schemaVersion == Self.currentVersion, rulesVersion == 1, revision >= 0 else { throw RuleError.invalidState }
        // A completed table can have zero humans after its last resignation.
        // Its four ordered seats and the remaining settings must still be valid.
        try settings.validate(allowNoHumans: isFinished)
        try game?.validate()
    }
}

public enum SnapshotCodec {
    public static func encode(_ envelope: MatchEnvelope, maximumBytes: Int = 1_000_000) throws -> Data {
        try envelope.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        guard data.count <= maximumBytes else { throw SessionError.tooLarge }
        return data
    }
    public static func decode(_ data: Data) throws -> MatchEnvelope {
        // Inspect the version before decoding fields that a future schema might have changed.
        struct Header: Decodable { var schemaVersion: Int; var rulesVersion: Int }
        let header = try JSONDecoder().decode(Header.self, from: data)
        guard header.schemaVersion <= MatchEnvelope.currentVersion, header.rulesVersion <= 1 else { throw SessionError.newerVersion }
        let envelope = try JSONDecoder().decode(MatchEnvelope.self, from: data)
        try envelope.validate(); return envelope
    }
}

public actor SnapshotStore {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    private func location(_ key: String) -> URL {
        let safe = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(safe).appendingPathExtension("json")
    }
    public func save(_ envelope: MatchEnvelope, key: String) throws {
        let data = try SnapshotCodec.encode(envelope)
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = location(key), backup = file.appendingPathExtension("backup")
        if let previous = try? Data(contentsOf: file) {
            do {
                _ = try SnapshotCodec.decode(previous)
                try previous.write(to: backup, options: .atomic)
            } catch SessionError.newerVersion { throw SessionError.newerVersion }
            catch { /* Preserve the existing recovery copy when the primary snapshot is damaged. */ }
        }
        try data.write(to: file, options: .atomic)
        #if os(iOS)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
        if manager.fileExists(atPath: backup.path) { try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: backup.path) }
        #endif
    }
    public func load(key: String) throws -> MatchEnvelope {
        let file = location(key)
        guard FileManager.default.fileExists(atPath: file.path) else { throw SessionError.noSnapshot }
        do { return try SnapshotCodec.decode(Data(contentsOf: file)) }
        catch SessionError.newerVersion { throw SessionError.newerVersion }
        catch {
            guard let backup = try? Data(contentsOf: file.appendingPathExtension("backup")) else { throw error }
            return try SnapshotCodec.decode(backup)
        }
    }
}
