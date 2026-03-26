import Foundation
import GameKit

struct PendingSubmission: Codable, Identifiable {
    let id: UUID
    let playerId: String
    let playerName: String
    let trackId: String
    let lapTimeMs: Int
    var retryCount: Int
    let createdAt: Date
}

final class SupabaseRetryQueue {
    static let shared = SupabaseRetryQueue()
    private let storageKey = "supabase.retryQueue"
    private let maxDepth = 100
    private let maxRetries = 3

    private init() {}

    func enqueue(playerId: String, playerName: String, trackId: String, lapTimeMs: Int) {
        var queue = load()
        let item = PendingSubmission(
            id: UUID(), playerId: playerId, playerName: playerName,
            trackId: trackId, lapTimeMs: lapTimeMs, retryCount: 0, createdAt: Date()
        )
        queue.append(item)
        while queue.count > maxDepth { queue.removeFirst() }
        save(queue)
    }

    /// Enqueue when GC is not yet authenticated (cold-launch didReceiveUserInfo).
    /// Player identity will be resolved at drain time from GKLocalPlayer.local.
    func enqueueDeferred(trackId: String, lapTimeMs: Int) {
        enqueue(playerId: "", playerName: "", trackId: trackId, lapTimeMs: lapTimeMs)
    }

    func drain() async {
        let player = GKLocalPlayer.local
        guard player.isAuthenticated else { return }

        var queue = load()
        var remaining: [PendingSubmission] = []

        for var item in queue {
            let pid = item.playerId.isEmpty ? player.gamePlayerID : item.playerId
            let pname = item.playerName.isEmpty ? player.displayName : item.playerName

            do {
                try await SupabaseManager.shared.submitLapTime(
                    playerId: pid, playerName: pname,
                    trackId: item.trackId, lapTimeMs: item.lapTimeMs
                )
            } catch {
                item.retryCount += 1
                if item.retryCount < maxRetries {
                    remaining.append(item)
                }
            }
        }
        save(remaining)
    }

    func clearAll() {
        save([])
    }

    private func load() -> [PendingSubmission] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let queue = try? JSONDecoder().decode([PendingSubmission].self, from: data) else {
            return []
        }
        return queue
    }

    private func save(_ queue: [PendingSubmission]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
