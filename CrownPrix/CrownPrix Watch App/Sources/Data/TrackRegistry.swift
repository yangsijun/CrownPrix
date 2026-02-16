import Foundation

enum TrackRegistry {
    static let allTracks: [TrackMetadata] = {
        var tracks: [TrackMetadata] = [
            TrackMetadata(id: "albertpark", displayName: "Albert Park Circuit", country: "Australia", flag: "🇦🇺",
                          svgFilename: "RaceCircuitAlbertPark", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.albertpark"),
            TrackMetadata(id: "shanghai", displayName: "Shanghai International Circuit", country: "China", flag: "🇨🇳",
                          svgFilename: "RaceCircuitShanghai", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.shanghai"),
            TrackMetadata(id: "suzuka", displayName: "Suzuka International Racing Course", country: "Japan", flag: "🇯🇵",
                          svgFilename: "RaceCircuitSuzuka", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.suzuka"),
            TrackMetadata(id: "bahrain", displayName: "Bahrain International Circuit", country: "Bahrain", flag: "🇧🇭",
                          svgFilename: "RaceCircuitBahrain", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.bahrain"),
            TrackMetadata(id: "jeddah", displayName: "Jeddah Corniche Circuit", country: "Saudi Arabia", flag: "🇸🇦",
                          svgFilename: "RaceCircuitJeddah", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.jeddah"),
            TrackMetadata(id: "miami", displayName: "Miami International Autodrome", country: "USA", flag: "🇺🇸",
                          svgFilename: "RaceCircuitMiami", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.miami"),
            TrackMetadata(id: "gillesvilleneuve", displayName: "Circuit Gilles Villeneuve", country: "Canada", flag: "🇨🇦",
                          svgFilename: "RaceCircuitGillesVilleneuve", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.gillesvilleneuve"),
            TrackMetadata(id: "monaco", displayName: "Circuit de Monaco", country: "Monaco", flag: "🇲🇨",
                          svgFilename: "RaceCircuitMonaco", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.monaco"),
            TrackMetadata(id: "catalunya", displayName: "Circuit de Barcelona-Catalunya", country: "Spain", flag: "🇪🇸",
                          svgFilename: "RaceCircuitCatalunya", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.catalunya"),
            TrackMetadata(id: "redbull", displayName: "Red Bull Ring", country: "Austria", flag: "🇦🇹",
                          svgFilename: "RaceCircuitRedBull", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.redbull"),
            TrackMetadata(id: "silverstone", displayName: "Silverstone Circuit", country: "UK", flag: "🇬🇧",
                          svgFilename: "RaceCircuitSilverstone", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.silverstone"),
            TrackMetadata(id: "spa", displayName: "Circuit de Spa-Francorchamps", country: "Belgium", flag: "🇧🇪",
                          svgFilename: "RaceCircuitSpa", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.spa"),
            TrackMetadata(id: "hungaroring", displayName: "Hungaroring", country: "Hungary", flag: "🇭🇺",
                          svgFilename: "RaceCircuitHungaroring", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.hungaroring"),
            TrackMetadata(id: "zandvoort", displayName: "Circuit Zandvoort", country: "Netherlands", flag: "🇳🇱",
                          svgFilename: "RaceCircuitZandvoort", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.zandvoort"),
            TrackMetadata(id: "monza", displayName: "Autodromo Nazionale Monza", country: "Italy", flag: "🇮🇹",
                          svgFilename: "RaceCircuitMonza", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.monza"),
            TrackMetadata(id: "madring", displayName: "Circuito de Madring", country: "Spain", flag: "🇪🇸",
                          svgFilename: "RaceCircuitMadring", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.madring"),
            TrackMetadata(id: "baku", displayName: "Baku City Circuit", country: "Azerbaijan", flag: "🇦🇿",
                          svgFilename: "RaceCircuitBaku", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.baku"),
            TrackMetadata(id: "marinabay", displayName: "Marina Bay Street Circuit", country: "Singapore", flag: "🇸🇬",
                          svgFilename: "RaceCircuitMarinaBay", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.marinabay"),
            TrackMetadata(id: "americas", displayName: "Circuit of the Americas", country: "USA", flag: "🇺🇸",
                          svgFilename: "RaceCircuitAmericas", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.americas"),
            TrackMetadata(id: "hermanosrodriguez", displayName: "Autódromo Hermanos Rodríguez", country: "Mexico", flag: "🇲🇽",
                          svgFilename: "RaceCircuitHermanosRodriguez", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.hermanosrodriguez"),
            TrackMetadata(id: "interlagos", displayName: "Autódromo José Carlos Pace", country: "Brazil", flag: "🇧🇷",
                          svgFilename: "RaceCircuitInterlagos", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.interlagos"),
            TrackMetadata(id: "lasvegas", displayName: "Las Vegas Strip Circuit", country: "USA", flag: "🇺🇸",
                          svgFilename: "RaceCircuitLasVegas", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.lasvegas"),
            TrackMetadata(id: "losail", displayName: "Losail International Circuit", country: "Qatar", flag: "🇶🇦",
                          svgFilename: "RaceCircuitLosail", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.losail"),
            TrackMetadata(id: "abudhabi", displayName: "Yas Marina Circuit", country: "UAE", flag: "🇦🇪",
                          svgFilename: "RaceCircuitAbuDhabi", racingDirectionReversed: false,
                          leaderboardId: "cp.laptime.abudhabi"),
        ]
        #if DEBUG
        tracks.insert(TrackMetadata(
            id: "dev",
            displayName: "Dev Circuit",
            country: "Debug",
            flag: "🏴",
            svgFilename: "RaceCircuitBahrain",
            racingDirectionReversed: false,
            leaderboardId: "cp.laptime.dev"
        ), at: 0)
        #endif
        return tracks
    }()

    static func track(byId id: String) -> TrackMetadata? {
        allTracks.first { $0.id == id }
    }

    static var sortedByName: [TrackMetadata] {
        allTracks.sorted { $0.displayName < $1.displayName }
    }
}
