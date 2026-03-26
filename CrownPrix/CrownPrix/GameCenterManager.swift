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
                let playerID = GKLocalPlayer.local.gamePlayerID
                print("[GC] authenticated: \(authed), player: \(GKLocalPlayer.local.displayName), id: \(playerID)")
                self?.isAuthenticated = authed
                PhoneConnectivityManager.shared.sendAuthStatus(authed, playerID: playerID)
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

    private static let f1Points = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]

    struct ChampionshipResult {
        let standings: [ChampionshipStanding]
        let localPlayer: ChampionshipStanding?
    }

    struct ChampionshipStanding {
        let playerName: String
        let totalPoints: Int
        let tracksEntered: Int
        let isLocalPlayer: Bool
        let trackResults: [TrackResult]

        struct TrackResult {
            let trackId: String
            let trackName: String
            let flag: String
            let rank: Int
            let points: Int
        }
    }

    /// Calculate championship standings locally from GC leaderboard data.
    /// Fetches top 10 from each track, aggregates by displayName, returns sorted standings.
    func calculateChampionship(topPerTrack: Int = 10) async -> ChampionshipResult {
        guard isAuthenticated else { return ChampionshipResult(standings: [], localPlayer: nil) }

        let allLeaderboardIDs = TrackRegistry.allTracks.map { $0.leaderboardId }
        let trackByLeaderboard = Dictionary(uniqueKeysWithValues: TrackRegistry.allTracks.map { ($0.leaderboardId, $0) })
        let localName = GKLocalPlayer.local.displayName

        // playerName -> [TrackResult]
        var playerTracks: [String: [ChampionshipStanding.TrackResult]] = [:]

        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: allLeaderboardIDs)
            for lb in leaderboards {
                guard let meta = trackByLeaderboard[lb.baseLeaderboardID] else { continue }
                do {
                    let (_, entries, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...topPerTrack))
                    for entry in entries {
                        let rank = entry.rank
                        let pts = rank <= Self.f1Points.count ? Self.f1Points[rank - 1] : 0
                        let result = ChampionshipStanding.TrackResult(
                            trackId: meta.id,
                            trackName: meta.displayName,
                            flag: meta.flag,
                            rank: rank,
                            points: pts
                        )
                        playerTracks[entry.player.displayName, default: []].append(result)
                    }
                } catch {
                    print("[GC] calculateChampionship failed for \(meta.id): \(error)")
                }
            }
        } catch {
            print("[GC] loadLeaderboards batch failed: \(error)")
        }

        let standings = playerTracks.map { (name, tracks) in
            ChampionshipStanding(
                playerName: name,
                totalPoints: tracks.reduce(0) { $0 + $1.points },
                tracksEntered: tracks.count,
                isLocalPlayer: name == localName,
                trackResults: tracks.sorted { $0.points > $1.points }
            )
        }.sorted { $0.totalPoints > $1.totalPoints }

        let localPlayer = standings.first { $0.isLocalPlayer }
        return ChampionshipResult(standings: standings, localPlayer: localPlayer)
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
