import Foundation

struct TrackMetadata: Identifiable, Hashable {
    let id: String
    let displayName: String
    let country: String
    let flag: String

    var leaderboardId: String { LeaderboardIDs.lapTime(id) }
}
