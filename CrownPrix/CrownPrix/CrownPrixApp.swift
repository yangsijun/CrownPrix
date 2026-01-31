import SwiftUI

@main
struct CrownPrixApp: App {
    @StateObject private var gcManager = GameCenterManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gcManager)
                .onAppear {
                    PhoneConnectivityManager.shared.activate()
                    GameCenterManager.shared.authenticate()
                }
        }
    }
}
