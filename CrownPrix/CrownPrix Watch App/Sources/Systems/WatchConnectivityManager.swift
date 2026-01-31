import Combine
import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    @Published var isPhoneReachable = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            self.syncAuthStatus(session.receivedApplicationContext)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.syncAuthStatus(applicationContext)
        }
    }

    private func syncAuthStatus(_ context: [String: Any]) {
        if let authed = context["gcAuthenticated"] as? Bool {
            GameCenterManager.shared.isAuthenticated = authed
        }
    }

    func sendMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void, errorHandler: @escaping (Error) -> Void) {
        guard WCSession.default.isReachable else {
            errorHandler(NSError(domain: "WCSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "iPhone not reachable"]))
            return
        }
        WCSession.default.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    func transferScore(trackId: String, lapTime: TimeInterval) {
        let info: [String: Any] = ["type": "submitScore", "trackId": trackId, "lapTime": lapTime]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(info, replyHandler: nil, errorHandler: { _ in
                WCSession.default.transferUserInfo(info)
            })
        } else {
            WCSession.default.transferUserInfo(info)
        }
    }

    func transferSectorTimes(trackId: String, times: [TimeInterval?]) {
        let rawTimes = times.map { $0 ?? -1.0 }
        let info: [String: Any] = ["type": "submitSectorTimes", "trackId": trackId, "times": rawTimes]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(info, replyHandler: nil, errorHandler: { _ in
                WCSession.default.transferUserInfo(info)
            })
        } else {
            WCSession.default.transferUserInfo(info)
        }
    }
}
