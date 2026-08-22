import Foundation

/// Central builder for Game Center leaderboard vendor IDs.
///
/// `generation` is the anti-cheat reset counter. Bumping it points the app at a
/// brand-new set of leaderboards (old app versions keep submitting to the old,
/// now-hidden boards) and triggers a one-time wipe of locally stored records so
/// only times driven on the current generation can be uploaded.
/// After bumping: run scripts/create_leaderboards.py to create the new boards,
/// then scripts/archive_leaderboards.py once the release is live.
enum LeaderboardIDs {
    static let generation = 2

    private static let prefix = "cp\(generation)"

    static func lapTime(_ trackId: String) -> String {
        "\(prefix).laptime.\(trackId)"
    }

    static func sector(_ trackId: String, _ sectorIndex: Int) -> String {
        "\(prefix).sector.\(trackId).\(sectorIndex)"
    }
}
