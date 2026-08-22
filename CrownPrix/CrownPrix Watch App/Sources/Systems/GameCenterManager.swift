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
        // GC boards enforce scoreRangeStart 15000ms; a 0 here means a phantom
        // GameKit entry leaked into local storage — never upload it.
        guard lapTime >= 15 else {
            print("[GC] submitScore skipped — invalid lapTime \(lapTime) for \(trackId)")
            return
        }
        let confirmed = try await WatchConnectivityManager.shared.transferScoreAsync(trackId: trackId, lapTime: lapTime)
        if confirmed {
            PersistenceManager.recordUploadedLap(trackId: trackId, ms: Self.submittedMs(lapTime))
        }
    }

    func submitSectorTimes(trackId: String, times: [TimeInterval?]) async throws {
        #if DEBUG
        if Self.isDevTrack(trackId) {
            print("[GC-Mock] submitSectorTimes intercepted: \(trackId)")
            return
        }
        #endif
        let confirmed = try await WatchConnectivityManager.shared.transferSectorTimesAsync(trackId: trackId, times: times)
        if confirmed {
            for (i, t) in times.enumerated() {
                guard let t, t > 0 else { continue }
                PersistenceManager.recordUploadedSector(trackId: trackId, sector: i, ms: Self.submittedMs(t))
            }
        }
    }

    /// Milliseconds as a submission truncates them (Int(t * 1000)).
    private static func submittedMs(_ t: TimeInterval) -> Int { Int(t * 1000) }
    /// Milliseconds of a value read back from GC (already ms-precise).
    private static func gcMs(_ t: TimeInterval) -> Int { Int((t * 1000).rounded()) }

    func loadLeaderboard(leaderboardId: String, topCount: Int) async throws -> LeaderboardData {
        #if DEBUG
        if Self.isDevLeaderboard(leaderboardId) {
            return Self.mockLeaderboardData()
        }
        #endif
        let reply = try await sendMessageWithTimeout(["type": "loadLeaderboard", "leaderboardId": leaderboardId, "topCount": topCount])
        // The phone marks failures explicitly so an empty entry list means a
        // genuinely empty board, not a failed load.
        if reply["error"] as? Bool == true { throw WCError.loadFailed }
        let entries = (reply["entries"] as? [[String: Any]] ?? []).compactMap { LeaderboardEntry.from($0) }
        var local: LeaderboardEntry?
        if let localDict = reply["localPlayer"] as? [String: Any] {
            local = LeaderboardEntry.from(localDict)
        }
        let totalCount = reply["totalCount"] as? Int ?? entries.count
        return LeaderboardData(topEntries: entries, localPlayer: local, totalPlayerCount: totalCount)
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
        do {
            let reply = try await sendMessageWithTimeout(["type": "loadBestSectorTimes", "trackId": trackId])
            return (reply["times"] as? [Double] ?? [-1, -1, -1]).map { raw -> TimeInterval? in
                if raw < 0 { return nil }        // load failed — global best unknown
                if raw == 0 { return .infinity } // board confirmed empty — any time is the global fastest
                return raw
            }
        } catch {
            return [nil, nil, nil]
        }
    }

    func syncTrackBests(trackId: String) async {
        guard isAuthenticated else {
            print("[GC] syncTrackBests skipped — not authenticated")
            return
        }
        #if DEBUG
        if Self.isDevTrack(trackId) { return }
        #endif
        do {
            let reply = try await sendMessageWithTimeout(["type": "syncTrackBests", "trackId": trackId])
            print("[GC] syncTrackBests reply for \(trackId): lapTime=\(reply["lapTime"] ?? "nil"), sectors=\(reply["sectorTimes"] ?? "nil")")
            // Values: > 0 our server record, 0 confirmed no entry, < 0 load failed.
            // The server is authoritative — see the merge rules in syncBestTimes.
            if let lapTime = reply["lapTime"] as? Double {
                if lapTime > 0 {
                    let serverMs = Self.gcMs(lapTime)
                    let localBest = PersistenceManager.getBestTime(trackId: trackId)
                    let deletedServerSide = PersistenceManager.uploadedLapMs(trackId: trackId).map { serverMs > $0 } ?? false
                    if deletedServerSide || localBest == nil || lapTime < localBest! {
                        PersistenceManager.forceSetBestTime(trackId: trackId, time: lapTime)
                    }
                    PersistenceManager.setUploadedLapMs(trackId: trackId, ms: serverMs)
                } else if lapTime == 0, PersistenceManager.uploadedLapMs(trackId: trackId) != nil {
                    PersistenceManager.clearBestTime(trackId: trackId)
                }
            }
            if let sectors = reply["sectorTimes"] as? [Double] {
                for (i, raw) in sectors.prefix(3).enumerated() {
                    if raw > 0 {
                        let serverMs = Self.gcMs(raw)
                        let local = PersistenceManager.getBestSectorTimes(trackId: trackId)[i]
                        let deletedServerSide = PersistenceManager.uploadedSectorMs(trackId: trackId, sector: i).map { serverMs > $0 } ?? false
                        if deletedServerSide || local == nil || raw < local! {
                            PersistenceManager.forceSetBestSectorTime(trackId: trackId, sector: i, time: raw)
                        }
                        PersistenceManager.setUploadedSectorMs(trackId: trackId, sector: i, ms: serverMs)
                    } else if raw == 0, PersistenceManager.uploadedSectorMs(trackId: trackId, sector: i) != nil {
                        PersistenceManager.clearBestSectorTime(trackId: trackId, sector: i)
                    }
                }
            }
        } catch {
            print("[GC] syncTrackBests failed for \(trackId): \(error)")
        }
    }

    /// Server-authoritative merge. "bestTimes" holds our real server records,
    /// "noEntry" the tracks confirmed to have none; tracks in neither failed to
    /// load and are left untouched (treating a failure as "missing" would
    /// resurrect records deleted server-side).
    func syncBestTimes() async {
        guard isAuthenticated else { return }

        let gcTimes: [String: Double]
        let noEntry: [String]
        do {
            let reply = try await sendMessageWithTimeout(["type": "syncBestTimes"])
            gcTimes = reply["bestTimes"] as? [String: Double] ?? [:]
            noEntry = reply["noEntry"] as? [String] ?? []
        } catch {
            return
        }

        // gcTime 0 is GameKit's phantom "no entry" localPlayerEntry — never persist it.
        for (trackId, gcTime) in gcTimes where gcTime > 0 {
            let serverMs = Self.gcMs(gcTime)
            let localBest = PersistenceManager.getBestTime(trackId: trackId)

            if let uploaded = PersistenceManager.uploadedLapMs(trackId: trackId), serverMs > uploaded {
                // The server reports a slower time than we confirmed-uploaded:
                // our faster record was deleted there (cheat cleanup). Server
                // wins — adopt its time and never re-upload the local copy.
                PersistenceManager.forceSetBestTime(trackId: trackId, time: gcTime)
                PersistenceManager.setUploadedLapMs(trackId: trackId, ms: serverMs)
                continue
            }
            PersistenceManager.setUploadedLapMs(trackId: trackId, ms: serverMs)
            if localBest == nil || gcTime < localBest! {
                PersistenceManager.forceSetBestTime(trackId: trackId, time: gcTime)
            } else if let local = localBest, Self.submittedMs(local) < serverMs {
                // A local improvement that never reached the server.
                try? await submitScore(trackId: trackId, lapTime: local)
            }
        }

        for trackId in noEntry {
            if PersistenceManager.uploadedLapMs(trackId: trackId) != nil {
                // We confirmed a record on the server before and now it's gone —
                // deleted server-side. Drop the local copy instead of re-uploading.
                PersistenceManager.clearBestTime(trackId: trackId)
            } else if let local = PersistenceManager.getBestTime(trackId: trackId) {
                try? await submitScore(trackId: trackId, lapTime: local)
            }
        }
    }

    /// Server-authoritative sector merge. Per-sector values from the phone:
    /// > 0 our server record, 0 confirmed no entry, < 0 load failed (untouched).
    func syncBestSectorTimes() async {
        guard isAuthenticated else { return }

        let gcData: [String: [Double]]
        do {
            let reply = try await sendMessageWithTimeout(["type": "syncBestSectorTimes"])
            gcData = reply["bestSectorTimes"] as? [String: [Double]] ?? [:]
        } catch {
            return
        }

        for (trackId, gcSectors) in gcData {
            let localTimes = PersistenceManager.getBestSectorTimes(trackId: trackId)
            var toUpload: [TimeInterval?] = [nil, nil, nil]

            for (i, raw) in gcSectors.prefix(3).enumerated() {
                if raw > 0 {
                    let serverMs = Self.gcMs(raw)
                    if let uploaded = PersistenceManager.uploadedSectorMs(trackId: trackId, sector: i), serverMs > uploaded {
                        // Our faster sector was deleted server-side — adopt the server's.
                        PersistenceManager.forceSetBestSectorTime(trackId: trackId, sector: i, time: raw)
                        PersistenceManager.setUploadedSectorMs(trackId: trackId, sector: i, ms: serverMs)
                        continue
                    }
                    PersistenceManager.setUploadedSectorMs(trackId: trackId, sector: i, ms: serverMs)
                    if localTimes[i] == nil || raw < localTimes[i]! {
                        PersistenceManager.forceSetBestSectorTime(trackId: trackId, sector: i, time: raw)
                    } else if let local = localTimes[i], Self.submittedMs(local) < serverMs {
                        toUpload[i] = local
                    }
                } else if raw == 0 {
                    if PersistenceManager.uploadedSectorMs(trackId: trackId, sector: i) != nil {
                        PersistenceManager.clearBestSectorTime(trackId: trackId, sector: i)
                    } else if let local = localTimes[i] {
                        toUpload[i] = local
                    }
                }
            }

            if toUpload.contains(where: { $0 != nil }) {
                try? await submitSectorTimes(trackId: trackId, times: toUpload)
            }
        }
    }

    struct SectorRecord {
        let sector: Int
        let playerName: String
        let time: TimeInterval
    }

    func submitLapTimeToSupabase(trackId: String, lapTime: TimeInterval) async throws {
        let lapTimeMs = Int(lapTime * 1000)
        _ = try await sendMessageWithTimeout(["type": "submitLapTimeToSupabase", "trackId": trackId, "lapTimeMs": lapTimeMs])
    }

    func loadChampionshipStandings(topCount: Int = 20) async throws -> (entries: [ChampionshipEntry], localPlayer: ChampionshipEntry?) {
        let reply = try await sendMessageWithTimeout(["type": "loadChampionship", "topCount": topCount])
        let entries = (reply["entries"] as? [[String: Any]] ?? []).compactMap { ChampionshipEntry.from($0) }
        var local: ChampionshipEntry?
        if let localDict = reply["localPlayer"] as? [String: Any] {
            local = ChampionshipEntry.from(localDict)
        }
        return (entries, local)
    }

    func loadChampionshipDetail(playerName: String) async throws -> ChampionshipDetail? {
        let reply = try await sendMessageWithTimeout(["type": "loadChampionshipDetail", "playerName": playerName])
        guard let detailDict = reply["detail"] as? [String: Any] else { return nil }
        return ChampionshipDetail.from(detailDict)
    }

    func loadSectorRecords(trackId: String) async -> [SectorRecord?] {
        #if DEBUG
        if Self.isDevTrack(trackId) {
            return Self.mockSectorRecords()
        }
        #endif
        do {
            let reply = try await sendMessageWithTimeout(["type": "loadSectorRecords", "trackId": trackId])
            let dicts = reply["records"] as? [[String: Any]] ?? []
            return dicts.enumerated().map { i, dict in
                guard let name = dict["playerName"] as? String,
                      let time = dict["time"] as? Double,
                      time >= 0 else { return nil }
                return SectorRecord(sector: i, playerName: name, time: time)
            }
        } catch {
            return [nil, nil, nil]
        }
    }

    private func sendMessageWithTimeout(
        _ message: [String: Any],
        timeout: TimeInterval = 10
    ) async throws -> [String: Any] {
        let once = ResumeOnce()
        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(timeout))
                guard !Task.isCancelled, once.claim() else { return }
                continuation.resume(throwing: WCError.timeout)
            }
            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                timeoutTask.cancel()
                guard once.claim() else { return }
                continuation.resume(returning: reply)
            }, errorHandler: { error in
                timeoutTask.cancel()
                guard once.claim() else { return }
                continuation.resume(throwing: error)
            })
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    #if DEBUG
    // MARK: - Dev Track Mock

    private static let devTrackId = "dev"
    private static let devLeaderboardId = LeaderboardIDs.lapTime("dev")

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
