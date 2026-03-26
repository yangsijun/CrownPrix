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

struct ChampionshipDetail {
    let playerId: String
    let playerName: String
    let totalPoints: Int
    let tracksEntered: Int
    let rank: Int
    let trackResults: [TrackResult]

    struct TrackResult: Identifiable {
        var id: String { trackId }
        let trackId: String
        let trackName: String
        let flag: String
        let rank: Int
        let points: Int
        let lapTimeMs: Int
    }

    var asDictionary: [String: Any] {
        [
            "playerId": playerId,
            "playerName": playerName,
            "totalPoints": totalPoints,
            "tracksEntered": tracksEntered,
            "rank": rank,
            "trackResults": trackResults.map { [
                "trackId": $0.trackId, "trackName": $0.trackName, "flag": $0.flag,
                "rank": $0.rank, "points": $0.points, "lapTimeMs": $0.lapTimeMs
            ] }
        ]
    }

    static func from(_ dict: [String: Any]) -> ChampionshipDetail? {
        guard let playerId = dict["playerId"] as? String,
              let playerName = dict["playerName"] as? String,
              let totalPoints = dict["totalPoints"] as? Int,
              let tracksEntered = dict["tracksEntered"] as? Int,
              let rank = dict["rank"] as? Int,
              let results = dict["trackResults"] as? [[String: Any]] else { return nil }
        let trackResults = results.compactMap { d -> TrackResult? in
            guard let tid = d["trackId"] as? String,
                  let tn = d["trackName"] as? String,
                  let f = d["flag"] as? String,
                  let r = d["rank"] as? Int,
                  let p = d["points"] as? Int,
                  let lt = d["lapTimeMs"] as? Int else { return nil }
            return TrackResult(trackId: tid, trackName: tn, flag: f, rank: r, points: p, lapTimeMs: lt)
        }
        return ChampionshipDetail(playerId: playerId, playerName: playerName, totalPoints: totalPoints, tracksEntered: tracksEntered, rank: rank, trackResults: trackResults)
    }
}
