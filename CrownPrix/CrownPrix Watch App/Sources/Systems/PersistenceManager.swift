import Foundation

enum PersistenceManager {
    static func saveBestTime(trackId: String, time: TimeInterval) {
        let key = "bestTime.\(trackId)"
        let currentBest = UserDefaults.standard.object(forKey: key) as? TimeInterval
        
        if currentBest == nil || time < currentBest! {
            UserDefaults.standard.set(time, forKey: key)
            HapticsManager.playNewRecord()
        }
    }
    
    static func forceSetBestTime(trackId: String, time: TimeInterval) {
        let key = "bestTime.\(trackId)"
        UserDefaults.standard.set(time, forKey: key)
    }

    static func getBestTime(trackId: String) -> TimeInterval? {
        let key = "bestTime.\(trackId)"
        return UserDefaults.standard.object(forKey: key) as? TimeInterval
    }
    
    static func getAllBestTimes() -> [String: TimeInterval] {
        var result: [String: TimeInterval] = [:]
        
        for track in TrackRegistry.allTracks {
            if let bestTime = getBestTime(trackId: track.id) {
                result[track.id] = bestTime
            }
        }
        
        return result
    }
    
    static func isNewRecord(trackId: String, time: TimeInterval) -> Bool {
        let currentBest = getBestTime(trackId: trackId)
        return currentBest == nil || time < currentBest!
    }

    static func saveBestSectorTimes(trackId: String, times: [TimeInterval?]) {
        for (i, time) in times.enumerated() {
            guard let t = time, t > 0 else { continue }
            let key = "bestSector.\(trackId).\(i)"
            let current = UserDefaults.standard.object(forKey: key) as? TimeInterval
            if current == nil || t < current! {
                UserDefaults.standard.set(t, forKey: key)
            }
        }
    }

    static func getBestSectorTimes(trackId: String) -> [TimeInterval?] {
        (0..<3).map { i in
            UserDefaults.standard.object(forKey: "bestSector.\(trackId).\(i)") as? TimeInterval
        }
    }

    static func forceSetBestSectorTime(trackId: String, sector: Int, time: TimeInterval) {
        UserDefaults.standard.set(time, forKey: "bestSector.\(trackId).\(sector)")
    }

    // MARK: - Server sync state
    // uploadedMs.* stores our record's millisecond score as last confirmed on
    // Game Center. The server is authoritative: when it later reports a slower
    // time (or no entry) than what we confirmed-uploaded, our record was
    // deleted there (cheat cleanup) and the local copy must NOT re-upload it.

    static func uploadedLapMs(trackId: String) -> Int? {
        UserDefaults.standard.object(forKey: "uploadedMs.\(trackId)") as? Int
    }

    static func setUploadedLapMs(trackId: String, ms: Int) {
        UserDefaults.standard.set(ms, forKey: "uploadedMs.\(trackId)")
    }

    /// After a confirmed submission: GC keeps the best score, so merge with min.
    static func recordUploadedLap(trackId: String, ms: Int) {
        setUploadedLapMs(trackId: trackId, ms: min(uploadedLapMs(trackId: trackId) ?? Int.max, ms))
    }

    static func uploadedSectorMs(trackId: String, sector: Int) -> Int? {
        UserDefaults.standard.object(forKey: "uploadedSectorMs.\(trackId).\(sector)") as? Int
    }

    static func setUploadedSectorMs(trackId: String, sector: Int, ms: Int) {
        UserDefaults.standard.set(ms, forKey: "uploadedSectorMs.\(trackId).\(sector)")
    }

    static func recordUploadedSector(trackId: String, sector: Int, ms: Int) {
        setUploadedSectorMs(trackId: trackId, sector: sector, ms: min(uploadedSectorMs(trackId: trackId, sector: sector) ?? Int.max, ms))
    }

    /// Server-side deletion: drop the local record and its sync state together.
    static func clearBestTime(trackId: String) {
        UserDefaults.standard.removeObject(forKey: "bestTime.\(trackId)")
        UserDefaults.standard.removeObject(forKey: "uploadedMs.\(trackId)")
        print("[Persist] cleared lap record for \(trackId) (deleted server-side)")
    }

    static func clearBestSectorTime(trackId: String, sector: Int) {
        UserDefaults.standard.removeObject(forKey: "bestSector.\(trackId).\(sector)")
        UserDefaults.standard.removeObject(forKey: "uploadedSectorMs.\(trackId).\(sector)")
        print("[Persist] cleared sector \(sector) record for \(trackId) (deleted server-side)")
    }

    static func clearAllRecords() {
        for track in TrackRegistry.allTracks {
            UserDefaults.standard.removeObject(forKey: "bestTime.\(track.id)")
            UserDefaults.standard.removeObject(forKey: "uploadedMs.\(track.id)")
            for i in 0..<3 {
                UserDefaults.standard.removeObject(forKey: "bestSector.\(track.id).\(i)")
                UserDefaults.standard.removeObject(forKey: "uploadedSectorMs.\(track.id).\(i)")
            }
        }
        print("[Persist] cleared all local records (account change)")
    }

    /// One-time wipe when the leaderboard generation is bumped (anti-cheat reset).
    /// Records set on older app versions may be tainted (shortcuts, reverse
    /// driving) and must never be uploaded to the new generation's boards.
    static func migrateForLeaderboardGeneration() {
        let key = "leaderboardGeneration"
        let stored = UserDefaults.standard.integer(forKey: key)
        guard stored < LeaderboardIDs.generation else { return }
        clearAllRecords()
        UserDefaults.standard.set(LeaderboardIDs.generation, forKey: key)
        print("[Persist] wiped local records for leaderboard generation \(LeaderboardIDs.generation)")
    }

    /// GameKit can report a phantom localPlayerEntry with score 0 on boards the
    /// player has never submitted to; syncs used to write that 0 into local
    /// storage, where it blocked real records. Runs every launch — cheap, and a
    /// phantom can reappear at any time.
    static func cleanupInvalidRecords() {
        for track in TrackRegistry.allTracks {
            let lapKey = "bestTime.\(track.id)"
            if let time = UserDefaults.standard.object(forKey: lapKey) as? TimeInterval, time <= 0 {
                UserDefaults.standard.removeObject(forKey: lapKey)
                print("[Persist] removed invalid 0 lap time for \(track.id)")
            }
            for i in 0..<3 {
                let sectorKey = "bestSector.\(track.id).\(i)"
                if let time = UserDefaults.standard.object(forKey: sectorKey) as? TimeInterval, time <= 0 {
                    UserDefaults.standard.removeObject(forKey: sectorKey)
                }
            }
        }
    }
}
