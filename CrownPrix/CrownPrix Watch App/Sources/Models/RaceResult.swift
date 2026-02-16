import Foundation

struct RaceCompletionData {
    let trackId: String
    let lapTime: TimeInterval
    let sectorTimes: [TimeInterval?]
    let sectorColors: [SectorColor]
}

struct RaceResult {
    let trackId: String
    let lapTime: TimeInterval
    let date: Date
}
