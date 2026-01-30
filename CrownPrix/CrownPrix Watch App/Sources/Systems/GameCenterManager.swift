import Combine
import GameKit

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let playerName: String
    let lapTime: TimeInterval
    let isLocalPlayer: Bool
}

struct LeaderboardData {
    let topEntries: [LeaderboardEntry]
    let localPlayer: LeaderboardEntry?
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
        let data = try await loadLeaderboard(leaderboardId: leaderboardId, topCount: count)
        return data.topEntries
    }

    func loadLeaderboard(leaderboardId: String, topCount: Int) async throws -> LeaderboardData {
        let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
        guard let leaderboard = leaderboards.first else {
            return LeaderboardData(topEntries: [], localPlayer: nil)
        }
        let (localEntry, entries, _) = try await leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...topCount))
        let topEntries = entries.map { entry in
            LeaderboardEntry(
                rank: entry.rank,
                playerName: entry.player.displayName,
                lapTime: TimeInterval(entry.score) / 1000.0,
                isLocalPlayer: entry.player == GKLocalPlayer.local
            )
        }
        let local: LeaderboardEntry? = localEntry.map {
            LeaderboardEntry(
                rank: $0.rank,
                playerName: $0.player.displayName,
                lapTime: TimeInterval($0.score) / 1000.0,
                isLocalPlayer: true
            )
        }
        return LeaderboardData(topEntries: topEntries, localPlayer: local)
    }

    func submitSectorTimes(trackId: String, times: [TimeInterval?]) {
        guard isAuthenticated else { return }
        Task {
            for (i, time) in times.enumerated() {
                guard let t = time else { continue }
                let leaderboardId = "crownprix.sector.\(trackId).\(i)"
                let score = Int(t * 1000)
                do {
                    try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardId])
                } catch {
                    print("Sector score submission failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func loadGlobalBestSectorTimes(trackId: String) async -> [TimeInterval?] {
        guard isAuthenticated else { return [nil, nil, nil] }
        var result: [TimeInterval?] = [nil, nil, nil]
        for i in 0..<3 {
            let leaderboardId = "crownprix.sector.\(trackId).\(i)"
            do {
                let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
                guard let lb = leaderboards.first else { continue }
                let (_, entries, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
                if let top = entries.first {
                    result[i] = TimeInterval(top.score) / 1000.0
                }
            } catch {
                continue
            }
        }
        return result
    }
}
