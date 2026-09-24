import Foundation

public enum Seat: Int, CaseIterable, Codable, Sendable, Identifiable {
    case red, yellow, green, blue
    public var id: Int { rawValue }
    public var name: String { ["Red", "Yellow", "Green", "Blue"][rawValue] }
    public var symbol: String { ["diamond.fill", "sparkle", "suit.club.fill", "triangle.fill"][rawValue] }
    public var partner: Seat { Seat(rawValue: (rawValue + 2) % 4)! }
    public var next: Seat { Seat(rawValue: (rawValue + 1) % 4)! }
    public var team: Int { rawValue % 2 }
    public var entry: Int { rawValue * 12 }
    public var gate: Int { (entry + 47) % 48 }
}

public struct Card: Codable, Hashable, Sendable, Identifiable {
    public enum Suit: Int, CaseIterable, Codable, Sendable {
        case clubs, diamonds, hearts, spades
        public var symbol: String { ["♣", "♦", "♥", "♠"][rawValue] }
        public var isRed: Bool { self == .diamonds || self == .hearts }
    }
    public let rank: Int
    public let suit: Suit
    public init(_ rank: Int, _ suit: Suit = .clubs) { self.rank = rank; self.suit = suit }
    public var id: Int { suit.rawValue * 13 + rank - 1 }
    public var label: String {
        let face = [1: "A", 11: "J", 12: "Q", 13: "K"][rank] ?? String(rank)
        return face + suit.symbol
    }
    public var rankLabel: String { [1: "A", 11: "J", 12: "Q", 13: "K"][rank] ?? String(rank) }
    public var rule: String {
        switch rank {
        case 1: "Enter or move 1"
        case 3: "Back 3"
        case 11: "Switch two marbles"
        case 12: "Move 12"
        case 13: "Enter a marble"
        default: "Move \(rank)"
        }
    }
    public static var deck: [Card] { Suit.allCases.flatMap { suit in (1...13).map { Card($0, suit) } } }
}

public enum Position: Codable, Hashable, Sendable {
    case reserve
    case track(Int)
    case home(Int)
    public var isHome: Bool { if case .home = self { true } else { false } }
    public var isTrack: Bool { if case .track = self { true } else { false } }
    public var label: String {
        switch self {
        case .reserve: "starting area"
        case .track(let index): "track space \(index + 1)"
        case .home(let index): "home space \(index + 1)"
        }
    }
}

public struct Marble: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let owner: Seat
    public var position: Position
    public init(id: Int, owner: Seat, position: Position = .reserve) {
        self.id = id; self.owner = owner; self.position = position
    }
    public var label: String { "\(owner.name) marble \(id % 5 + 1)" }
    public static var initial: [Marble] {
        Seat.allCases.flatMap { seat in (0..<5).map { Marble(id: seat.rawValue * 5 + $0, owner: seat) } }
    }
}

public enum GameResult: Codable, Equatable, Sendable {
    case won(team: Int)
    case forfeited(winner: Int)
    case cancelled
    public var winningTeam: Int? {
        switch self { case .won(let team), .forfeited(let team): team; case .cancelled: nil }
    }
}

/// Persisted, explicit randomness makes a committed action replayable, including a new shuffle.
public struct SeededRandom: RandomNumberGenerator, Codable, Equatable, Sendable {
    public var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    public mutating func shuffle<T>(_ values: [T]) -> [T] {
        var result = values
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            // Rejection sampling avoids modulo bias and does not depend on Swift's shuffle implementation.
            let bound = UInt64(index + 1)
            let threshold = (0 &- bound) % bound
            var value = next()
            while value < threshold { value = next() }
            result.swapAt(index, Int(value % bound))
        }
        return result
    }
}

public struct GameState: Codable, Equatable, Sendable {
    public var marbles: [Marble]
    public var hands: [[Card]]
    public var stock: [Card]
    public var discards: [Card]
    public var dealer: Seat
    public var dealIndex: Int
    public var handNumber: Int
    public var activeSeat: Seat
    public var turn: Int
    public var random: SeededRandom
    public var result: GameResult?

