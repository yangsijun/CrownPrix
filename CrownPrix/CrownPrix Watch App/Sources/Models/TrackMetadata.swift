import Foundation

struct TrackMetadata: Identifiable, Hashable {
    let id: String
    let displayName: String
    let country: String
    let flag: String
    let svgFilename: String
    let racingDirectionReversed: Bool

    var leaderboardId: String { LeaderboardIDs.lapTime(id) }
}
