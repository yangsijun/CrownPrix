import SwiftUI

@main
struct CrownPrixApp: App {
    @StateObject private var gcManager = GameCenterManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gcManager)
                .onAppear {
                    PhoneConnectivityManager.shared.activate()
                    GameCenterManager.shared.authenticate()
                }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                GameCenterManager.shared.authenticate()
            }
        }
    }
}
