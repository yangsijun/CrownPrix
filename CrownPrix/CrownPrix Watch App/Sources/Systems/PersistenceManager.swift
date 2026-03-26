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

    static func cleanupInvalidSectorTimes() {
        let key = "didCleanupZeroSectors"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        for track in TrackRegistry.allTracks {
            for i in 0..<3 {
                let sectorKey = "bestSector.\(track.id).\(i)"
                if let time = UserDefaults.standard.object(forKey: sectorKey) as? TimeInterval, time <= 0 {
                    UserDefaults.standard.removeObject(forKey: sectorKey)
                }
            }
        }
        UserDefaults.standard.set(true, forKey: key)
    }
}
