import SwiftUI

@main
struct CrownPrix_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    PersistenceManager.migrateForLeaderboardGeneration()
                    PersistenceManager.cleanupInvalidRecords()
                    WatchConnectivityManager.shared.activate()
                }
        }
    }
}
