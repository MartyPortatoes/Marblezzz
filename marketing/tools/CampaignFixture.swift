// Compile alongside Packages/MarblezzzCore/Sources/MarblezzzCore/*.swift.
// Creates only rule-engine-replayed local game states; never edits marble positions.
import Foundation

@main struct CampaignFixture {
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var best: (score: Int, seed: UInt64, envelope: MatchEnvelope, action: GameAction)?
        for seed in UInt64(1)...12 {
            var match = MatchEnvelope(settings: MatchSettings(mode: .solo), hostPlayerID: "local-0", seed: seed)
            for _ in 0..<220 {
                guard let state = match.game, state.result == nil else { break }
                let actions = GameRules.legalActions(in: state)
                let candidates = actions.filter { if case .move(_, let steps) = $0.kind { return steps > 2 && steps < 11 }; return false }
                if state.activeSeat == .red, state.hands[0].count >= 4, let action = candidates.first {
                    let track = state.marbles.filter { $0.position.isTrack }.count
                    let home = state.marbles.filter { $0.position.isHome }.count
                    let owners = Set(state.marbles.filter { $0.position.isTrack }.map(\.owner)).count
                    let score = track * 8 + min(home, 6) * 3 + owners * 15 + state.hands[0].count * 2
                    if best == nil || score > best!.score { best = (score, seed, match, action) }
                }
                let observation = PlayerObservation(state: state, seat: state.activeSeat)
                guard let action = BotPlayer.choose(in: observation, difficulty: .standard) else { break }
                let next = try GameRules.apply(action, to: state)
                match.game = next.state
                match.revision += 1
                for event in next.events { match.append(event) }
                try match.validate()
            }
        }
        guard let best, let game = best.envelope.game else { fatalError("No suitable legal game state") }
        let solo = try SnapshotCodec.encode(best.envelope)
        try solo.write(to: output.appendingPathComponent("c29sbw==.json"))
        var pass = best.envelope
        pass.settings = MatchSettings(mode: .passAndPlay, humanSeats: Set(Seat.allCases))
        for (i, name) in ["Alex", "Sam", "Jordan", "Casey"].enumerated() { pass.settings.seats[i].name = name }
        try SnapshotCodec.encode(pass).write(to: output.appendingPathComponent("cGFzc0FuZFBsYXk=.json"))
        let preview = try GameRules.preview(best.action, for: PlayerObservation(state: game, seat: .red))
        let metadata = "Seed: \(best.seed)\nLegally replayed turns: \(game.turn)\nTrack: \(game.marbles.filter { $0.position.isTrack }.count)\nHome: \(game.marbles.filter { $0.position.isHome }.count)\nCard identifier: card-\(best.action.card!.id)\nAction identifier: move-\(best.action.id)\nPreview: \(preview.description)\n"
        try metadata.write(to: output.appendingPathComponent("fixture.txt"), atomically: true, encoding: .utf8)
        print(metadata)
    }
}
