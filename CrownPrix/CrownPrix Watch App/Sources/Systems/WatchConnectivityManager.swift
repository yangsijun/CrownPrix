import Combine
import WatchConnectivity

enum WCError: Error {
    case phoneNotReachable
    case submissionFailed
    case timeout
}

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
            print("[WC-Watch] activated, reachable=\(session.isReachable)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            print("[WC-Watch] reachability changed: \(session.isReachable)")
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.syncAuthStatus(applicationContext)
        }
    }

    private static let playerIDKey = "gc.currentPlayerID"

    private func syncAuthStatus(_ context: [String: Any]) {
        if let authed = context["gcAuthenticated"] as? Bool {
            // Detect account change before setting isAuthenticated,
            // so no sync can run with stale local data.
            if authed, let newPlayerID = context["gcPlayerID"] as? String, !newPlayerID.isEmpty {
                let previousPlayerID = UserDefaults.standard.string(forKey: Self.playerIDKey)
                if let previous = previousPlayerID, previous != newPlayerID {
                    print("[WC-Watch] GC account changed: \(previous) → \(newPlayerID), clearing local records")
                    PersistenceManager.clearAllRecords()
                }
                UserDefaults.standard.set(newPlayerID, forKey: Self.playerIDKey)
            }
            print("[WC-Watch] GC auth status from phone: \(authed)")
            GameCenterManager.shared.isAuthenticated = authed
        }
    }

    func sendMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void, errorHandler: @escaping (Error) -> Void) {
        guard WCSession.default.isReachable else {
            print("[WC-Watch] sendMessage failed — phone not reachable")
            errorHandler(NSError(domain: "WCSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "iPhone not reachable"]))
            return
        }
        print("[WC-Watch] sendMessage: \(message["type"] ?? "?")")
        WCSession.default.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    func transferScore(trackId: String, lapTime: TimeInterval) {
        let info: [String: Any] = ["type": "submitScore", "trackId": trackId, "lapTime": lapTime]
        if WCSession.default.isReachable {
            print("[WC-Watch] transferScore via sendMessage: \(trackId) \(lapTime)")
            WCSession.default.sendMessage(info, replyHandler: { reply in
                print("[WC-Watch] transferScore reply: \(reply)")
            }, errorHandler: { error in
                print("[WC-Watch] transferScore sendMessage failed, falling back to transferUserInfo: \(error.localizedDescription)")
                WCSession.default.transferUserInfo(info)
            })
        } else {
            print("[WC-Watch] transferScore via transferUserInfo (not reachable): \(trackId) \(lapTime)")
            WCSession.default.transferUserInfo(info)
        }
    }

    func transferSectorTimes(trackId: String, times: [TimeInterval?]) {
        let rawTimes = times.map { $0 ?? -1.0 }
        let info: [String: Any] = ["type": "submitSectorTimes", "trackId": trackId, "times": rawTimes]
        if WCSession.default.isReachable {
            print("[WC-Watch] transferSectorTimes via sendMessage: \(trackId)")
            WCSession.default.sendMessage(info, replyHandler: { reply in
                print("[WC-Watch] transferSectorTimes reply: \(reply)")
            }, errorHandler: { error in
                print("[WC-Watch] transferSectorTimes sendMessage failed, falling back: \(error.localizedDescription)")
                WCSession.default.transferUserInfo(info)
            })
        } else {
            print("[WC-Watch] transferSectorTimes via transferUserInfo (not reachable): \(trackId)")
            WCSession.default.transferUserInfo(info)
        }
    }

    func transferScoreAsync(trackId: String, lapTime: TimeInterval) async throws {
        let info: [String: Any] = ["type": "submitScore", "trackId": trackId, "lapTime": lapTime]
        guard WCSession.default.isReachable else {
            print("[WC-Watch] transferScoreAsync falling back to transferUserInfo (not reachable)")
            WCSession.default.transferUserInfo(info)
            return
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                WCSession.default.sendMessage(info, replyHandler: { reply in
                    if reply["ok"] as? Bool == true {
                        print("[WC-Watch] transferScoreAsync confirmed: \(trackId)")
                        continuation.resume()
                    } else {
                        print("[WC-Watch] transferScoreAsync rejected: \(reply)")
                        continuation.resume(throwing: WCError.submissionFailed)
                    }
                }, errorHandler: { error in
                    print("[WC-Watch] transferScoreAsync error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                })
            }
        } catch {
            print("[WC-Watch] transferScoreAsync failed, falling back to transferUserInfo: \(error.localizedDescription)")
            WCSession.default.transferUserInfo(info)
        }
    }

    func transferSectorTimesAsync(trackId: String, times: [TimeInterval?]) async throws {
        let rawTimes = times.map { $0 ?? -1.0 }
        let info: [String: Any] = ["type": "submitSectorTimes", "trackId": trackId, "times": rawTimes]
        guard WCSession.default.isReachable else {
            print("[WC-Watch] transferSectorTimesAsync falling back to transferUserInfo")
            WCSession.default.transferUserInfo(info)
            return
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                WCSession.default.sendMessage(info, replyHandler: { reply in
                    if reply["ok"] as? Bool == true {
                        print("[WC-Watch] transferSectorTimesAsync confirmed: \(trackId)")
                        continuation.resume()
                    } else {
                        print("[WC-Watch] transferSectorTimesAsync rejected")
                        continuation.resume(throwing: WCError.submissionFailed)
                    }
                }, errorHandler: { error in
                    print("[WC-Watch] transferSectorTimesAsync error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                })
            }
        } catch {
            print("[WC-Watch] transferSectorTimesAsync failed, falling back to transferUserInfo: \(error.localizedDescription)")
            WCSession.default.transferUserInfo(info)
        }
    }
}
