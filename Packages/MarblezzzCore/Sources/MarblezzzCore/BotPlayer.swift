import Foundation

public enum BotDifficulty: String, Codable, CaseIterable, Sendable { case easy, standard }

public enum BotPlayer {
    /// Intentionally accepts no full GameState, stock, opponent hands, or shuffle seed.
    public static func choose(in view: PlayerObservation, difficulty: BotDifficulty = .standard) -> GameAction? {
        let actions = GameRules.legalActions(for: view)
        guard !actions.isEmpty else { return nil }
        var random = SeededRandom(seed: UInt64(view.turn) &* 7919 &+ UInt64(view.seat.rawValue + 1))
        if difficulty == .easy {
            // Easy notices immediate progress but does not evaluate exposure or future blocking.
            let useful = actions.filter { action in
                guard let preview = try? GameRules.preview(action, for: view) else { return false }
                if case .enter = action.kind { return true }
                return preview.destination?.isHome == true || preview.capturedID != nil
            }
            let choices = useful.isEmpty ? actions : useful
            return choices[Int(random.next() % UInt64(choices.count))]
        }
        return actions.enumerated().max { lhs, rhs in
            let a = score(lhs.element, view), b = score(rhs.element, view)
            return a == b ? lhs.offset > rhs.offset : a < b
        }?.element
    }
    private static func progress(_ position: Position, owner: Seat) -> Double {
        switch position {
        case .reserve: -12
        case .track(let index): Double((index - owner.entry + 48) % 48)
        case .home(let index): 70 + Double(index) * 5
        }
    }
    private static func score(_ action: GameAction, _ view: PlayerObservation) -> Double {
        guard let sourceID = action.sourceID,
              let marble = view.marbles.first(where: { $0.id == sourceID }),
              let preview = try? GameRules.preview(action, for: view), let destination = preview.destination else { return -1000 }
        var value = progress(destination, owner: marble.owner) - progress(marble.position, owner: marble.owner)
        if marble.position == .reserve { value += 18 }
        if destination.isHome { value += 30 }
        if preview.capturedID != nil { value += 24 }
        if let otherID = action.targetID, let other = view.marbles.first(where: { $0.id == otherID }) {
            let delta = progress(marble.position, owner: other.owner) - progress(other.position, owner: other.owner)
            value += delta * (other.owner.team == marble.owner.team ? 0.9 : -0.6)
        }
        if case .track(let index) = destination {
            for other in view.marbles where other.id != sourceID {
                guard case .track(let otherIndex) = other.position else { continue }
                let distance = (index - otherIndex + 48) % 48
                if other.owner.team != marble.owner.team && (1...12).contains(distance) { value -= 2.0 }
                if other.owner.team == marble.owner.team && (1...6).contains(distance) { value -= 5.0 }
            }
        }
        return value
    }
}
