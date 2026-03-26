import SwiftUI
import GameKit

@main
struct CrownPrixApp: App {
    @StateObject private var gcManager = GameCenterManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gcManager)
                .preferredColorScheme(.dark)
                .tint(.red)
                .onAppear {
                    PhoneConnectivityManager.shared.activate()
                    GameCenterManager.shared.authenticate()
                }
                // Trigger Supabase setup when GC auth completes
                .onChange(of: gcManager.isAuthenticated) { _, isAuthed in
                    guard isAuthed else { return }
                    let player = GKLocalPlayer.local
                    // Update Supabase client header with current player ID
                    SupabaseManager.shared.updatePlayerID(player.gamePlayerID)
                    // Backfill/reconcile: compare GC bests vs Supabase on each launch
                    Task { await SupabaseManager.shared.reconcileFromGameCenter() }
                    // Drain any pending retry queue items
                    Task { await SupabaseRetryQueue.shared.drain() }
                }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                GameCenterManager.shared.authenticate()
                // Drain retry queue on each foreground activation
                if gcManager.isAuthenticated {
                    Task { await SupabaseRetryQueue.shared.drain() }
                }
            }
        }
    }
}
