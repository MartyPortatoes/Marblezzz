import SwiftUI
import MarblezzzCore

private struct Lesson: Identifiable {
    var id: Int
    var icon: String
    var title: String
    var body: String
    var example: String
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize: CGFloat = 36
    @State private var page = 0
    private let lessons: [Lesson] = [
        Lesson(id: 0, icon: "person.2.fill", title: "Two teams. One way home.", body: "Four players have five marbles each. Opposite colors are partners: Red with Green, Yellow with Blue. Get all ten team marbles home to win.", example: "The track has 48 spaces. Move clockwise around the cross; each color has its own five-space home lane."),
        Lesson(id: 1, icon: "door.left.hand.open", title: "Your invitation to the board.", body: "An ace or king brings one marble from its starting area directly onto its colored entry space. An ace can instead move a marble forward one.", example: "Kings only enter marbles. Entry spaces are not protected: entering onto an opponent sends that opponent back."),
        Lesson(id: 2, icon: "arrow.right", title: "Choose your move.", body: "Tap a card, then a marble, or tap a marble, then a card. Confirm the move to play. Number cards move their value, except 3 goes backward. A queen moves 12.", example: "Seven is an ordinary move of seven, not a split move. There are no extra turns."),
        Lesson(id: 3, icon: "hand.raised.fill", title: "Look out for your own team.", body: "You may pass opponents, but cannot pass or land on your own or your partner's marbles. Land exactly on an opponent to send it back to its starting area.", example: "Passing an opponent does not capture it. Friendly marbles block backward moves too."),
        Lesson(id: 4, icon: "arrow.uturn.backward", title: "Sometimes back is the way forward.", body: "A 3 moves a track marble backward three. You can go backward past your home entrance, then turn into home on a later forward move without a full lap.", example: "From Red's entry: back three, then forward four lands in Red's second home space. A marble already in home cannot move backward."),
        Lesson(id: 5, icon: "arrow.triangle.swap", title: "A change of places.", body: "A jack switches one of your track marbles with any other track marble—including your partner's or another of your own. Select both, then confirm.", example: "Marbles in starting areas and home lanes cannot switch. A same-color switch is still legal, even when the board looks unchanged."),
        Lesson(id: 6, icon: "house.fill", title: "Make it an exact arrival.", body: "A forward move must turn into your home lane when it reaches the entrance. Use the full card value without overshooting, passing, or landing on another home marble.", example: "If a move cannot fit, choose another marble or card. You cannot take another lap instead."),
        Lesson(id: 7, icon: "rectangle.stack.fill", title: "If you can play, you must.", body: "Any legal play means you must play a legal card. You cannot throw away an unplayable card while another one works. If your whole hand is unplayable, reveal and discard all of it.", example: "After forfeiting your hand, sit out until the next deal—even if the board changes. Everyone may see the cards you discarded."),
        Lesson(id: 8, icon: "suit.club.fill", title: "Five. Four. Four. Again.", body: "Use 52 cards, no jokers. Deal five each, play the hands out, then four each, then four each. Shuffle all the cards and rotate the dealer after that complete cycle.", example: "The player clockwise after the dealer starts each hand. There are no draws or card exchanges. Keep your hand private, including from your partner."),
        Lesson(id: 9, icon: "heart.fill", title: "All home? You're not done yet.", body: "Once your five marbles are home, keep your own cards and normal turns, but move your partner's marbles. Your team wins the moment all ten are home.", example: "Your cards, their marbles. That's teamwork.")
    ]
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ProgressView(value: Double(page+1), total: Double(lessons.count)).tint(Palette.gold).padding(.horizontal, 24)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Image(systemName: lessons[page].icon).font(.system(size: 46)).foregroundStyle(Palette.gold).padding(.top, 30)
                        Text(lessons[page].title).font(.system(size: headingSize, design: .serif))
                        Text(lessons[page].body).font(.title3).lineSpacing(5)
                        Text(lessons[page].example).font(.subheadline).lineSpacing(4).foregroundStyle(Palette.secondary)
                            .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.cream, in: RoundedRectangle(cornerRadius: 18))
                    }.padding(.horizontal, 26).frame(maxWidth: 600).frame(maxWidth: .infinity)
                }
                navigationLayout {
                    Button("Back") { page -= 1 }.disabled(page == 0).frame(minWidth: 65, minHeight: 44)
                    Text("\(page+1) / \(lessons.count)").font(.caption).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity)
                    Button(page == lessons.count-1 ? "Let's play" : "Next") {
                        if page == lessons.count-1 { dismiss() } else { page += 1 }
                    }.buttonStyle(.borderedProminent).foregroundStyle(Palette.cream)
                        .accessibilityIdentifier("tutorial-next")
                }.padding(24)
            }.foregroundStyle(Palette.pine).background(Palette.background)
                .navigationTitle("Learn the game").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
    private var navigationLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var transport: GameCenterTransport
    @AppStorage("soundEnabled") private var sound = false
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("botDifficulty") private var difficulty = BotDifficulty.standard.rawValue
    var body: some View {
        NavigationStack {
            Form {
                Section("At your table") {
                    Toggle("Sound effects", isOn: $sound)
                    Toggle("Haptics", isOn: $haptics)
                    Picker("Solo computer difficulty", selection: $difficulty) {
                        ForEach(BotDifficulty.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0.rawValue) }
                    }
                    Text("Marblezzz follows your device's Reduce Motion setting. Player symbols and the legal move list work alongside color.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("Solo and pass-and-play stay on this device. Online games use Game Center. Purchases use Apple's StoreKit. Marblezzz includes no advertising or third-party analytics.")
                    Text("Hands are private in normal play. Game Center's shared match data is not a server-enforced anti-cheat system.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let privacyURL = URL(string: "https://martyportatoes.github.io/Marblezzz/privacy/") {
                        Link("Privacy policy", destination: privacyURL)
                    }
                }
                Section("Help") {
                    if let supportURL = URL(string: "https://martyportatoes.github.io/Marblezzz/support/") {
                        Link("Support", destination: supportURL)
                    }
                }
                Section("Game Center diagnostics") {
                    Text(transport.diagnostic).font(.caption.monospaced()).textSelection(.enabled)
                    Text("Diagnostics contain participant status and timing, never hands or the deck. Include these details when reporting a multiplayer problem.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section { Text("Marblezzz · 1.0\nMade for a little friendly rivalry.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }
        }
    }
}
