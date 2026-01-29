import Combine
import GameKit

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let playerName: String
    let lapTime: TimeInterval
    let isLocalPlayer: Bool
}

final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    @Published var isAuthenticated: Bool = false

    func authenticate() {
        guard !isRunningTests else { return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] (error: Error?) in
            Task { @MainActor in
                if let error = error {
                    print("Game Center auth failed: \(error.localizedDescription)")
                    return
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if GKLocalPlayer.local.isAuthenticated {
                    print("Game Center: \(GKLocalPlayer.local.displayName)")
                }
            }
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func submitScore(trackId: String, lapTime: TimeInterval) {
        guard isAuthenticated else { return }
        guard let leaderboardId = TrackRegistry.track(byId: trackId)?.leaderboardId else { return }
        let score = Int(lapTime * 1000)
        Task {
            do {
                try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardId])
            } catch {
                print("Score submission failed: \(error.localizedDescription)")
            }
        }
    }

    func loadTopScores(leaderboardId: String, count: Int) async throws -> [LeaderboardEntry] {
        let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
        guard let leaderboard = leaderboards.first else { return [] }
        let (_, entries, _) = try await leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...count))
        return entries.map { entry in
            LeaderboardEntry(
                rank: entry.rank,
                playerName: entry.player.displayName,
                lapTime: TimeInterval(entry.score) / 1000.0,
                isLocalPlayer: entry.player == GKLocalPlayer.local
            )
        }
    }
}
