import Foundation

final class LapDetector {
    enum State {
        case preStart
        case racing
        case passedSector1
        case passedSector2
        case lapComplete
    }

    private(set) var state: State = .preStart
    private let startSegmentIndex: Int
    private let totalSegments: Int
    private let sectorBoundaries: [Int]
    private let window: Int
    var onLapComplete: (() -> Void)?
    private var previousSegmentIndex: Int

    init(trackId: String, trackData: TrackData) {
        self.totalSegments = trackData.points.count
        self.startSegmentIndex = trackData.startSegmentIndex
        self.sectorBoundaries = SectorConfig.boundaries(for: trackId, segmentCount: trackData.points.count)
        self.window = GameConfig.lapCrossSegmentWindow
        self.previousSegmentIndex = trackData.startSegmentIndex
    }

    func startRace() {
        state = .racing
    }

    func update(currentSegmentIndex: Int) {
        defer { previousSegmentIndex = currentSegmentIndex }
        let sector = sectorForSegment(currentSegmentIndex)

        switch state {
        case .preStart, .lapComplete:
            break
        case .racing:
            if sector == 1 {
                state = .passedSector1
            }
        case .passedSector1:
            if sector == 2 {
                state = .passedSector2
            }
        case .passedSector2:
            if didCrossStart(previous: previousSegmentIndex, current: currentSegmentIndex) {
                state = .lapComplete
                onLapComplete?()
            }
        }
    }

    func reset() {
        state = .preStart
    }

    private func sectorForSegment(_ index: Int) -> Int {
        if index < sectorBoundaries[0] { return 0 }
        if index < sectorBoundaries[1] { return 1 }
        return 2
    }

    private func didCrossStart(previous: Int, current: Int) -> Bool {
        let nearEnd = previous >= totalSegments - window
        let nearStart = current <= window
        return nearEnd && nearStart
    }
}
