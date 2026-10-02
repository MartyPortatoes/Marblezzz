import SwiftUI

@main struct MarblezzzApp: App {
    @StateObject private var transport: GameCenterTransport
    @StateObject private var model: GameModel
    init() {
        let transport = GameCenterTransport()
        _transport = StateObject(wrappedValue: transport)
        _model = StateObject(wrappedValue: GameModel(transport: transport))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).environmentObject(transport)
                .tint(Palette.pine).preferredColorScheme(.light)
        }
    }
}
