import SwiftUI
import MarblezzzCore

private enum RootSheet: String, Identifiable {
    case tutorial, settings, passSetup, online, onlineSetup
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var model: GameModel
    @EnvironmentObject private var purchases: PurchaseStore
    @EnvironmentObject private var transport: GameCenterTransport
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("boardTheme") private var themeName = BoardTheme.original.rawValue
    @AppStorage("botDifficulty") private var difficultyName = BotDifficulty.standard.rawValue
    @AppStorage("soundEnabled") private var sound = false
    @AppStorage("hapticsEnabled") private var haptics = true
    @State private var sheet: RootSheet?
    @State private var replacementMode: PlayMode?
    @State private var showReplacementConfirmation = false
    @State private var replacingPassSave = false
    private var theme: BoardTheme {
        let selected = BoardTheme(rawValue: themeName) ?? .original
        return purchases.owns(selected.productID) ? selected : .original
    }
    var body: some View {
        NavigationStack {
            Group {
                if model.session != nil {
                    GameTableView(theme: theme)
                } else {
                    HomeView(theme: theme, onSolo: openSolo, onPass: openPassAndPlay,
                             onOnline: { if purchases.hasFriends { sheet = .online } else { model.showStore = true } },
                             onLearn: { sheet = .tutorial }, onSettings: { sheet = .settings },
                             onNewSolo: { requestReplacement(.solo) },
                             onNewPass: { requestReplacement(.passAndPlay) })
                        .alert("Replace your saved game?", isPresented: $showReplacementConfirmation,
                               presenting: replacementMode) { mode in
                            Button("Replace saved game", role: .destructive) { replaceSavedGame(mode) }
                            Button("Keep saved game", role: .cancel) { replacementMode = nil }
                        } message: { mode in
                            Text(mode == .solo ? "Starting a new solo game replaces your unfinished solo game."
                                 : "Dealing a new table replaces your unfinished pass-and-play game.")
                        }
                }
            }
            .background(Palette.background.ignoresSafeArea())
        }
        .overlay {
            if scenePhase != .active {
                Palette.background.ignoresSafeArea().overlay {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.fill").font(.largeTitle)
                        Text("Your cards are tucked away.").font(.headline)
                        Text("Marblezzz").font(.system(.title, design: .serif))
                    }.foregroundStyle(Palette.pine)
                }.accessibilityElement(children: .combine)
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .tutorial: TutorialView()
            case .settings: SettingsView()
            case .passSetup:
                TableSetupView(mode: .passAndPlay) { settings, _ in
                    let replace = replacingPassSave
                    sheet = nil; replacingPassSave = false
                    Task { await model.startLocal(settings, replacingSavedGame: replace) }
                }
            case .online:
                OnlineTablesView(onCreate: { sheet = .onlineSetup }, onOpen: { id in
                    sheet = nil; Task { await model.openOnline(id) }
                })
            case .onlineSetup:
                TableSetupView(mode: .online) { settings, host in
                    sheet = nil
                    Task { try? await Task.sleep(for: .milliseconds(400)); model.beginOnline(settings, hostSeat: host) }
                }
            }
        }
        .sheet(isPresented: $model.showStore) { StorefrontView() }
        .sheet(isPresented: $model.showMatchmaker) {
            GameCenterMatchmaker(humanCount: transport.pendingSettings?.humanCount ?? 4,
                                onDismiss: { model.showMatchmaker = false; transport.pendingSettings = nil },
                                onError: { model.error = $0 }).ignoresSafeArea()
        }
        .sheet(isPresented: Binding(get: { sheet == nil && transport.authenticationController != nil }, set: { if !$0 { transport.authenticationController = nil } })) {
            if let controller = transport.authenticationController { HostedController(controller: controller).ignoresSafeArea() }
        }
        .alert("A note from the table", isPresented: Binding(get: { model.error != nil || model.notice != nil || transport.errorMessage != nil }, set: {
            if !$0 { model.error = nil; model.notice = nil; transport.errorMessage = nil }
        })) {
            Button("OK", role: .cancel) { model.error = nil; model.notice = nil; transport.errorMessage = nil }
        } message: { Text(model.error ?? model.notice ?? transport.errorMessage ?? "") }
        .onAppear { model.reduceMotion = reduceMotion; model.soundEnabled = sound; model.hapticsEnabled = haptics }
        .onChange(of: reduceMotion) { _, value in model.reduceMotion = value }
        .onChange(of: sound) { _, value in model.soundEnabled = value }
        .onChange(of: haptics) { _, value in model.hapticsEnabled = value }
        .onChange(of: scenePhase) { _, phase in
            model.setActive(phase == .active)
            if phase == .active { Task { await purchases.refreshEntitlements(); await model.refreshOnline() } }
        }
    }
    private func openSolo() {
        Task {
            if model.availableSaves.contains(.solo) { await model.resume(.solo) }
            else { await model.startLocal(soloSettings) }
        }
    }
    private var soloSettings: MatchSettings {
        MatchSettings(difficulty: BotDifficulty(rawValue: difficultyName) ?? .standard)
    }
    private func openPassAndPlay() {
        guard purchases.hasFriends else { model.showStore = true; return }
        if model.availableSaves.contains(.passAndPlay) { Task { await model.resume(.passAndPlay) } }
        else { replacingPassSave = false; sheet = .passSetup }
    }
    private func requestReplacement(_ mode: PlayMode) {
        guard mode == .solo || purchases.hasFriends else { model.showStore = true; return }
        replacementMode = mode; showReplacementConfirmation = true
    }
    private func replaceSavedGame(_ mode: PlayMode) {
        replacementMode = nil
        if mode == .solo { Task { await model.startLocal(soloSettings, replacingSavedGame: true) } }
        else { replacingPassSave = true; sheet = .passSetup }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: GameModel
    @EnvironmentObject private var purchases: PurchaseStore
    let theme: BoardTheme
    let onSolo: () -> Void
    let onPass: () -> Void
    let onOnline: () -> Void
    let onLearn: () -> Void
    let onSettings: () -> Void
    let onNewSolo: () -> Void
    let onNewPass: () -> Void
    private var displayMarbles: [Marble] {
        var marbles = Marble.initial
        marbles[0].position = .track(3); marbles[1].position = .home(4)
        marbles[5].position = .track(17); marbles[6].position = .home(4)
        marbles[10].position = .track(30); marbles[11].position = .home(4)
        marbles[15].position = .track(42); marbles[16].position = .home(4)
        return marbles
    }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 23) {
                    VStack(spacing: 8) {
                        HStack(spacing: 7) {
                            ForEach(Seat.allCases) { seat in Circle().fill(seat.color.gradient).frame(width: 9,height: 9) }
                        }
                        Text("Marblezzz").font(.system(size: geometry.size.width < 390 ? 48 : 56, weight: .regular, design: .serif)).tracking(-2)
                        Text("A LITTLE LUCK. A LOT OF TEAMWORK.").font(.system(size: 10, weight: .semibold)).tracking(2)
                            .foregroundStyle(Palette.secondary)
                    }.padding(.top, 10)
                    BoardCanvas(marbles: displayMarbles, theme: theme, rendersContinuously: false)
                        .frame(width: max(1, min(geometry.size.width - 52, 355)), height: max(1, min(geometry.size.width - 52, 355)))
                        .rotationEffect(.degrees(-3)).shadow(color: Palette.pine.opacity(0.17), radius: 14, y: 12)
                        .allowsHitTesting(false).accessibilityHidden(true)
                    VStack(spacing: 12) {
                        Button(action: onSolo) {
                            HStack {
                                Image(systemName: "sparkles").font(.title3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(model.availableSaves.contains(.solo) ? "Resume solo" : "Play solo").font(.headline)
                                    Text(model.availableSaves.contains(.solo) ? "Pick up where you left off" : "You, a partner, and a little friendly rivalry")
                                        .font(.caption).fontWeight(.regular).opacity(0.78)
                                }
                                Spacer(); Image(systemName: "arrow.right")
                            }.padding(.horizontal, 18)
                        }.buttonStyle(PrimaryButton())
                            .accessibilityIdentifier(model.availableSaves.contains(.solo) ? "resume-solo" : "play-solo")
                        HStack(spacing: 12) {
                            modeButton(model.availableSaves.contains(.passAndPlay) ? "Resume table" : "Pass & play",
                                       detail: "Around one screen", icon: "iphone.gen3.radiowaves.left.and.right", identifier: "pass-and-play", action: onPass)
                            modeButton("Play online", detail: "Together, anywhere", icon: "globe.americas", identifier: "play-online", action: onOnline)
                        }
                        if !model.availableSaves.isEmpty {
                            VStack(spacing: 4) {
                                if model.availableSaves.contains(.solo) {
                                    Button("New solo game", systemImage: "plus", action: onNewSolo)
                                        .frame(minHeight: 44).accessibilityIdentifier("new-solo")
                                }
                                if model.availableSaves.contains(.passAndPlay) {
                                    Button("New shared table", systemImage: "plus", action: onNewPass)
                                        .frame(minHeight: 44).accessibilityIdentifier("new-pass-and-play")
                                }
                            }.font(.subheadline)
                        }
                    }.frame(maxWidth: 460)
                    Button(action: onLearn) { Label("New to the table? Learn to play", systemImage: "book.closed").font(.subheadline) }
                        .accessibilityIdentifier("learn-to-play")
                    Text("FOUR COLORS · TWO TEAMS · ONE WAY HOME").font(.system(size: 9, weight: .medium)).tracking(1.7)
                        .foregroundStyle(Palette.secondary).padding(.bottom, 20)
                }.padding(.horizontal, 24).frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Palette.pine)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button(action: onSettings) { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Settings") }
            ToolbarItem(placement: .topBarTrailing) { Button { model.showStore = true } label: { Image(systemName: "bag") }.accessibilityLabel("Table shop") }
        }
    }
    private func modeButton(_ title: String, detail: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack { Image(systemName: icon).font(.title3); Spacer(); if !purchases.hasFriends { Image(systemName: "lock").font(.caption2) } }
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(Palette.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.pine.opacity(0.09)))
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
}
