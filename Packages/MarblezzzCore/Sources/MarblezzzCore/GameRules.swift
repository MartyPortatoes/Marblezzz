import Foundation

public enum GameRules {
    public static func legalActions(in state: GameState) -> [GameAction] {
        legalActions(for: PlayerObservation(state: state, seat: state.activeSeat))
    }
    public static func legalActions(for view: PlayerObservation) -> [GameAction] {
        guard !view.isFinished, !view.hand.isEmpty else { return [] }
        var actions: [GameAction] = []
        for card in view.hand {
            for marble in view.marbles where marble.owner == view.controlledSeat {
                var candidates: [GameAction.Kind] = []
                if (card.rank == 1 || card.rank == 13) && marble.position == .reserve {
                    candidates.append(.enter(marble.id))
                }
                if card.rank == 11 && marble.position.isTrack {
                    candidates += view.marbles.filter { $0.id != marble.id && $0.position.isTrack }.map { .swap(marble.id, $0.id) }
                } else if card.rank != 13 && card.rank != 11 && marble.position != .reserve {
                    candidates.append(.move(marble.id, card.rank == 3 ? -3 : card.rank))
                }
                for kind in candidates {
                    let action = GameAction(card: card, kind: kind)
                    if (try? preview(action, for: view)) != nil { actions.append(action) }
                }
            }
        }
        return actions.isEmpty ? [GameAction(kind: .forfeitHand)] : actions
    }

    public static func preview(_ action: GameAction, for view: PlayerObservation) throws -> MovePreview {
        if case .forfeitHand = action.kind {
            return MovePreview(path: [], description: "Reveal and discard your remaining hand")
        }
        guard let id = action.sourceID, let marble = view.marbles.first(where: { $0.id == id }) else { throw RuleError.illegalAction }
        guard marble.owner == view.controlledSeat else { throw RuleError.wrongOwner }
        var path: [Position] = []
        switch action.kind {
        case .enter:
            guard marble.position == .reserve else { throw RuleError.illegalAction }
            path = [.track(marble.owner.entry)]
        case .move(_, let amount):
            guard marble.position != .reserve else { throw RuleError.reserve }
            guard amount != 0 && abs(amount) <= 12 else { throw RuleError.illegalAction }
            if amount < 0 && marble.position.isHome { throw RuleError.backwardHome }
            var position = marble.position
            for _ in 0..<abs(amount) {
                switch position {
                case .track(let index):
                    if amount < 0 { position = .track((index + 47) % 48) }
                    else if index == marble.owner.gate { position = .home(0) }
                    else { position = .track((index + 1) % 48) }
                case .home(let index):
                    guard index < 4 else { throw RuleError.overshoot }
                    position = .home(index + 1)
                case .reserve: throw RuleError.reserve
                }
                path.append(position)
            }
        case .swap(_, let target):
            guard let other = view.marbles.first(where: { $0.id == target }), id != target else { throw RuleError.illegalAction }
            guard marble.position.isTrack && other.position.isTrack else { throw RuleError.protectedMarble }
            return MovePreview(path: [other.position], destination: other.position,
                               description: "Switch \(marble.label.lowercased()) with \(other.label.lowercased())")
        case .forfeitHand: break
        }
        var capture: Int?
        for (index, position) in path.enumerated() {
            let occupant = view.marbles.first {
                $0.id != marble.id && $0.position == position && (position.isTrack || $0.owner == marble.owner)
            }
            if let occupant {
                if occupant.owner.team == marble.owner.team { throw RuleError.friendlyBlock }
                if index == path.count - 1 { capture = occupant.id }
            }
        }
        let destination = path.last!
        let verb = marble.position == .reserve ? "Enter" : "Move"
        var description = "\(verb) \(marble.label.lowercased()) to \(destination.label)"
        if let capture, let victim = view.marbles.first(where: { $0.id == capture }) {
            description += "; capture \(victim.label.lowercased())"
        }
        return MovePreview(path: path, destination: destination, capturedID: capture, description: description)
    }

    public static func explanation(for card: Card, in state: GameState) -> String {
        let view = PlayerObservation(state: state, seat: state.activeSeat)
        if legalActions(for: view).contains(where: { $0.card == card }) { return card.rule }
        if card.rank == 13 {
            return view.marbles.contains(where: { $0.owner == view.controlledSeat && $0.position == .reserve })
                ? "A friendly marble blocks your entry space." : "All your marbles are already in play. Kings only enter marbles."
        }
        if card.rank == 11 { return "A jack needs one of your track marbles and another track marble." }
        let playable = view.marbles.filter { $0.owner == view.controlledSeat && $0.position != .reserve }
        if playable.isEmpty { return "Use an ace or king to enter a marble first." }
        let errors = playable.compactMap { marble -> RuleError? in
            do { _ = try preview(GameAction(card: card, kind: .move(marble.id, card.rank == 3 ? -3 : card.rank)), for: view); return nil }
            catch { return error as? RuleError }
        }
        if let first = errors.first, errors.allSatisfy({ $0 == first }) { return first.rawValue }
        return "Every move is blocked or would overshoot home. Choose another card."
    }

    public static func apply(_ action: GameAction, to original: GameState) throws -> (state: GameState, events: [GameEvent]) {
        guard original.result == nil else { throw RuleError.finished }
        let legal = legalActions(in: original)
        guard legal.contains(action) else {
            if action.kind == .forfeitHand { throw RuleError.mustPlay }
            throw RuleError.illegalAction
        }
        var state = original
        let actor = state.activeSeat
        let preview = try preview(action, for: PlayerObservation(state: state, seat: actor))
        var events: [GameEvent] = []
        func event(_ text: String, cards: [Card] = []) -> GameEvent {
            GameEvent(id: "\(original.turn)-\(events.count)", text: text, cards: cards)
        }
        if action.kind == .forfeitHand {
            let cards = state.hands[actor.rawValue]
            state.discards += cards; state.hands[actor.rawValue] = []
            events.append(event("\(actor.name) has no legal cards and reveals their remaining hand.", cards: cards))
        } else {
            let card = action.card!
            state.hands[actor.rawValue].removeAll { $0 == card }; state.discards.append(card)
            let sourceIndex = state.marbles.firstIndex { $0.id == action.sourceID! }!
            let oldPosition = state.marbles[sourceIndex].position
            if let captured = preview.capturedID, let index = state.marbles.firstIndex(where: { $0.id == captured }) {
                state.marbles[index].position = .reserve
            }
            state.marbles[sourceIndex].position = preview.destination!
            if let target = action.targetID, let index = state.marbles.firstIndex(where: { $0.id == target }) {
                state.marbles[index].position = oldPosition
            }
            events.append(event("\(actor.name) plays \(card.label). \(preview.description).", cards: [card]))
            for seat in Seat.allCases where original.homeCount(seat) < 5 && state.homeCount(seat) == 5 {
                events.append(event("\(seat.name) is all home and now helps \(seat.partner.name)."))
            }
            for team in 0..<2 where state.marbles.filter({ $0.owner.team == team && $0.position.isHome }).count == 10 {
                state.result = .won(team: team)
                events.append(event(team == 0 ? "Red and Green win!" : "Yellow and Blue win!"))
            }
        }
        state.turn += 1
        state.advanceTurn()
        if state.handNumber != original.handNumber {
            events.append(event("Hand \(state.handNumber): \(state.dealIndex == 0 ? 5 : 4) cards each. \(state.dealer.name) deals."))
        }
        return (state, events)
    }
}
