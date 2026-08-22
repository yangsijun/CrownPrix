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

    static func clearAllRecords() {
        for track in TrackRegistry.allTracks {
            UserDefaults.standard.removeObject(forKey: "bestTime.\(track.id)")
            for i in 0..<3 {
                UserDefaults.standard.removeObject(forKey: "bestSector.\(track.id).\(i)")
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
