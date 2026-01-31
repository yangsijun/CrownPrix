import Combine
import Foundation

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let playerName: String
    let lapTime: TimeInterval
    let isLocalPlayer: Bool

    static func from(_ dict: [String: Any]) -> LeaderboardEntry? {
        guard let rank = dict["rank"] as? Int,
              let name = dict["playerName"] as? String,
              let lap = dict["lapTime"] as? Double,
              let isLocal = dict["isLocalPlayer"] as? Bool else { return nil }
        return LeaderboardEntry(rank: rank, playerName: name, lapTime: lap, isLocalPlayer: isLocal)
    }
}

struct LeaderboardData {
    let topEntries: [LeaderboardEntry]
    let localPlayer: LeaderboardEntry?
}

final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    @Published var isAuthenticated: Bool = false

    func submitScore(trackId: String, lapTime: TimeInterval) {
        WatchConnectivityManager.shared.transferScore(trackId: trackId, lapTime: lapTime)
    }

    func submitSectorTimes(trackId: String, times: [TimeInterval?]) {
        WatchConnectivityManager.shared.transferSectorTimes(trackId: trackId, times: times)
    }

    func loadLeaderboard(leaderboardId: String, topCount: Int) async throws -> LeaderboardData {
        try await withCheckedThrowingContinuation { continuation in
            let message: [String: Any] = ["type": "loadLeaderboard", "leaderboardId": leaderboardId, "topCount": topCount]
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                let entries = (reply["entries"] as? [[String: Any]] ?? []).compactMap { LeaderboardEntry.from($0) }
                var local: LeaderboardEntry?
                if let localDict = reply["localPlayer"] as? [String: Any] {
                    local = LeaderboardEntry.from(localDict)
                }
                continuation.resume(returning: LeaderboardData(topEntries: entries, localPlayer: local))
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    func loadTopScores(leaderboardId: String, count: Int) async throws -> [LeaderboardEntry] {
        let data = try await loadLeaderboard(leaderboardId: leaderboardId, topCount: count)
        return data.topEntries
    }

    func loadGlobalBestSectorTimes(trackId: String) async -> [TimeInterval?] {
        await withCheckedContinuation { continuation in
            let message: [String: Any] = ["type": "loadBestSectorTimes", "trackId": trackId]
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                let times = (reply["times"] as? [Double] ?? [-1, -1, -1]).map { $0 < 0 ? nil : $0 as TimeInterval? }
                continuation.resume(returning: times)
            }, errorHandler: { _ in
                continuation.resume(returning: [nil, nil, nil])
            })
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
