import Foundation

enum TrackRegistry {
    static let allTracks: [TrackMetadata] = {
        var tracks: [TrackMetadata] = [
            TrackMetadata(id: "albertpark", displayName: "Albert Park Circuit", country: "Australia", flag: "🇦🇺",
                          svgFilename: "RaceCircuitAlbertPark", racingDirectionReversed: false),
            TrackMetadata(id: "shanghai", displayName: "Shanghai International Circuit", country: "China", flag: "🇨🇳",
                          svgFilename: "RaceCircuitShanghai", racingDirectionReversed: false),
            TrackMetadata(id: "suzuka", displayName: "Suzuka International Racing Course", country: "Japan", flag: "🇯🇵",
                          svgFilename: "RaceCircuitSuzuka", racingDirectionReversed: false),
            TrackMetadata(id: "bahrain", displayName: "Bahrain International Circuit", country: "Bahrain", flag: "🇧🇭",
                          svgFilename: "RaceCircuitBahrain", racingDirectionReversed: false),
            TrackMetadata(id: "jeddah", displayName: "Jeddah Corniche Circuit", country: "Saudi Arabia", flag: "🇸🇦",
                          svgFilename: "RaceCircuitJeddah", racingDirectionReversed: false),
            TrackMetadata(id: "miami", displayName: "Miami International Autodrome", country: "USA", flag: "🇺🇸",
                          svgFilename: "RaceCircuitMiami", racingDirectionReversed: false),
            TrackMetadata(id: "gillesvilleneuve", displayName: "Circuit Gilles Villeneuve", country: "Canada", flag: "🇨🇦",
                          svgFilename: "RaceCircuitGillesVilleneuve", racingDirectionReversed: false),
            TrackMetadata(id: "monaco", displayName: "Circuit de Monaco", country: "Monaco", flag: "🇲🇨",
                          svgFilename: "RaceCircuitMonaco", racingDirectionReversed: false),
            TrackMetadata(id: "catalunya", displayName: "Circuit de Barcelona-Catalunya", country: "Spain", flag: "🇪🇸",
                          svgFilename: "RaceCircuitCatalunya", racingDirectionReversed: false),
            TrackMetadata(id: "redbull", displayName: "Red Bull Ring", country: "Austria", flag: "🇦🇹",
                          svgFilename: "RaceCircuitRedBull", racingDirectionReversed: false),
            TrackMetadata(id: "silverstone", displayName: "Silverstone Circuit", country: "UK", flag: "🇬🇧",
                          svgFilename: "RaceCircuitSilverstone", racingDirectionReversed: false),
            TrackMetadata(id: "spa", displayName: "Circuit de Spa-Francorchamps", country: "Belgium", flag: "🇧🇪",
                          svgFilename: "RaceCircuitSpa", racingDirectionReversed: false),
            TrackMetadata(id: "hungaroring", displayName: "Hungaroring", country: "Hungary", flag: "🇭🇺",
                          svgFilename: "RaceCircuitHungaroring", racingDirectionReversed: false),
            TrackMetadata(id: "zandvoort", displayName: "Circuit Zandvoort", country: "Netherlands", flag: "🇳🇱",
                          svgFilename: "RaceCircuitZandvoort", racingDirectionReversed: false),
            TrackMetadata(id: "monza", displayName: "Autodromo Nazionale Monza", country: "Italy", flag: "🇮🇹",
                          svgFilename: "RaceCircuitMonza", racingDirectionReversed: false),
            TrackMetadata(id: "madring", displayName: "Circuito de Madring", country: "Spain", flag: "🇪🇸",
                          svgFilename: "RaceCircuitMadring", racingDirectionReversed: false),
            TrackMetadata(id: "baku", displayName: "Baku City Circuit", country: "Azerbaijan", flag: "🇦🇿",
                          svgFilename: "RaceCircuitBaku", racingDirectionReversed: false),
            TrackMetadata(id: "marinabay", displayName: "Marina Bay Street Circuit", country: "Singapore", flag: "🇸🇬",
                          svgFilename: "RaceCircuitMarinaBay", racingDirectionReversed: false),
            TrackMetadata(id: "americas", displayName: "Circuit of the Americas", country: "USA", flag: "🇺🇸",
                          svgFilename: "RaceCircuitAmericas", racingDirectionReversed: false),
            TrackMetadata(id: "hermanosrodriguez", displayName: "Autódromo Hermanos Rodríguez", country: "Mexico", flag: "🇲🇽",
                          svgFilename: "RaceCircuitHermanosRodriguez", racingDirectionReversed: false),
            TrackMetadata(id: "interlagos", displayName: "Autódromo José Carlos Pace", country: "Brazil", flag: "🇧🇷",
                          svgFilename: "RaceCircuitInterlagos", racingDirectionReversed: false),
            TrackMetadata(id: "lasvegas", displayName: "Las Vegas Strip Circuit", country: "USA", flag: "🇺🇸",
                          svgFilename: "RaceCircuitLasVegas", racingDirectionReversed: false),
            TrackMetadata(id: "losail", displayName: "Losail International Circuit", country: "Qatar", flag: "🇶🇦",
                          svgFilename: "RaceCircuitLosail", racingDirectionReversed: false),
            TrackMetadata(id: "abudhabi", displayName: "Yas Marina Circuit", country: "UAE", flag: "🇦🇪",
                          svgFilename: "RaceCircuitAbuDhabi", racingDirectionReversed: false),
        ]
        #if DEBUG
        tracks.append(contentsOf: [
            TrackMetadata(id: "sepang", displayName: "Sepang International Circuit", country: "Malaysia", flag: "🇲🇾",
                          svgFilename: "RaceCircuitSepang", racingDirectionReversed: false),
            TrackMetadata(id: "imola", displayName: "Autodromo Enzo e Dino Ferrari", country: "Italy", flag: "🇮🇹",
                          svgFilename: "RaceCircuitImola", racingDirectionReversed: false),
            TrackMetadata(id: "portimao", displayName: "Algarve International Circuit", country: "Portugal", flag: "🇵🇹",
                          svgFilename: "RaceCircuitPortimao", racingDirectionReversed: false),
        ])
        tracks.insert(TrackMetadata(
            id: "dev",
            displayName: "Dev Circuit",
            country: "Debug",
            flag: "🏴",
            svgFilename: "RaceCircuitBahrain",
            racingDirectionReversed: false
        ), at: 0)
        #endif
        return tracks
    }()

    // Keep these IDs isolated even when a Release phone receives a Debug watch message.
    private static let developmentTrackIDs: Set<String> = ["dev", "sepang", "imola", "portimao"]

    static func isDevelopmentTrack(_ id: String) -> Bool {
        developmentTrackIDs.contains(id)
    }

    static func isDevelopmentLeaderboard(_ leaderboardId: String) -> Bool {
        developmentTrackIDs.contains { id in
            leaderboardId == LeaderboardIDs.lapTime(id)
                || (0..<3).contains { leaderboardId == LeaderboardIDs.sector(id, $0) }
        }
    }

    static var competitiveTracks: [TrackMetadata] {
        allTracks.filter { !isDevelopmentTrack($0.id) }
    }

    static func track(byId id: String) -> TrackMetadata? {
        allTracks.first { $0.id == id }
    }

    static var sortedByName: [TrackMetadata] {
        allTracks.sorted { $0.displayName < $1.displayName }
    }
}
