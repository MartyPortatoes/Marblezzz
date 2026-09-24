import SwiftUI
import StoreKit

struct StorefrontView: View {
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("boardTheme") private var themeName = BoardTheme.original.rawValue
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Make room\nfor your people.").font(.system(.largeTitle, design: .serif))
                        Text("Solo is always free. One purchase opens the table to friends, near and far.")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Friends for good", systemImage: "person.2.fill").font(.title2.weight(.semibold))
                        Text("Pass-and-play and private online games. Pay once, keep playing. Each online player needs access; one purchase covers a shared device.")
                            .font(.subheadline)
                        Label("Supports Family Sharing", systemImage: "person.3").font(.caption)
                        purchaseButton(ProductID.friends, ownedTitle: "Friends unlocked")
                    }.padding(22).background(Palette.pine.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                    Text("A table that feels like you.").font(.system(.title2, design: .serif))
                    Text("Optional finishes for your board, marbles, and card backs. Every move still plays the same.")
                        .font(.subheadline).foregroundStyle(Palette.secondary)
                    ForEach(BoardTheme.allCases) { theme in
                        VStack(alignment: .leading, spacing: 12) {
                            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(uiColor: theme.wood), Color(uiColor: theme.woodDark)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 95).overlay {
                                    HStack(spacing: 16) {
                                        ForEach(0..<4) { index in Circle().fill([Color.red, .yellow, .green, .blue][index].gradient).frame(width: 32,height: 32).shadow(radius: 3,y: 3) }
                                    }
                                }
                            HStack {
                                Text(theme.name).font(.headline)
                                Spacer()
                                if purchases.owns(theme.productID) {
                                    Button(themeName == theme.rawValue ? "Selected" : "Use finish") { themeName = theme.rawValue }
                                        .buttonStyle(.bordered).disabled(themeName == theme.rawValue)
                                }
                            }
                            if let id = theme.productID, !purchases.owns(id) { purchaseButton(id, ownedTitle: "Purchased") }
                        }.padding(16).background(Palette.cream, in: RoundedRectangle(cornerRadius: 20))
                    }
                    Button("Restore purchases") { Task { await purchases.restore() } }
                        .frame(maxWidth: .infinity, minHeight: 44).disabled(purchases.busy)
                    Text("Purchases are handled by Apple. Cosmetic packs do not include Friends access.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(Palette.background).foregroundStyle(Palette.pine)
                .navigationTitle("The table shop").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
                .task { await purchases.loadProducts() }
                .alert("Store update", isPresented: Binding(
                    get: { purchases.message != nil },
                    set: { if !$0 { purchases.message = nil } }
                )) { } message: {
                    Text(purchases.message ?? "")
                }
        }
    }
    @ViewBuilder private func purchaseButton(_ id: String, ownedTitle: String) -> some View {
        if purchases.owned.contains(id) || (id == ProductID.friends && purchases.hasFriends) {
            Label(ownedTitle, systemImage: "checkmark.seal.fill").font(.headline)
        } else if let product = purchases.product(id) {
            Button { Task { await purchases.purchase(product) } } label: { Text("Unlock · \(product.displayPrice)") }
                .buttonStyle(PrimaryButton()).disabled(purchases.busy).accessibilityIdentifier("buy-\(id)")
        } else {
            Button("Reload store") { Task { await purchases.loadProducts() } }.buttonStyle(.bordered)
            Text("Store pricing is temporarily unavailable. No purchase will be made until Apple provides a product.")
                .font(.caption).foregroundStyle(Palette.secondary)
        }
    }
}
