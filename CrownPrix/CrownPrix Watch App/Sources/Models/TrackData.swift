import CoreGraphics

struct InnerBarrier: Codable, Equatable {
    let start: TrackPoint
    let end: TrackPoint
}

struct TrackData: Codable {
    let points: [TrackPoint]
    let roadHalfWidth: CGFloat
    let totalLength: CGFloat
    let startSegmentIndex: Int
    let startHeading: CGFloat
    let innerBarriers: [InnerBarrier]

    init(
        points: [TrackPoint],
        roadHalfWidth: CGFloat,
        totalLength: CGFloat,
        startSegmentIndex: Int,
        startHeading: CGFloat,
        innerBarriers: [InnerBarrier] = []
    ) {
        self.points = points
        self.roadHalfWidth = roadHalfWidth
        self.totalLength = totalLength
        self.startSegmentIndex = startSegmentIndex
        self.startHeading = startHeading
        self.innerBarriers = innerBarriers
    }
}

extension TrackData {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            points: try container.decode([TrackPoint].self, forKey: .points),
            roadHalfWidth: try container.decode(CGFloat.self, forKey: .roadHalfWidth),
            totalLength: try container.decode(CGFloat.self, forKey: .totalLength),
            startSegmentIndex: try container.decode(Int.self, forKey: .startSegmentIndex),
            startHeading: try container.decode(CGFloat.self, forKey: .startHeading),
            innerBarriers: try container.decodeIfPresent([InnerBarrier].self, forKey: .innerBarriers) ?? []
        )
    }
}
