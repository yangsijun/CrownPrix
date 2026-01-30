import Foundation
import CoreGraphics

enum TrackLoader {
    static func loadTrackData(trackId: String, bundle: Bundle = .main) throws -> TrackData {
        guard let url = BundleHelper.trackDataURL(trackId: trackId, bundle: bundle) else {
            throw TrackPipelineError.noPathElementFound(svgFilename: trackId)
        }
        let data = try Data(contentsOf: url)
        let raw = try JSONDecoder().decode(TrackData.self, from: data)
        let reversed = applyDirectionReverse(raw, trackId: trackId)
        return applyStartOffset(reversed, trackId: trackId)
    }

    private static func applyDirectionReverse(_ data: TrackData, trackId: String) -> TrackData {
        guard let meta = TrackRegistry.track(byId: trackId), meta.racingDirectionReversed else {
            return data
        }

        let reversed = Array(data.points.reversed())
        let p0 = reversed[0]
        let p1 = reversed[1]
        let heading = atan2(p1.y - p0.y, p1.x - p0.x)

        return TrackData(
            points: reversed,
            roadHalfWidth: data.roadHalfWidth,
            totalLength: data.totalLength,
            startSegmentIndex: 0,
            startHeading: heading
        )
    }

    private static func applyStartOffset(_ data: TrackData, trackId: String) -> TrackData {
        let layout = SectorConfig.layout(for: trackId)
        guard layout.startOffset > 0 else { return data }

        let n = data.points.count
        let offset = Int(Double(n) * layout.startOffset)
        guard offset > 0, offset < n else { return data }

        let rotated = Array(data.points[offset...]) + Array(data.points[..<offset])

        let p0 = rotated[0]
        let p1 = rotated[1]
        let heading = atan2(p1.y - p0.y, p1.x - p0.x)

        return TrackData(
            points: rotated,
            roadHalfWidth: data.roadHalfWidth,
            totalLength: data.totalLength,
            startSegmentIndex: 0,
            startHeading: heading
        )
    }
}
