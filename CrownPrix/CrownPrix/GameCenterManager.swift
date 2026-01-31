import GameKit

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let playerName: String
    let lapTime: TimeInterval
    let isLocalPlayer: Bool

    var asDictionary: [String: Any] {
        ["rank": rank, "playerName": playerName, "lapTime": lapTime, "isLocalPlayer": isLocalPlayer]
    }

    static func from(_ dict: [String: Any]) -> LeaderboardEntry? {
        guard let rank = dict["rank"] as? Int,
              let name = dict["playerName"] as? String,
              let lap = dict["lapTime"] as? Double,
              let isLocal = dict["isLocalPlayer"] as? Bool else { return nil }
        return LeaderboardEntry(rank: rank, playerName: name, lapTime: lap, isLocalPlayer: isLocal)
    }
}

final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    @Published var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("GC auth error: \(error.localizedDescription)")
                }
                let authed = GKLocalPlayer.local.isAuthenticated
                self?.isAuthenticated = authed
                PhoneConnectivityManager.shared.sendAuthStatus(authed)
            }
        }
    }

    func submitScore(trackId: String, lapTime: TimeInterval) {
        guard isAuthenticated else { return }
        guard let leaderboardId = TrackRegistry.track(byId: trackId)?.leaderboardId else { return }
        let score = Int(lapTime * 1000)
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardId])
        }
    }

    func submitSectorTimes(trackId: String, times: [TimeInterval?]) {
        guard isAuthenticated else { return }
        Task {
            for (i, time) in times.enumerated() {
                guard let t = time else { continue }
                let leaderboardId = "cp.sector.\(trackId).\(i)"
                let score = Int(t * 1000)
                try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardId])
            }
        }
    }

    func loadLeaderboard(leaderboardId: String, topCount: Int) async -> [String: Any] {
        guard isAuthenticated else { return ["entries": [], "localPlayer": NSNull()] }
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
            guard let lb = leaderboards.first else { return ["entries": [], "localPlayer": NSNull()] }
            let (localEntry, entries, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...topCount))
            let topEntries: [[String: Any]] = entries.map { entry in
                LeaderboardEntry(
                    rank: entry.rank,
                    playerName: entry.player.displayName,
                    lapTime: TimeInterval(entry.score) / 1000.0,
                    isLocalPlayer: entry.player == GKLocalPlayer.local
                ).asDictionary
            }
            let local: [String: Any]? = localEntry.map {
                LeaderboardEntry(
                    rank: $0.rank,
                    playerName: $0.player.displayName,
                    lapTime: TimeInterval($0.score) / 1000.0,
                    isLocalPlayer: true
                ).asDictionary
            }
            return ["entries": topEntries, "localPlayer": local as Any]
        } catch {
            return ["entries": [], "localPlayer": NSNull()]
        }
    }

    func loadGlobalBestSectorTimes(trackId: String) async -> [Double] {
        guard isAuthenticated else { return [-1, -1, -1] }
        var result: [Double] = [-1, -1, -1]
        for i in 0..<3 {
            let leaderboardId = "cp.sector.\(trackId).\(i)"
            do {
                let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
                guard let lb = leaderboards.first else { continue }
                let (_, entries, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
                if let top = entries.first {
                    result[i] = Double(top.score) / 1000.0
                }
            } catch { continue }
        }
        return result
    }
}