    public init(seed: UInt64, dealer: Seat? = nil) {
        var random = SeededRandom(seed: seed)
        self.dealer = dealer ?? Seat(rawValue: Int(random.next() % 4))!
        self.activeSeat = self.dealer.next
        self.marbles = Marble.initial
        self.hands = Array(repeating: [], count: 4)
        self.stock = random.shuffle(Card.deck)
        self.discards = []
        self.dealIndex = 0; self.handNumber = 0; self.turn = 0
        self.random = random; self.result = nil
        deal()
    }
    public func controlledSeat(for seat: Seat) -> Seat {
        marbles.filter { $0.owner == seat && $0.position.isHome }.count == 5 ? seat.partner : seat
    }
    public func homeCount(_ seat: Seat) -> Int { marbles.filter { $0.owner == seat && $0.position.isHome }.count }
    mutating func deal() {
        handNumber += 1
        for _ in 0..<(dealIndex == 0 ? 5 : 4) {
            var seat = dealer.next
            for _ in 0..<4 { hands[seat.rawValue].append(stock.removeLast()); seat = seat.next }
        }
        activeSeat = dealer.next
    }
    mutating func advanceTurn() {
        guard result == nil else { return }
        if hands.allSatisfy(\.isEmpty) {
            dealIndex += 1
            if dealIndex == 3 {
                dealIndex = 0; dealer = dealer.next
                stock = random.shuffle(discards); discards = []
            }
            deal()
        } else {
            repeat { activeSeat = activeSeat.next } while hands[activeSeat.rawValue].isEmpty
        }
    }
    public func validate() throws {
        guard marbles.count == 20, Set(marbles.map(\.id)) == Set(0..<20),
              marbles.allSatisfy({ $0.id / 5 == $0.owner.rawValue }),
              hands.count == 4, (0...2).contains(dealIndex), handNumber > 0, turn >= 0 else {
            throw RuleError.invalidState
        }
        // The stock is unchanged within a hand; only the next 5-4-4 deal consumes it.
        let cardsDealt = dealIndex == 0 ? 5 : 4
        guard stock.count == (2 - dealIndex) * 16,
              hands.allSatisfy({ $0.count <= cardsDealt }) else { throw RuleError.invalidState }
        let cards = hands.flatMap { $0 } + stock + discards
        guard cards.count == 52, Set(cards) == Set(Card.deck) else { throw RuleError.invalidState }
        var occupied = Set<String>()
        for marble in marbles {
            let key: String
            switch marble.position {
            case .reserve: continue
            case .track(let index):
                guard (0..<48).contains(index) else { throw RuleError.invalidState }
                key = "t\(index)"
            case .home(let index):
                guard (0..<5).contains(index) else { throw RuleError.invalidState }
                key = "h\(marble.owner.rawValue)-\(index)"
            }
            guard occupied.insert(key).inserted else { throw RuleError.invalidState }
        }
        if result == nil && hands[activeSeat.rawValue].isEmpty { throw RuleError.invalidState }
    }
}

public struct PlayerObservation: Equatable, Sendable {
    public let seat: Seat
    public let controlledSeat: Seat
    public let marbles: [Marble]
    public let hand: [Card]
    public let publicDiscards: [Card]
    public let cardCounts: [Int]
    public let turn: Int
    public let isFinished: Bool
    public init(state: GameState, seat: Seat) {
        self.seat = seat; controlledSeat = state.controlledSeat(for: seat)
        marbles = state.marbles; hand = state.hands[seat.rawValue]
        publicDiscards = state.discards; cardCounts = state.hands.map(\.count)
        turn = state.turn; isFinished = state.result != nil
    }
}

public struct GameAction: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: Codable, Hashable, Sendable {
        case enter(Int)
        case move(Int, Int)
        case swap(Int, Int)
        case forfeitHand
    }
    public let card: Card?
    public let kind: Kind
    public init(card: Card? = nil, kind: Kind) { self.card = card; self.kind = kind }
    public var sourceID: Int? {
        switch kind { case .enter(let id), .move(let id, _), .swap(let id, _): id; case .forfeitHand: nil }
    }
    public var targetID: Int? { if case .swap(_, let id) = kind { id } else { nil } }
    public var id: String { "\(card?.id ?? -1):\(kind)" }
}

public struct GameEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var cards: [Card]
    public init(id: String, text: String, cards: [Card] = []) { self.id = id; self.text = text; self.cards = cards }
}

public struct MovePreview: Equatable, Sendable {
    public var path: [Position]
    public var destination: Position?
    public var capturedID: Int?
    public var description: String
}

public enum RuleError: String, Error, LocalizedError, Codable, Sendable {
    case invalidState = "This saved game is damaged and cannot be changed."
    case illegalAction = "Choose one of the legal moves for your hand."
    case mustPlay = "You have a playable card. A legal card must be played."
    case friendlyBlock = "Your own marble or your partner blocks this path."
    case overshoot = "This card would overshoot home."
    case protectedMarble = "Marbles in their starting area or home cannot switch."
    case backwardHome = "A marble inside home cannot move backward."
    case reserve = "Use an ace or king to enter this marble."
    case wrongOwner = "Finish your own marbles before moving your partner's."
    case finished = "This game has finished."
    public var errorDescription: String? { rawValue }
}
