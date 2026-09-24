import SwiftUI
import SpriteKit
import MarblezzzCore

struct BoardCanvas: View {
    let marbles: [Marble]
    let theme: BoardTheme
    var highlighted: Set<Int> = []
    var selectedMarbleID: Int?
    var selectableIDs: Set<Int> = []
    var preview: MovePreview?
    var previewOwner: Seat = .red
    var onTap: ((Int) -> Void)?
    var rendersContinuously = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = MarbleBoardScene(size: CGSize(width: 400,height: 400))
    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency], shouldRender: { _ in
            rendersContinuously || scene.consumeRenderRequest()
        })
            .accessibilityRepresentation {
                VStack {
                    Text("Marble board").accessibilityHint("Select a marble and a card in either order. Board positions are available in Table options.")
                    if let onTap {
                        ForEach(marbles.filter { selectableIDs.contains($0.id) }) { marble in
                            Button("\(marble.label), \(marble.position.label)") { onTap(marble.id) }
                                .accessibilityIdentifier("marble-\(marble.id)")
                                .accessibilityAddTraits(selectedMarbleID == marble.id ? .isSelected : [])
                        }
                    }
                }
            }
            .onAppear(perform: update)
            .onChange(of: marbles) { _, _ in update() }
            .onChange(of: highlighted) { _, _ in update() }
            .onChange(of: selectedMarbleID) { _, _ in update() }
            .onChange(of: preview) { _, _ in update() }
            .onChange(of: theme) { _, _ in update() }
            .onChange(of: reduceMotion) { _, _ in update() }
            .onChange(of: rendersContinuously) { _, _ in update() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { update() }
            }
    }
    private func update() {
        scene.onMarbleTap = onTap
        scene.configure(marbles: marbles, theme: theme, highlighted: highlighted, selectedMarbleID: selectedMarbleID, preview: preview,
                        previewOwner: previewOwner, reduceMotion: reduceMotion || !rendersContinuously)
    }
}

