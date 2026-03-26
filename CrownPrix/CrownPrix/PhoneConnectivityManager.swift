import GameKit
import WatchConnectivity

final class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendAuthStatus(_ authenticated: Bool, playerID: String = "") {
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext([
            "gcAuthenticated": authenticated,
            "gcPlayerID": playerID
        ])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let type = message["type"] as? String else {
            replyHandler(["error": "missing type"])
            return
        }
        print("[WC-Phone] received message: \(type)")

        switch type {
        case "submitScore":
            guard let trackId = message["trackId"] as? String,
                  let lapTime = message["lapTime"] as? Double else {
                print("[WC-Phone] submitScore — invalid params")
                replyHandler(["ok": false])
                return
            }
            print("[WC-Phone] submitScore trackId=\(trackId) lapTime=\(lapTime)")
            Task {
                // 1. Submit to Game Center (existing -- unchanged)
                do {
                    try await GameCenterManager.shared.submitScore(trackId: trackId, lapTime: lapTime)
                    replyHandler(["ok": true])
                } catch {
                    print("[WC-Phone] submitScore failed: \(error)")
                    replyHandler(["ok": false, "error": error.localizedDescription])
                }

                // 2. Submit own lap time to Supabase (fire-and-forget)
                let player = GKLocalPlayer.local
                guard player.isAuthenticated else { return }
                #if DEBUG
                guard trackId != "dev" else { return }
                #endif
                let lapTimeMs = Int(lapTime * 1000)
                do {
                    try await SupabaseManager.shared.submitLapTime(
                        playerId: player.gamePlayerID,
                        playerName: player.displayName,
                        trackId: trackId,
                        lapTimeMs: lapTimeMs
                    )
                } catch {
                    print("[Supabase] submitLapTime failed: \(error)")
                }
            }

        case "submitSectorTimes":
            guard let trackId = message["trackId"] as? String,
                  let rawTimes = message["times"] as? [Double] else {
                replyHandler(["ok": false])
                return
            }
            let times: [TimeInterval?] = rawTimes.map { $0 < 0 ? nil : $0 }
            print("[WC-Phone] submitSectorTimes trackId=\(trackId) times=\(rawTimes)")
            Task {
                do {
                    try await GameCenterManager.shared.submitSectorTimes(trackId: trackId, times: times)
                    replyHandler(["ok": true])
                } catch {
                    print("[WC-Phone] submitSectorTimes failed: \(error)")
                    replyHandler(["ok": false, "error": error.localizedDescription])
                }
            }

        case "loadLeaderboard":
            guard let leaderboardId = message["leaderboardId"] as? String,
                  let topCount = message["topCount"] as? Int else {
                replyHandler(["entries": [], "localPlayer": NSNull()])
                return
            }
            print("[WC-Phone] loadLeaderboard id=\(leaderboardId) top=\(topCount)")
            Task {
                let result = await GameCenterManager.shared.loadLeaderboard(leaderboardId: leaderboardId, topCount: topCount)
                replyHandler(result)
            }

        case "loadBestSectorTimes":
            guard let trackId = message["trackId"] as? String else {
                replyHandler(["times": [-1.0, -1.0, -1.0]])
                return
            }
            Task {
                let times = await GameCenterManager.shared.loadGlobalBestSectorTimes(trackId: trackId)
                replyHandler(["times": times])
            }

        case "syncBestTimes":
            Task {
                let bestTimes = await GameCenterManager.shared.loadMyBestTimes()
                replyHandler(["bestTimes": bestTimes])
            }

        case "syncBestSectorTimes":
            Task {
                let bestSectorTimes = await GameCenterManager.shared.loadMyBestSectorTimes()
                replyHandler(["bestSectorTimes": bestSectorTimes])
            }

        case "loadSectorRecords":
            guard let trackId = message["trackId"] as? String else {
                replyHandler(["records": []])
                return
            }
            Task {
                let records = await GameCenterManager.shared.loadSectorRecords(trackId: trackId)
                let dicts: [[String: Any]] = records.map { record in
                    if let r = record {
                        return ["playerName": r.playerName, "time": r.time]
                    } else {
                        return ["playerName": "", "time": -1.0]
                    }
                }
                replyHandler(["records": dicts])
            }

        case "syncTrackBests":
            guard let trackId = message["trackId"] as? String else {
                replyHandler(["lapTime": -1.0, "sectorTimes": [-1.0, -1.0, -1.0]])
                return
            }
            Task {
                var lapTime: Double = -1.0
                if let meta = TrackRegistry.track(byId: trackId) {
                    if let lbs = try? await GKLeaderboard.loadLeaderboards(IDs: [meta.leaderboardId]),
                       let lb = lbs.first,
                       let (local, _, _) = try? await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1)),
                       let entry = local {
                        lapTime = Double(entry.score) / 1000.0
                    }
                }
                var sectors: [Double] = [-1.0, -1.0, -1.0]
                for i in 0..<3 {
                    if let lbs = try? await GKLeaderboard.loadLeaderboards(IDs: ["cp.sector.\(trackId).\(i)"]),
                       let lb = lbs.first,
                       let (local, _, _) = try? await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1)),
                       let entry = local {
                        sectors[i] = Double(entry.score) / 1000.0
                    }
                }
                replyHandler(["lapTime": lapTime, "sectorTimes": sectors])
            }

        case "loadChampionship":
            let topCount = message["topCount"] as? Int ?? 20
            Task {
                do {
                    let standings = try await SupabaseManager.shared.loadStandings(limit: topCount)
                    let standingsDicts = standings.map { $0.asDictionary }
                    let localPlayerId = GKLocalPlayer.local.gamePlayerID
                    var localPlayerDict: [String: Any]? = nil
                    if let local = standings.first(where: { $0.playerId == localPlayerId }) {
                        localPlayerDict = local.asDictionary
                    } else if GKLocalPlayer.local.isAuthenticated,
                              let local = try? await SupabaseManager.shared.loadPlayerStanding(playerId: localPlayerId) {
                        localPlayerDict = local.asDictionary
                    }
                    var reply: [String: Any] = ["entries": standingsDicts]
                    if let localPlayerDict {
                        reply["localPlayer"] = localPlayerDict
                    }
                    replyHandler(reply)
                } catch {
                    print("[WC-Phone] loadChampionship failed: \(error)")
                    replyHandler(["entries": [], "error": error.localizedDescription])
                }
            }

        case "submitLapTimeToSupabase":
            guard let trackId = message["trackId"] as? String,
                  let lapTimeMs = message["lapTimeMs"] as? Int else {
                replyHandler(["ok": false])
                return
            }
            let player = GKLocalPlayer.local
            guard player.isAuthenticated else {
                replyHandler(["ok": false])
                return
            }
            Task {
                try? await SupabaseManager.shared.submitLapTime(
                    playerId: player.gamePlayerID,
                    playerName: player.displayName,
                    trackId: trackId,
                    lapTimeMs: lapTimeMs
                )
                replyHandler(["ok": true])
            }

        case "syncAllTracks":
            Task {
                for track in TrackRegistry.allTracks {
                    await SupabaseManager.shared.syncTrackFromGameCenter(trackId: track.id)
                }
                replyHandler(["ok": true])
            }

        case "loadChampionshipDetail":
            guard let playerId = message["playerId"] as? String else {
                replyHandler(["error": "missing playerId"])
                return
            }
            Task {
                do {
                    if let detail = try await SupabaseManager.shared.loadPlayerDetail(playerId: playerId) {
                        replyHandler(["detail": detail.asDictionary])
                    } else {
                        replyHandler(["error": "player not found"])
                    }
                } catch {
                    print("[WC-Phone] loadChampionshipDetail failed: \(error)")
                    replyHandler(["error": error.localizedDescription])
                }
            }

        default:
            replyHandler(["error": "unknown type"])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let type = userInfo["type"] as? String else { return }
        print("[WC-Phone] received userInfo: \(type)")

        switch type {
        case "submitScore":
            guard let trackId = userInfo["trackId"] as? String,
                  let lapTime = userInfo["lapTime"] as? Double else { return }
            print("[WC-Phone] userInfo submitScore trackId=\(trackId) lapTime=\(lapTime)")
            // GC submission (existing, unchanged)
            Task { try? await GameCenterManager.shared.submitScore(trackId: trackId, lapTime: lapTime) }

            // Submit own lap time to Supabase (fire-and-forget)
            #if DEBUG
            guard trackId != "dev" else { break }
            #endif
            let player = GKLocalPlayer.local
            if player.isAuthenticated {
                let lapTimeMs = Int(lapTime * 1000)
                Task {
                    try? await SupabaseManager.shared.submitLapTime(
                        playerId: player.gamePlayerID,
                        playerName: player.displayName,
                        trackId: trackId,
                        lapTimeMs: lapTimeMs
                    )
                }
            }

        case "submitSectorTimes":
            guard let trackId = userInfo["trackId"] as? String,
                  let rawTimes = userInfo["times"] as? [Double] else { return }
            let times: [TimeInterval?] = rawTimes.map { $0 < 0 ? nil : $0 }
            print("[WC-Phone] userInfo submitSectorTimes trackId=\(trackId)")
            Task { try? await GameCenterManager.shared.submitSectorTimes(trackId: trackId, times: times) }

        default: break
        }
    }
}
