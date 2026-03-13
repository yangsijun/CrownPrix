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
    let totalPlayerCount: Int
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        return true
    }
}

final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    @Published var isAuthenticated: Bool = false

    func submitScore(trackId: String, lapTime: TimeInterval) async throws {
        #if DEBUG
        if Self.isDevTrack(trackId) {
            print("[GC-Mock] submitScore intercepted: \(trackId) \(lapTime)")
            return
        }
        #endif
        try await WatchConnectivityManager.shared.transferScoreAsync(trackId: trackId, lapTime: lapTime)
    }

    func submitSectorTimes(trackId: String, times: [TimeInterval?]) async throws {
        #if DEBUG
        if Self.isDevTrack(trackId) {
            print("[GC-Mock] submitSectorTimes intercepted: \(trackId)")
            return
        }
        #endif
        try await WatchConnectivityManager.shared.transferSectorTimesAsync(trackId: trackId, times: times)
    }

    func loadLeaderboard(leaderboardId: String, topCount: Int) async throws -> LeaderboardData {
        #if DEBUG
        if Self.isDevLeaderboard(leaderboardId) {
            return Self.mockLeaderboardData()
        }
        #endif
        return try await withCheckedThrowingContinuation { continuation in
            let message: [String: Any] = ["type": "loadLeaderboard", "leaderboardId": leaderboardId, "topCount": topCount]
            let once = ResumeOnce()
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                guard once.claim() else { return }
                let entries = (reply["entries"] as? [[String: Any]] ?? []).compactMap { LeaderboardEntry.from($0) }
                var local: LeaderboardEntry?
                if let localDict = reply["localPlayer"] as? [String: Any] {
                    local = LeaderboardEntry.from(localDict)
                }
                let totalCount = reply["totalCount"] as? Int ?? entries.count
                continuation.resume(returning: LeaderboardData(topEntries: entries, localPlayer: local, totalPlayerCount: totalCount))
            }, errorHandler: { error in
                guard once.claim() else { return }
                continuation.resume(throwing: error)
            })
        }
    }

    func loadTopScores(leaderboardId: String, count: Int) async throws -> [LeaderboardEntry] {
        let data = try await loadLeaderboard(leaderboardId: leaderboardId, topCount: count)
        return data.topEntries
    }

    func loadGlobalBestSectorTimes(trackId: String) async -> [TimeInterval?] {
        #if DEBUG
        if Self.isDevTrack(trackId) {
            return Self.mockSectorTimes()
        }
        #endif
        return await withCheckedContinuation { continuation in
            let message: [String: Any] = ["type": "loadBestSectorTimes", "trackId": trackId]
            let once = ResumeOnce()
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                guard once.claim() else { return }
                let times = (reply["times"] as? [Double] ?? [-1, -1, -1]).map { $0 < 0 ? nil : $0 as TimeInterval? }
                continuation.resume(returning: times)
            }, errorHandler: { _ in
                guard once.claim() else { return }
                continuation.resume(returning: [nil, nil, nil])
            })
        }
    }

    func syncBestTimes() async {
        guard isAuthenticated else { return }

        let gcTimes: [String: Double] = await withCheckedContinuation { continuation in
            let message: [String: Any] = ["type": "syncBestTimes"]
            let once = ResumeOnce()
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                guard once.claim() else { return }
                let times = reply["bestTimes"] as? [String: Double] ?? [:]
                continuation.resume(returning: times)
            }, errorHandler: { _ in
                guard once.claim() else { return }
                continuation.resume(returning: [:])
            })
        }

        guard !gcTimes.isEmpty else { return }

        for (trackId, gcTime) in gcTimes {
            let localBest = PersistenceManager.getBestTime(trackId: trackId)
            if localBest == nil || gcTime < localBest! {
                PersistenceManager.forceSetBestTime(trackId: trackId, time: gcTime)
            }
        }

        let allLocal = PersistenceManager.getAllBestTimes()
        for (trackId, localTime) in allLocal {
            if let gcTime = gcTimes[trackId], localTime < gcTime {
                try? await submitScore(trackId: trackId, lapTime: localTime)
            } else if gcTimes[trackId] == nil {
                try? await submitScore(trackId: trackId, lapTime: localTime)
            }
        }
    }

    func syncBestSectorTimes() async {
        guard isAuthenticated else { return }

        let gcData: [String: [Double]] = await withCheckedContinuation { continuation in
            let message: [String: Any] = ["type": "syncBestSectorTimes"]
            let once = ResumeOnce()
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                guard once.claim() else { return }
                continuation.resume(returning: reply["bestSectorTimes"] as? [String: [Double]] ?? [:])
            }, errorHandler: { _ in
                guard once.claim() else { return }
                continuation.resume(returning: [:])
            })
        }

        for (trackId, gcSectors) in gcData {
            let times: [TimeInterval?] = gcSectors.map { $0 < 0 ? nil : $0 }
            PersistenceManager.saveBestSectorTimes(trackId: trackId, times: times)
        }

        for meta in TrackRegistry.allTracks {
            let localTimes = PersistenceManager.getBestSectorTimes(trackId: meta.id)
            guard localTimes.contains(where: { $0 != nil }) else { continue }

            if let gcSectors = gcData[meta.id] {
                let gcTimes: [TimeInterval?] = gcSectors.map { $0 < 0 ? nil : $0 }
                let hasBetter = (0..<3).contains { i in
                    guard let local = localTimes[i] else { return false }
                    return gcTimes[i] == nil || local < gcTimes[i]!
                }
                if hasBetter {
                    try? await submitSectorTimes(trackId: meta.id, times: localTimes)
                }
            } else {
                try? await submitSectorTimes(trackId: meta.id, times: localTimes)
            }
        }
    }

    struct SectorRecord {
        let sector: Int
        let playerName: String
        let time: TimeInterval
    }

    func loadSectorRecords(trackId: String) async -> [SectorRecord?] {
        #if DEBUG
        if Self.isDevTrack(trackId) {
            return Self.mockSectorRecords()
        }
        #endif
        return await withCheckedContinuation { continuation in
            let message: [String: Any] = ["type": "loadSectorRecords", "trackId": trackId]
            let once = ResumeOnce()
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                guard once.claim() else { return }
                let dicts = reply["records"] as? [[String: Any]] ?? []
                let result: [SectorRecord?] = dicts.enumerated().map { i, dict in
                    guard let name = dict["playerName"] as? String,
                          let time = dict["time"] as? Double,
                          time >= 0 else { return nil }
                    return SectorRecord(sector: i, playerName: name, time: time)
                }
                continuation.resume(returning: result)
            }, errorHandler: { _ in
                guard once.claim() else { return }
                continuation.resume(returning: [nil, nil, nil])
            })
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    #if DEBUG
    // MARK: - Dev Track Mock

    private static let devTrackId = "dev"
    private static let devLeaderboardId = "cp.laptime.dev"

    static func isDevTrack(_ trackId: String) -> Bool {
        trackId == devTrackId
    }

    static func isDevLeaderboard(_ leaderboardId: String) -> Bool {
        leaderboardId == devLeaderboardId
    }

    private static func mockLeaderboardData() -> LeaderboardData {
        let names = ["Max V.", "Lewis H.", "Charles L.", "Lando N.", "Carlos S.",
                     "Oscar P.", "George R.", "Fernando A.", "Pierre G.", "Yuki T."]
        let baseLapTime: TimeInterval = 82.0
        let entries = names.enumerated().map { i, name in
            LeaderboardEntry(
                rank: i + 1,
                playerName: name,
                lapTime: baseLapTime + Double(i) * 0.347,
                isLocalPlayer: i == 4
            )
        }
        let local = entries.first { $0.isLocalPlayer }
        return LeaderboardData(topEntries: entries, localPlayer: local, totalPlayerCount: 247)
    }

    private static func mockSectorTimes() -> [TimeInterval?] {
        [25.432, 28.891, 27.677]
    }

    private static func mockSectorRecords() -> [SectorRecord?] {
        [
            SectorRecord(sector: 0, playerName: "Max V.", time: 25.432),
            SectorRecord(sector: 1, playerName: "Lewis H.", time: 28.891),
            SectorRecord(sector: 2, playerName: "Charles L.", time: 27.677)
        ]
    }
    #endif
}
