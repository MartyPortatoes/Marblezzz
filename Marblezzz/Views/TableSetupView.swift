import SwiftUI
import MarblezzzCore

struct TableSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: PlayMode
    let onStart: (MatchSettings, Seat) -> Void
    @State private var humans: Set<Seat> = [.red, .yellow]
    @State private var names = ["Red", "Yellow", "Green", "Blue"]
    @State private var host: Seat = .red
    @State private var difficulty: BotDifficulty = .standard
    @State private var timer: TimeControl = .unlimited
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(mode == .online ? "Invite two to four people. Computer players fill the other seats." : "Gather two to four people around this device. Opposite colors are partners.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    if mode == .online {
                        Picker("Your color", selection: $host) { ForEach(Seat.allCases) { Text($0.name).tag($0) } }
                            .onChange(of: host) { _, value in humans.insert(value) }
                    }
                    ForEach(Seat.allCases) { seat in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding(get: { humans.contains(seat) }, set: { enabled in
                                if enabled { humans.insert(seat) }
                                else if humans.count > 2 { humans.remove(seat) }
                            })) {
                                Label {
                                    Text("\(seat.name) · \(seat.partner.name)'s partner").foregroundStyle(Palette.pine)
                                } icon: {
                                    Image(systemName: seat.symbol).foregroundStyle(seat.color)
                                }
                            }.disabled(mode == .online && seat == host)
                                .accessibilityIdentifier("seat-toggle-\(seat.rawValue)")
                            if humans.contains(seat) && mode == .passAndPlay {
                                TextField("Player name", text: $names[seat.rawValue]).textContentType(.nickname).autocorrectionDisabled()
                                    .accessibilityLabel("\(seat.name) player name")
                            } else { Text(humans.contains(seat) ? (seat == host ? "You" : "Invited friend") : "Computer player").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 4)
                    }
                } header: { Text("Around the table") }
                  footer: { Text("Keep at least two human seats. Red + Green play against Yellow + Blue.") }
                Section("Computer players") {
                    Picker("Difficulty", selection: $difficulty) {
                        Text("Easy").tag(BotDifficulty.easy); Text("Standard").tag(BotDifficulty.standard)
                    }
                }
                if mode == .online {
                    Section("Time to take a turn") {
                        Picker("Turn timer", selection: $timer) { ForEach(TimeControl.allCases) { Text($0.label).tag($0) } }
                        Text(timer == .unlimited ? "No Limit waits indefinitely. Resigning forfeits your team; no computer replaces a human." : "A missed deadline gives the computer one turn. Resigning permanently hands your seat to a computer.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("When all apps are closed, pending computer moves finish when an authorized player reconnects.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button {
                        var settings = MatchSettings(mode: mode, humanSeats: humans, difficulty: difficulty, timeControl: timer)
                        for seat in Seat.allCases where humans.contains(seat) {
                            let name = String(names[seat.rawValue].trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                            settings.seats[seat.rawValue].name = name.isEmpty ? seat.name : name
                        }
                        onStart(settings, host)
                    } label: {
                        Text(mode == .online ? "Choose friends in Game Center" : "Deal the cards").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.font(.headline).accessibilityIdentifier("start-table")
                }
            }.navigationTitle(mode == .online ? "Set your table" : "Pass & play")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct OnlineTablesView: View {
    @EnvironmentObject private var transport: GameCenterTransport
    @Environment(\.dismiss) private var dismiss
    let onCreate: () -> Void
    let onOpen: (String) -> Void
    var body: some View {
        NavigationStack {
            Group {
                if !transport.authenticated {
                    ContentUnavailableView {
                        Label("Your friends are one sign-in away.", systemImage: "person.2.circle")
                    } description: {
                        Text("Use your Game Center identity to invite friends and come back to saved games.")
                    } actions: {
                        Button("Sign in to Game Center") { transport.authenticate() }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section { Button("Set up a new table", systemImage: "plus.circle", action: onCreate).font(.headline).padding(.vertical, 8) }
                        if transport.tables.isEmpty {
                            Section { Text("Your saved tables will appear here. Start a game and invite your people.").foregroundStyle(.secondary) }
                        }
                        ForEach(transport.tables) { table in
                            Button { onOpen(table.id) } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(table.title).font(.headline)
                                    HStack {
                                        Text(table.detail)
                                        Spacer()
                                        if table.invitation { Text("Invitation") }
                                        else if table.yourTurn && !table.ended { Text("Your turn").bold().foregroundStyle(Palette.pine) }
                                    }.font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 7)
                            }
                        }
                    }.refreshable { await transport.refreshTables() }
                }
            }.navigationTitle("Your tables")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .task { await transport.refreshTables() }
                .sheet(isPresented: Binding(get: { transport.authenticationController != nil }, set: { if !$0 { transport.authenticationController = nil } })) {
                    if let controller = transport.authenticationController { HostedController(controller: controller).ignoresSafeArea() }
                }
        }
    }
}
