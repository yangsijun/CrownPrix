import Foundation

struct ChampionshipEntry: Identifiable {
    // Use player_id as Identifiable.id for correct SwiftUI list animations
    let id: String  // = player_id
    let rank: Int
    let playerId: String
    let playerName: String
    let totalPoints: Int
    let tracksEntered: Int
    let isLocalPlayer: Bool

    init(rank: Int, playerId: String, playerName: String, totalPoints: Int, tracksEntered: Int, isLocalPlayer: Bool) {
        self.id = playerId
        self.rank = rank
        self.playerId = playerId
        self.playerName = playerName
        self.totalPoints = totalPoints
        self.tracksEntered = tracksEntered
        self.isLocalPlayer = isLocalPlayer
    }

    var asDictionary: [String: Any] {
        ["rank": rank, "playerId": playerId, "playerName": playerName,
         "totalPoints": totalPoints, "tracksEntered": tracksEntered, "isLocalPlayer": isLocalPlayer]
    }

    static func from(_ dict: [String: Any]) -> ChampionshipEntry? {
        guard let rank = dict["rank"] as? Int,
              let playerId = dict["playerId"] as? String,
              let name = dict["playerName"] as? String,
              let points = dict["totalPoints"] as? Int,
              let tracks = dict["tracksEntered"] as? Int,
              let isLocal = dict["isLocalPlayer"] as? Bool else { return nil }
        return ChampionshipEntry(rank: rank, playerId: playerId, playerName: name,
                                  totalPoints: points, tracksEntered: tracks, isLocalPlayer: isLocal)
    }
}
