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
    private let window: Int
    var onLapComplete: (() -> Void)?
    private var previousSegmentIndex: Int

    init(trackData: TrackData) {
        self.totalSegments = trackData.points.count
        self.startSegmentIndex = trackData.startSegmentIndex
        self.halfLapSegmentIndex = (trackData.startSegmentIndex + totalSegments / 2) % totalSegments
        self.window = GameConfig.lapCrossSegmentWindow
        self.previousSegmentIndex = trackData.startSegmentIndex
    }

    func startRace() {
        state = .racing
    }

    func update(currentSegmentIndex: Int) {
        defer { previousSegmentIndex = currentSegmentIndex }

        switch state {
        case .preStart, .lapComplete:
            break
        case .racing:
            if isNearHalfLap(currentSegmentIndex) {
                state = .halfLap
            }
        case .halfLap:
            if didCrossStart(previous: previousSegmentIndex, current: currentSegmentIndex) {
                state = .lapComplete
                onLapComplete?()
            }
        }
    }

    func reset() {
        state = .preStart
    }

    private func didCrossStart(previous: Int, current: Int) -> Bool {
        let nearEnd = previous >= totalSegments - window
        let nearStart = current <= window
        return nearEnd && nearStart
    }

    private func circularDistance(_ a: Int, _ b: Int) -> Int {
        let d = (a - b + totalSegments) % totalSegments
        return min(d, totalSegments - d)
    }

    private func isNearHalfLap(_ idx: Int) -> Bool {
        circularDistance(idx, halfLapSegmentIndex) < window
    }
}
