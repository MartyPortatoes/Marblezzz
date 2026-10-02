import SwiftUI

struct BoardFinishesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("boardTheme") private var themeName = BoardTheme.original.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("A table that feels like you.").font(.system(.title2, design: .serif))
                    Text("Every finish is included. Choose a look for your board, marbles, and card backs. Every move still plays the same.")
                        .font(.subheadline).foregroundStyle(Palette.secondary)
                    ForEach(BoardTheme.allCases) { theme in
                        VStack(alignment: .leading, spacing: 12) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [Color(uiColor: theme.wood), Color(uiColor: theme.woodDark)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 95).overlay {
                                    HStack(spacing: 16) {
                                        ForEach(0..<4) { index in
                                            Circle().fill([Color.red, .yellow, .green, .blue][index].gradient)
                                                .frame(width: 32, height: 32).shadow(radius: 3, y: 3)
                                        }
                                    }
                                }.accessibilityHidden(true)
                            HStack {
                                Text(theme.name).font(.headline)
                                Spacer()
                                Button(themeName == theme.rawValue ? "Selected" : "Use finish") {
                                    themeName = theme.rawValue
                                }
                                .buttonStyle(.bordered).frame(minHeight: 44)
                                .disabled(themeName == theme.rawValue)
                                .accessibilityLabel("\(theme.name), \(themeName == theme.rawValue ? "selected" : "use finish")")
                                .accessibilityIdentifier("finish-\(theme.rawValue)")
                            }
                        }.padding(16).background(Palette.cream, in: RoundedRectangle(cornerRadius: 20))
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(Palette.background).foregroundStyle(Palette.pine)
                .navigationTitle("Board finishes").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
