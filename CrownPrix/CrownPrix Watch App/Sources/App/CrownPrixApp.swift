import SwiftUI

@main
struct CrownPrix_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    WatchConnectivityManager.shared.activate()
                }
        }
    }
}
