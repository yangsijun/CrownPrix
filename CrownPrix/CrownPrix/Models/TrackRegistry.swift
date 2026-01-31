import Foundation

enum TrackRegistry {
    static let allTracks: [TrackMetadata] = [
        TrackMetadata(id: "albertpark", displayName: "Albert Park Circuit", country: "Australia", flag: "🇦🇺", leaderboardId: "cp.laptime.albertpark"),
        TrackMetadata(id: "shanghai", displayName: "Shanghai International Circuit", country: "China", flag: "🇨🇳", leaderboardId: "cp.laptime.shanghai"),
        TrackMetadata(id: "suzuka", displayName: "Suzuka International Racing Course", country: "Japan", flag: "🇯🇵", leaderboardId: "cp.laptime.suzuka"),
        TrackMetadata(id: "bahrain", displayName: "Bahrain International Circuit", country: "Bahrain", flag: "🇧🇭", leaderboardId: "cp.laptime.bahrain"),
        TrackMetadata(id: "jeddah", displayName: "Jeddah Corniche Circuit", country: "Saudi Arabia", flag: "🇸🇦", leaderboardId: "cp.laptime.jeddah"),
        TrackMetadata(id: "miami", displayName: "Miami International Autodrome", country: "USA", flag: "🇺🇸", leaderboardId: "cp.laptime.miami"),
        TrackMetadata(id: "gillesvilleneuve", displayName: "Circuit Gilles Villeneuve", country: "Canada", flag: "🇨🇦", leaderboardId: "cp.laptime.gillesvilleneuve"),
        TrackMetadata(id: "monaco", displayName: "Circuit de Monaco", country: "Monaco", flag: "🇲🇨", leaderboardId: "cp.laptime.monaco"),
        TrackMetadata(id: "catalunya", displayName: "Circuit de Barcelona-Catalunya", country: "Spain", flag: "🇪🇸", leaderboardId: "cp.laptime.catalunya"),
        TrackMetadata(id: "redbull", displayName: "Red Bull Ring", country: "Austria", flag: "🇦🇹", leaderboardId: "cp.laptime.redbull"),
        TrackMetadata(id: "silverstone", displayName: "Silverstone Circuit", country: "UK", flag: "🇬🇧", leaderboardId: "cp.laptime.silverstone"),
        TrackMetadata(id: "spa", displayName: "Circuit de Spa-Francorchamps", country: "Belgium", flag: "🇧🇪", leaderboardId: "cp.laptime.spa"),
        TrackMetadata(id: "hungaroring", displayName: "Hungaroring", country: "Hungary", flag: "🇭🇺", leaderboardId: "cp.laptime.hungaroring"),
        TrackMetadata(id: "zandvoort", displayName: "Circuit Zandvoort", country: "Netherlands", flag: "🇳🇱", leaderboardId: "cp.laptime.zandvoort"),
        TrackMetadata(id: "monza", displayName: "Autodromo Nazionale Monza", country: "Italy", flag: "🇮🇹", leaderboardId: "cp.laptime.monza"),
        TrackMetadata(id: "madring", displayName: "Circuito de Madring", country: "Spain", flag: "🇪🇸", leaderboardId: "cp.laptime.madring"),
        TrackMetadata(id: "baku", displayName: "Baku City Circuit", country: "Azerbaijan", flag: "🇦🇿", leaderboardId: "cp.laptime.baku"),
        TrackMetadata(id: "marinabay", displayName: "Marina Bay Street Circuit", country: "Singapore", flag: "🇸🇬", leaderboardId: "cp.laptime.marinabay"),
        TrackMetadata(id: "americas", displayName: "Circuit of the Americas", country: "USA", flag: "🇺🇸", leaderboardId: "cp.laptime.americas"),
        TrackMetadata(id: "hermanosrodriguez", displayName: "Autódromo Hermanos Rodríguez", country: "Mexico", flag: "🇲🇽", leaderboardId: "cp.laptime.hermanosrodriguez"),
        TrackMetadata(id: "interlagos", displayName: "Autódromo José Carlos Pace", country: "Brazil", flag: "🇧🇷", leaderboardId: "cp.laptime.interlagos"),
        TrackMetadata(id: "lasvegas", displayName: "Las Vegas Strip Circuit", country: "USA", flag: "🇺🇸", leaderboardId: "cp.laptime.lasvegas"),
        TrackMetadata(id: "losail", displayName: "Losail International Circuit", country: "Qatar", flag: "🇶🇦", leaderboardId: "cp.laptime.losail"),
        TrackMetadata(id: "abudhabi", displayName: "Yas Marina Circuit", country: "UAE", flag: "🇦🇪", leaderboardId: "cp.laptime.abudhabi"),
    ]

    static func track(byId id: String) -> TrackMetadata? {
        allTracks.first { $0.id == id }
    }

    static var sortedByName: [TrackMetadata] {
        allTracks.sorted { $0.displayName < $1.displayName }
    }
}
