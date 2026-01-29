import CoreGraphics

struct TrackData: Codable {
    let points: [TrackPoint]
    let roadHalfWidth: CGFloat
    let totalLength: CGFloat
    let startSegmentIndex: Int
    let startHeading: CGFloat
}
