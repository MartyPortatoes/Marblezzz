import SwiftUI

@main struct MarblezzzApp: App {
    @StateObject private var purchases: PurchaseStore
    @StateObject private var transport: GameCenterTransport
    @StateObject private var model: GameModel
    init() {
        let purchases = PurchaseStore()
        let transport = GameCenterTransport()
        _purchases = StateObject(wrappedValue: purchases)
        _transport = StateObject(wrappedValue: transport)
        _model = StateObject(wrappedValue: GameModel(purchases: purchases, transport: transport))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).environmentObject(purchases).environmentObject(transport)
                .tint(Palette.pine).preferredColorScheme(.light)
        }
    }
}
