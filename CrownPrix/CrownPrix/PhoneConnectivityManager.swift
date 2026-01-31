import WatchConnectivity

final class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendAuthStatus(_ authenticated: Bool) {
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext(["gcAuthenticated": authenticated])
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

        switch type {
        case "submitScore":
            guard let trackId = message["trackId"] as? String,
                  let lapTime = message["lapTime"] as? Double else {
                replyHandler(["ok": false])
                return
            }
            GameCenterManager.shared.submitScore(trackId: trackId, lapTime: lapTime)
            replyHandler(["ok": true])

        case "submitSectorTimes":
            guard let trackId = message["trackId"] as? String,
                  let rawTimes = message["times"] as? [Double] else {
                replyHandler(["ok": false])
                return
            }
            let times: [TimeInterval?] = rawTimes.map { $0 < 0 ? nil : $0 }
            GameCenterManager.shared.submitSectorTimes(trackId: trackId, times: times)
            replyHandler(["ok": true])

        case "loadLeaderboard":
            guard let leaderboardId = message["leaderboardId"] as? String,
                  let topCount = message["topCount"] as? Int else {
                replyHandler(["entries": [], "localPlayer": NSNull()])
                return
            }
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

        default:
            replyHandler(["error": "unknown type"])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "submitScore":
            guard let trackId = userInfo["trackId"] as? String,
                  let lapTime = userInfo["lapTime"] as? Double else { return }
            GameCenterManager.shared.submitScore(trackId: trackId, lapTime: lapTime)

        case "submitSectorTimes":
            guard let trackId = userInfo["trackId"] as? String,
                  let rawTimes = userInfo["times"] as? [Double] else { return }
            let times: [TimeInterval?] = rawTimes.map { $0 < 0 ? nil : $0 }
            GameCenterManager.shared.submitSectorTimes(trackId: trackId, times: times)

        default: break
        }
    }
}