struct GameTableView: View {
    @EnvironmentObject private var model: GameModel
    @EnvironmentObject private var purchases: PurchaseStore
    @EnvironmentObject private var transport: GameCenterTransport
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var cardWidth: CGFloat = 53
    @ScaledMetric(relativeTo: .caption) private var minimumPlayerWidth: CGFloat = 74
    @ScaledMetric(relativeTo: .caption) private var playerIconSize: CGFloat = 11
    @ScaledMetric(relativeTo: .body) private var moveListHeight: CGFloat = 180
    let theme: BoardTheme
    @State private var selectedCard: Card?
    @State private var selectedSource: Int?
    @State private var selectedAction: GameAction?
    @State private var moveListExpanded = false
    @State private var showHistory = false
    @State private var showRules = false
    @State private var showPositions = false
    @State private var confirmExit = false
    @State private var confirmEnd = false
    private var actions: [GameAction] { model.legalActions.filter { $0.card == selectedCard && $0.card != nil } }
    private var preview: MovePreview? {
        guard let action = selectedAction, let game = model.game else { return nil }
        return try? GameRules.preview(action, for: PlayerObservation(state: game, seat: game.activeSeat))
    }
    private var highlighted: Set<Int> {
        if let source = selectedSource, selectedCard?.rank == 11 {
            return Set(actions.filter { $0.sourceID == source }.compactMap(\.targetID)).union([source])
        }
        var sources = Set(actions.compactMap(\.sourceID))
        if let selectedSource { sources.insert(selectedSource) }
        return sources
    }
    private var selectableIDs: Set<Int> {
        guard model.canPlay, let game = model.game else { return [] }
        return Self.selectableMarbleIDs(for: selectedCard, sourceID: selectedSource, in: game,
                                        legalActions: model.legalActions)
    }
    var body: some View {
        Group {
            if let session = model.session, let game = session.game {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 17) {
                                playerRow(session, game, availableWidth: geometry.size.width - 28)
                                if geometry.size.width > geometry.size.height {
                                    HStack(alignment: .top, spacing: 26) {
                                        board(game).frame(width: max(1, min(geometry.size.width * 0.53, geometry.size.height - 80)), height: max(1, min(geometry.size.width * 0.53, geometry.size.height - 80)))
                                        controls(session, game).frame(maxWidth: 400)
                                    }.frame(maxWidth: .infinity)
                                } else {
                                    board(game).frame(width: max(1, min(geometry.size.width - 28, 610)), height: max(1, min(geometry.size.width - 28, 610)))
                                    controls(session, game).frame(maxWidth: 600)
                                }
                            }
                            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 24)
                            .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("table-scroll")
                        if model.canPlay, let selectedCard, !actions.isEmpty {
                            Button {
                                if let selectedAction { Task { await model.commit(selectedAction) } }
                            } label: { Text(confirmLabel(for: selectedCard)) }
                            .buttonStyle(PrimaryButton())
                            .disabled(selectedAction == nil)
                            .opacity(selectedAction == nil ? 0.5 : 1)
                            .accessibilityIdentifier("confirm-move")
                            .frame(maxWidth: 600)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Palette.background)
                        }
                    }
                }
            } else if model.session != nil { lobby }
        }
        .foregroundStyle(Palette.pine)
        .navigationTitle("Marblezzz").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { model.leaveTable() } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Save and leave table")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Recent moves", systemImage: "clock") { showHistory = true }
                    Button("Board positions", systemImage: "list.bullet") { showPositions = true }
                    Button("Rules", systemImage: "book") { showRules = true }
                    if model.onlineMatchID != nil {
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refreshOnline() } }
                        if model.session?.isFinished == false {
                            Button("Resign", systemImage: "flag", role: .destructive) { confirmExit = true }
                            if model.session?.hostPlayerID == transport.playerID {
                                Button("End game for everyone", systemImage: "xmark.circle", role: .destructive) { confirmEnd = true }
                            }
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Table options")
            }
        }
        .sheet(isPresented: $showRules) { TutorialView() }
        .sheet(isPresented: $showHistory) { history }
        .sheet(isPresented: $showPositions) { positions }
        .confirmationDialog("Resign from this game?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("Resign", role: .destructive) { Task { await model.resignOnline() } }
        } message: {
            Text(model.session?.settings.timeControl == .unlimited ? "Your team will forfeit this No Limit game." : "A computer will permanently take your seat. The other players can continue.")
        }
        .confirmationDialog("End this game for everyone?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End game", role: .destructive) { Task { await model.endOnline() } }
        } message: { Text("There will be no winner. If it isn't your turn, cancellation finishes when an authorized player connects.") }
        .onChange(of: model.session?.revision) { _, _ in clearSelection() }
    }
    private func board(_ game: GameState) -> some View {
        BoardCanvas(marbles: game.marbles, theme: theme, highlighted: highlighted, selectedMarbleID: selectedSource,
                    selectableIDs: selectableIDs, preview: preview,
                    previewOwner: game.controlledSeat(for: game.activeSeat), onTap: selectMarble)
            .shadow(color: Palette.pine.opacity(0.12), radius: 8, y: 6)
    }
    private func playerRow(_ session: MatchEnvelope, _ game: GameState, availableWidth: CGFloat) -> some View {
        let columnCount = max(1, min(4, Int((min(availableWidth, 760) + 7) / (minimumPlayerWidth + 7))))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: columnCount), spacing: 7) {
            ForEach(session.settings.seats) { slot in
                let playerDescription = slot.kind == .computer && !slot.name.localizedCaseInsensitiveContains("computer")
                    ? "\(slot.name), computer" : slot.name
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: slot.seat.symbol)
                            .font(.system(size: playerIconSize, weight: .semibold))
                            .foregroundStyle(slot.seat.color)
                        Text(slot.name).font(.caption.weight(.semibold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                    .multilineTextAlignment(.center)
                    Text("with \(slot.seat.partner.name)")
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: 5) {
                        Text("\(game.homeCount(slot.seat))/5").accessibilityLabel("\(game.homeCount(slot.seat)) marbles home")
                        Image(systemName: "rectangle.on.rectangle")
                        Text("\(game.hands[slot.seat.rawValue].count)")
                    }.font(.caption).foregroundStyle(Palette.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 6)
                .background(game.activeSeat == slot.seat ? slot.seat.color.opacity(0.10) : Palette.cream.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(game.activeSeat == slot.seat ? slot.seat.color.opacity(0.8) : .clear, lineWidth: 1.5))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(playerDescription), partners with \(slot.seat.partner.name), \(game.homeCount(slot.seat)) home, \(game.hands[slot.seat.rawValue].count) cards\(game.activeSeat == slot.seat ? ", current turn" : "")")
                .accessibilityIdentifier("player-status-\(slot.seat.rawValue)")
            }
        }.frame(maxWidth: 760)
    }
    @ViewBuilder private func controls(_ session: MatchEnvelope, _ game: GameState) -> some View {
        VStack(spacing: 15) {
            if session.isFinished { result(session, game) }
            else if session.settings.mode != .solo && !purchases.hasFriends {
                Text("Friends access is needed to continue this table.").font(.headline)
                Button("View Friends unlock") { model.showStore = true }.buttonStyle(PrimaryButton())
            } else if session.settings.mode == .passAndPlay && !model.handRevealed && model.viewingSeat != nil {
                Image(systemName: "hand.raised").font(.largeTitle).padding(.top, 10)
                Text("Pass to \(session.settings.seats[game.activeSeat.rawValue].name)").font(.system(.title2, design: .serif))
                Text("Your partner is \(session.settings.seats[game.activeSeat.partner.rawValue].name). Your cards stay private.")
                    .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                Button("I'm ready · reveal my hand") { model.handRevealed = true }.buttonStyle(PrimaryButton()).accessibilityIdentifier("reveal-hand")
            } else { handControls(session, game) }
            Text("HAND \(game.handNumber) · \(game.dealIndex == 0 ? 5 : 4) CARDS DEALT\(session.settings.mode == .online ? " · \(session.settings.timeControl.label)" : "")")
                .font(.caption).tracking(1).foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("hand-summary")
            if let last = session.recentEvents.last {
                Button { showHistory = true } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(last.text).multilineTextAlignment(.leading).lineLimit(3)
                    }.font(.caption).foregroundStyle(Palette.secondary).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
    }
    @ViewBuilder private func handControls(_ session: MatchEnvelope, _ game: GameState) -> some View {
        VStack(spacing: 12) {
            Text(model.canPlay ? "Your move." : "\(session.settings.seats[game.activeSeat.rawValue].name)'s turn")
                .font(.system(.title2, design: .serif)).accessibilityIdentifier("turn-title")
            if game.controlledSeat(for: game.activeSeat) != game.activeSeat {
                Label("Playing for \(game.activeSeat.partner.name)", systemImage: "person.2.fill").font(.caption).foregroundStyle(Palette.secondary)
            }
            if let seat = model.viewingSeat, model.handRevealed {
                let cards = game.hands[seat.rawValue]
                LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: 8)], spacing: 16) {
                    ForEach(cards) { card in
                        let playable = !model.canPlay || model.legalActions.contains {
                            $0.card == card && (selectedSource == nil || $0.sourceID == selectedSource)
                        }
                        Button {
                            selectCard(card)
                        } label: { CardFace(card: card, selected: selectedCard == card, playable: playable) }
                        .buttonStyle(.plain).disabled(!model.canPlay)
                        .accessibilityIdentifier("card-\(card.id)")
                    }
                }
                .frame(maxWidth: CGFloat(cards.count) * cardWidth + CGFloat(max(0, cards.count - 1)) * 8)
                .padding(.top, 9).padding(.bottom, 4)
                if model.canPlay {
                    if model.legalActions == [GameAction(kind: .forfeitHand)] {
                        Text("No cards can be played. Reveal your hand and sit out until the next deal.")
                            .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                        Button("Reveal hand & sit out") { Task { await model.commit(GameAction(kind: .forfeitHand)) } }
                            .buttonStyle(PrimaryButton()).accessibilityIdentifier("forfeit-hand")
                    } else {
                        Text(instruction(game)).font(.subheadline).foregroundStyle(Palette.secondary)
                            .multilineTextAlignment(.center).frame(minHeight: 38)
                        if selectedCard != nil, !actions.isEmpty {
                            Button { moveListExpanded.toggle() } label: {
                                HStack {
                                    Text("Legal moves · \(actions.count)")
                                    Spacer()
                                    Image(systemName: moveListExpanded ? "chevron.up" : "chevron.down")
                                }.font(.subheadline).padding(.vertical, 12).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("legal-moves")
                                .accessibilityValue(moveListExpanded ? "Expanded" : "Collapsed")
                            if moveListExpanded {
                                ScrollView {
                                    VStack(spacing: 3) {
                                        ForEach(actions) { action in
                                            Button { selectedAction = action; selectedSource = action.sourceID } label: {
                                                HStack(alignment: .top) {
                                                    Text(actionDescription(action, game))
                                                    Spacer(minLength: 4)
                                                    if selectedAction == action { Image(systemName: "checkmark.circle.fill") }
                                                    }.font(.subheadline).multilineTextAlignment(.leading).padding(.vertical, 12).padding(.horizontal, 8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .contentShape(Rectangle())
                                            }.buttonStyle(.plain).accessibilityIdentifier("move-\(action.id)")
                                                .accessibilityAddTraits(selectedAction == action ? .isSelected : [])
                                        }
                                    }
                                }.frame(height: moveListHeight).accessibilityIdentifier("legal-move-list")
                            }
                        }
                    }
                } else if game.hands[seat.rawValue].isEmpty {
                    Text("Your hand is finished. You'll join the next deal.").font(.subheadline).foregroundStyle(Palette.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(0..<game.hands[game.activeSeat.rawValue].count, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 10).fill(theme.cardBack).frame(width: 45,height: 65)
                            .overlay(Image(systemName: "sparkle").foregroundStyle(.white.opacity(0.4)))
                    }
                }.accessibilityLabel("Computer hand hidden")
            }
            if model.busy { ProgressView("Updating the table…").font(.caption) }
            if session.settings.mode == .online, let deadline = session.deadline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if context.date < deadline {
                        HStack(spacing: 5) { Image(systemName: "hourglass"); Text(deadline, style: .relative) }.font(.caption).foregroundStyle(Palette.secondary)
                    } else {
                        Text("Turn expired · waiting for Game Center").font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
        }
    }
    private func instruction(_ game: GameState) -> String {
        if let preview { return preview.description }
        if let selectedCard {
            if actions.isEmpty { return GameRules.explanation(for: selectedCard, in: game) }
            if let selectedSource, !actions.contains(where: { $0.sourceID == selectedSource }) {
                return "That card cannot move the selected marble. Choose another card or marble."
            }
            if selectedCard.rank == 11 { return selectedSource == nil ? "Choose one of your track marbles." : "Choose the other marble to switch with." }
            return "Choose a highlighted marble, then confirm your move."
        }
        if let selectedSource {
            return model.legalActions.contains(where: { $0.sourceID == selectedSource })
                ? "Choose a card for the selected marble."
                : "No card can move this marble right now. Choose another marble."
        }
        return "Choose a card or marble to start your move."
    }
    private func confirmLabel(for card: Card) -> String {
        if selectedAction != nil { return "Play \(card.label)" }
        if let selectedSource, !actions.contains(where: { $0.sourceID == selectedSource }) {
            return "Choose another card or marble"
        }
        return card.rank == 11 && selectedSource != nil ? "Choose a marble to switch with" : "Choose a marble"
    }
    private func actionDescription(_ action: GameAction, _ game: GameState) -> String {
        (try? GameRules.preview(action, for: PlayerObservation(state: game, seat: game.activeSeat)).description) ?? "Move"
    }
    private func selectCard(_ card: Card) {
        let source = selectedSource
        selectedCard = card
        selectedAction = nil
        moveListExpanded = false
        if let source {
            selectedAction = Self.action(for: card, sourceID: source, legalActions: model.legalActions)
            return
        }
        if let selection = Self.impliedSelection(for: card, legalActions: model.legalActions) {
            selectedSource = selection.sourceID
            selectedAction = selection.action
        }
    }
    static func action(for card: Card, sourceID: Int, legalActions: [GameAction]) -> GameAction? {
        guard card.rank != 11 else { return nil }
        return legalActions.first { $0.card == card && $0.sourceID == sourceID }
    }
    private static func controllableMarbleIDs(in game: GameState) -> Set<Int> {
        let controlledSeat = game.controlledSeat(for: game.activeSeat)
        return Set(game.marbles.filter { $0.owner == controlledSeat && $0.position != .home(4) }.map(\.id))
    }
    static func selectableMarbleIDs(for card: Card?, sourceID: Int?, in game: GameState,
                                    legalActions: [GameAction]) -> Set<Int> {
        let sources = controllableMarbleIDs(in: game)
        guard let card, card.rank == 11, let sourceID else { return sources }
        let targets = legalActions.filter { $0.card == card && $0.sourceID == sourceID }.compactMap(\.targetID)
        return sources.union(targets)
    }
    static func selection(afterTapping id: Int, card: Card?, sourceID: Int?, in game: GameState,
                          legalActions: [GameAction])
        -> (card: Card?, sourceID: Int, action: GameAction?)? {
        if let card, card.rank == 11, let sourceID,
           let swap = legalActions.first(where: { $0.card == card && $0.sourceID == sourceID && $0.targetID == id }) {
            return (card, sourceID, swap)
        }
        guard controllableMarbleIDs(in: game).contains(id) else { return nil }
        guard let card else { return (nil, id, nil) }
        if card.rank == 11 {
            let canSwap = legalActions.contains { $0.card == card && $0.sourceID == id }
            return (canSwap ? card : nil, id, nil)
        }
        if let action = action(for: card, sourceID: id, legalActions: legalActions) {
            return (card, id, action)
        }
        return (nil, id, nil)
    }
    static func impliedSelection(for card: Card, legalActions: [GameAction]) -> (sourceID: Int, action: GameAction?)? {
        guard card.rank != 1, card.rank != 13 else { return nil }
        let choices = legalActions.filter { $0.card == card && $0.sourceID != nil }
        guard let sourceID = choices.first?.sourceID,
              choices.allSatisfy({ $0.sourceID == sourceID }) else { return nil }
        let action = card.rank == 11 || choices.count != 1 ? nil : choices[0]
        return (sourceID, action)
    }
    private func selectMarble(_ id: Int) {
        guard model.canPlay, let game = model.game,
              let selection = Self.selection(afterTapping: id, card: selectedCard, sourceID: selectedSource,
                                             in: game, legalActions: model.legalActions) else { return }
        selectedCard = selection.card
        selectedSource = selection.sourceID
        selectedAction = selection.action
        moveListExpanded = false
    }
    private func clearSelection() { selectedCard = nil; selectedSource = nil; selectedAction = nil; moveListExpanded = false }
    private func result(_ session: MatchEnvelope, _ game: GameState) -> some View {
        VStack(spacing: 15) {
            Image(systemName: session.cancelled ? "flag.slash" : "trophy").font(.system(size: 34)).foregroundStyle(Palette.gold)
            Text(resultTitle(game, session)).font(.system(.title, design: .serif)).multilineTextAlignment(.center)
            Text(session.cancelled ? "This table was ended without a winner." : "A little luck. A lot of teamwork.")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            if session.settings.mode != .online {
                Button("Another round") { Task { await model.startLocal(session.settings) } }.buttonStyle(PrimaryButton())
            }
            Button("Back to the club") { model.leaveTable() }.font(.headline)
        }.padding(.vertical, 10)
    }
    private func resultTitle(_ game: GameState, _ session: MatchEnvelope) -> String {
        if session.cancelled { return "Until next time." }
        guard let team = game.result?.winningTeam else { return "Game finished" }
        return session.settings.seats.filter { $0.seat.team == team }.map(\.name).joined(separator: " & ") + " win!"
    }
    private var lobby: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "person.2.circle").font(.system(size: 60)).foregroundStyle(Palette.gold)
                Text(model.session?.cancelled == true ? "This table has ended." : "Pull up a chair.").font(.system(.largeTitle, design: .serif))
                Text("Everyone reviews the table before the first deal. Opposite colors are partners.")
                    .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                if let session = model.session {
                    ForEach(session.settings.seats) { slot in
                        HStack {
                            Image(systemName: slot.seat.symbol).foregroundStyle(slot.seat.color)
                            Text(slot.name); Spacer()
                            Text(slot.kind == .computer ? "Computer" : session.readyPlayerIDs.contains(slot.playerID ?? "") ? "Ready" : "Invited")
                                .font(.caption).foregroundStyle(Palette.secondary)
                        }.padding().background(Palette.cream, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Text("\(session.settings.timeControl.label) · \(session.settings.difficulty.rawValue.capitalized) computers").font(.subheadline)
                    if session.hostPlayerID == transport.playerID && !session.isFinished {
                        Menu("Change seat assignments") {
                            ForEach(session.settings.seats.filter { $0.kind == .human }) { first in
                                ForEach(session.settings.seats.filter { $0.kind == .human && $0.seat.rawValue > first.seat.rawValue }) { second in
                                    Button("Switch \(first.name) (\(first.seat.name)) and \(second.name) (\(second.seat.name))") {
                                        Task { await model.swapOnlineSeats(first.seat, second.seat) }
                                    }
                                }
                            }
                        }.disabled(model.busy)
                    }
                    if !session.isFinished && !session.readyPlayerIDs.contains(transport.playerID ?? "") {
                        Button("Accept table & get ready") { Task { await model.readyOnline() } }.buttonStyle(PrimaryButton()).disabled(model.busy)
                    }
                    Button("Refresh table") { Task { await model.refreshOnline() } }.padding()
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
    }
    private var history: some View {
        NavigationStack {
            List((model.session?.recentEvents ?? []).reversed()) { event in
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.text).font(.subheadline)
                    if !event.cards.isEmpty { Text(event.cards.map(\.label).joined(separator: "   ")).font(.system(.title3, design: .serif)) }
                }.padding(.vertical, 5)
            }.navigationTitle("Around the table").toolbar { Button("Done") { showHistory = false } }
        }
    }

    private var positions: some View {
        NavigationStack {
            List {
                if let game = model.game {
                    ForEach(Seat.allCases) { seat in
                        Section("\(seat.name) · partners with \(seat.partner.name)") {
                            ForEach(game.marbles.filter { $0.owner == seat }) { marble in
                                Text("\(marble.label): \(marble.position.label)")
                            }
                        }
                    }
                }
            }.navigationTitle("Board positions")
                .toolbar { Button("Done") { showPositions = false } }
        }
    }
}
