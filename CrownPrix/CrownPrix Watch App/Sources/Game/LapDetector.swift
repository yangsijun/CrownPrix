import Foundation

final class LapDetector {
    enum State {
        case preStart
        case racing
        case halfLap
        case lapComplete
    }

    private(set) var state: State = .preStart
    private let startSegmentIndex: Int
    private let halfLapSegmentIndex: Int
    private let totalSegments: Int
    var onLapComplete: ((TimeInterval) -> Void)?
    private var lapStartTime: TimeInterval = 0

    init(trackData: TrackData) {
        self.totalSegments = trackData.points.count
        self.startSegmentIndex = trackData.startSegmentIndex
        self.halfLapSegmentIndex = (trackData.startSegmentIndex + totalSegments / 2) % totalSegments
    }

    func startRace(at time: TimeInterval) {
        state = .racing
        lapStartTime = time
    }

    func update(currentSegmentIndex: Int, currentTime: TimeInterval) {
        switch state {
        case .preStart, .lapComplete:
            break
        case .racing:
            if isNearHalfLap(currentSegmentIndex) {
                state = .halfLap
            }
        case .halfLap:
            if isNearStart(currentSegmentIndex) {
                state = .lapComplete
                onLapComplete?(currentTime - lapStartTime)
            }
        }
    }

    func reset() {
        state = .preStart
    }

    private func circularDistance(_ a: Int, _ b: Int) -> Int {
        let d = (a - b + totalSegments) % totalSegments
        return min(d, totalSegments - d)
    }

    private func isNearHalfLap(_ idx: Int) -> Bool {
        circularDistance(idx, halfLapSegmentIndex) < GameConfig.lapCrossSegmentWindow
    }

    private func isNearStart(_ idx: Int) -> Bool {
        circularDistance(idx, startSegmentIndex) < GameConfig.lapCrossSegmentWindow
    }
}
