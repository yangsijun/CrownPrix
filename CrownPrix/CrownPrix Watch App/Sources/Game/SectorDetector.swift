import Foundation

enum SectorColor {
    case white
    case yellow
    case green
    case purple
}

final class SectorDetector {
    private let boundaries: [Int]
    private let totalSegments: Int
    private(set) var currentSector: Int = 0
    private var sectorStartTime: TimeInterval = 0
    private(set) var sectorTimes: [TimeInterval?] = [nil, nil, nil]

    var onSectorComplete: ((Int, TimeInterval, SectorColor) -> Void)?

    private let trackId: String
    private var bestSectorTimes: [TimeInterval?]

    init(trackId: String, segmentCount: Int) {
        self.trackId = trackId
        self.totalSegments = segmentCount
        self.boundaries = SectorConfig.boundaries(for: trackId, segmentCount: segmentCount)
        self.bestSectorTimes = PersistenceManager.getBestSectorTimes(trackId: trackId)
    }

    func startRace() {
        currentSector = 0
        sectorStartTime = 0
        sectorTimes = [nil, nil, nil]
    }

    func update(currentSegmentIndex: Int, elapsedTime: TimeInterval) {
        let sector = sectorForSegment(currentSegmentIndex)
        guard sector != currentSector else { return }

        let sectorTime = elapsedTime - sectorStartTime
        let completedSector = currentSector

        sectorTimes[completedSector] = sectorTime

        let color = determineSectorColor(sector: completedSector, time: sectorTime)

        onSectorComplete?(completedSector, sectorTime, color)

        currentSector = sector
        sectorStartTime = elapsedTime
    }

    func saveBestSectorTimes() {
        PersistenceManager.saveBestSectorTimes(trackId: trackId, times: sectorTimes)
        bestSectorTimes = PersistenceManager.getBestSectorTimes(trackId: trackId)
    }

    private func sectorForSegment(_ index: Int) -> Int {
        if index < boundaries[0] { return 0 }
        if index < boundaries[1] { return 1 }
        return 2
    }

    private func determineSectorColor(sector: Int, time: TimeInterval) -> SectorColor {
        guard let best = bestSectorTimes[sector] else { return .green }
        if time < best { return .green }
        return .yellow
    }
}
