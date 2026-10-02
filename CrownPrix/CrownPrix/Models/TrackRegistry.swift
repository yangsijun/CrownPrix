import Foundation

enum TrackRegistry {
    static let allTracks: [TrackMetadata] = {
        var tracks: [TrackMetadata] = [
            TrackMetadata(id: "albertpark", displayName: "Albert Park Circuit", country: "Australia", flag: "🇦🇺"),
            TrackMetadata(id: "shanghai", displayName: "Shanghai International Circuit", country: "China", flag: "🇨🇳"),
            TrackMetadata(id: "suzuka", displayName: "Suzuka International Racing Course", country: "Japan", flag: "🇯🇵"),
            TrackMetadata(id: "bahrain", displayName: "Bahrain International Circuit", country: "Bahrain", flag: "🇧🇭"),
            TrackMetadata(id: "jeddah", displayName: "Jeddah Corniche Circuit", country: "Saudi Arabia", flag: "🇸🇦"),
            TrackMetadata(id: "miami", displayName: "Miami International Autodrome", country: "USA", flag: "🇺🇸"),
            TrackMetadata(id: "gillesvilleneuve", displayName: "Circuit Gilles Villeneuve", country: "Canada", flag: "🇨🇦"),
            TrackMetadata(id: "monaco", displayName: "Circuit de Monaco", country: "Monaco", flag: "🇲🇨"),
            TrackMetadata(id: "catalunya", displayName: "Circuit de Barcelona-Catalunya", country: "Spain", flag: "🇪🇸"),
            TrackMetadata(id: "redbull", displayName: "Red Bull Ring", country: "Austria", flag: "🇦🇹"),
            TrackMetadata(id: "silverstone", displayName: "Silverstone Circuit", country: "UK", flag: "🇬🇧"),
            TrackMetadata(id: "spa", displayName: "Circuit de Spa-Francorchamps", country: "Belgium", flag: "🇧🇪"),
            TrackMetadata(id: "hungaroring", displayName: "Hungaroring", country: "Hungary", flag: "🇭🇺"),
            TrackMetadata(id: "zandvoort", displayName: "Circuit Zandvoort", country: "Netherlands", flag: "🇳🇱"),
            TrackMetadata(id: "monza", displayName: "Autodromo Nazionale Monza", country: "Italy", flag: "🇮🇹"),
            TrackMetadata(id: "madring", displayName: "Circuito de Madring", country: "Spain", flag: "🇪🇸"),
            TrackMetadata(id: "baku", displayName: "Baku City Circuit", country: "Azerbaijan", flag: "🇦🇿"),
            TrackMetadata(id: "marinabay", displayName: "Marina Bay Street Circuit", country: "Singapore", flag: "🇸🇬"),
            TrackMetadata(id: "americas", displayName: "Circuit of the Americas", country: "USA", flag: "🇺🇸"),
            TrackMetadata(id: "hermanosrodriguez", displayName: "Autódromo Hermanos Rodríguez", country: "Mexico", flag: "🇲🇽"),
            TrackMetadata(id: "interlagos", displayName: "Autódromo José Carlos Pace", country: "Brazil", flag: "🇧🇷"),
            TrackMetadata(id: "lasvegas", displayName: "Las Vegas Strip Circuit", country: "USA", flag: "🇺🇸"),
            TrackMetadata(id: "losail", displayName: "Losail International Circuit", country: "Qatar", flag: "🇶🇦"),
            TrackMetadata(id: "abudhabi", displayName: "Yas Marina Circuit", country: "UAE", flag: "🇦🇪"),
        ]
        #if DEBUG
        tracks.append(contentsOf: [
            TrackMetadata(id: "sepang", displayName: "Sepang International Circuit", country: "Malaysia", flag: "🇲🇾"),
            TrackMetadata(id: "imola", displayName: "Autodromo Enzo e Dino Ferrari", country: "Italy", flag: "🇮🇹"),
            TrackMetadata(id: "portimao", displayName: "Algarve International Circuit", country: "Portugal", flag: "🇵🇹"),
        ])
        tracks.insert(TrackMetadata(id: "dev", displayName: "Dev Circuit", country: "Debug", flag: "🏴"), at: 0)
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
