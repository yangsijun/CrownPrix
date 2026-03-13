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

enum GCError: Error {
    case notAuthenticated
    case unknownTrack
}

final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    @Published var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let error {
                    print("[GC] auth error: \(error.localizedDescription)")
                }
                let authed = GKLocalPlayer.local.isAuthenticated
                print("[GC] authenticated: \(authed), player: \(GKLocalPlayer.local.displayName)")
                self?.isAuthenticated = authed
                PhoneConnectivityManager.shared.sendAuthStatus(authed)
            }
        }
    }

    func submitScore(trackId: String, lapTime: TimeInterval) async throws {
        guard isAuthenticated else {
            print("[GC] submitScore skipped — not authenticated")
            throw GCError.notAuthenticated
        }
        guard let leaderboardId = TrackRegistry.track(byId: trackId)?.leaderboardId else {
            print("[GC] submitScore skipped — unknown trackId: \(trackId)")
            throw GCError.unknownTrack
        }
        let score = Int(lapTime * 1000)
        print("[GC] submitting score \(score) to \(leaderboardId)")
        try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardId])
        print("[GC] score submitted OK: \(score) -> \(leaderboardId)")
    }

    func submitSectorTimes(trackId: String, times: [TimeInterval?]) async throws {
        guard isAuthenticated else {
            print("[GC] submitSectorTimes skipped — not authenticated")
            throw GCError.notAuthenticated
        }
        for (i, time) in times.enumerated() {
            guard let t = time else { continue }
            let leaderboardId = "cp.sector.\(trackId).\(i)"
            let score = Int(t * 1000)
            try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardId])
            print("[GC] sector submitted OK: \(score) -> \(leaderboardId)")
        }
    }

    func loadLeaderboard(leaderboardId: String, topCount: Int) async -> [String: Any] {
        guard isAuthenticated else {
            print("[GC] loadLeaderboard skipped — not authenticated")
            return ["entries": [], "localPlayer": NSNull()]
        }
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
            guard let lb = leaderboards.first else {
                print("[GC] loadLeaderboard — no leaderboard found for \(leaderboardId)")
                return ["entries": [], "localPlayer": NSNull()]
            }
            let (localEntry, entries, totalCount) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...topCount))
            print("[GC] loaded \(leaderboardId): \(entries.count) entries, total=\(totalCount), local=\(localEntry != nil)")
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
            return ["entries": topEntries, "localPlayer": local as Any, "totalCount": totalCount]
        } catch {
            print("[GC] loadLeaderboard FAILED \(leaderboardId): \(error)")
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
                guard let lb = leaderboards.first else {
                    print("[GC] sector leaderboard not found: \(leaderboardId)")
                    continue
                }
                let (_, entries, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
                if let top = entries.first {
                    result[i] = Double(top.score) / 1000.0
                }
            } catch {
                print("[GC] sector load FAILED \(leaderboardId): \(error)")
                continue
            }
        }
        return result
    }

    func loadMyBestSectorTimes() async -> [String: [Double]] {
        guard isAuthenticated else { return [:] }
        var result: [String: [Double]] = [:]
        for meta in TrackRegistry.allTracks {
            var sectors: [Double] = [-1, -1, -1]
            var hasAny = false
            for i in 0..<3 {
                let leaderboardId = "cp.sector.\(meta.id).\(i)"
                do {
                    let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
                    guard let lb = leaderboards.first else { continue }
                    let (localEntry, _, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
                    if let entry = localEntry {
                        sectors[i] = Double(entry.score) / 1000.0
                        hasAny = true
                    }
                } catch {
                    print("[GC] loadMyBestSectorTimes FAILED \(leaderboardId): \(error)")
                    continue
                }
            }
            if hasAny {
                result[meta.id] = sectors
            }
        }
        return result
    }

    func loadMyBestTimes() async -> [String: Double] {
        guard isAuthenticated else { return [:] }
        var result: [String: Double] = [:]
        for meta in TrackRegistry.allTracks {
            let leaderboardId = meta.leaderboardId
            do {
                let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
                guard let lb = leaderboards.first else { continue }
                let (localEntry, _, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
                if let entry = localEntry {
                    result[meta.id] = Double(entry.score) / 1000.0
                }
            } catch {
                print("[GC] loadMyBestTimes FAILED \(leaderboardId): \(error)")
                continue
            }
        }
        return result
    }

    struct SectorRecord {
        let sector: Int
        let playerName: String
        let time: TimeInterval
    }

    func loadSectorRecords(trackId: String) async -> [SectorRecord?] {
        guard isAuthenticated else { return [nil, nil, nil] }
        var result: [SectorRecord?] = [nil, nil, nil]
        for i in 0..<3 {
            let leaderboardId = "cp.sector.\(trackId).\(i)"
            do {
                let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardId])
                guard let lb = leaderboards.first else { continue }
                let (_, entries, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
                if let top = entries.first {
                    result[i] = SectorRecord(
                        sector: i,
                        playerName: top.player.displayName,
                        time: Double(top.score) / 1000.0
                    )
                }
            } catch {
                print("[GC] sector record load FAILED \(leaderboardId): \(error)")
                continue
            }
        }
        return result
    }
}
