import CoreGraphics
import Foundation
import SVGPath

enum TrackPreprocessor {
    static func preprocessTrack(svgContent: String, metadata: TrackMetadata) throws -> TrackData {
        let dAttributes = extractPathDAttributes(from: svgContent)

        guard !dAttributes.isEmpty else {
            throw TrackPipelineError.noPathElementFound(svgFilename: metadata.svgFilename)
        }

        let isSuzuka = dAttributes.count == 2
        if !isSuzuka && dAttributes.count != 1 {
            throw TrackPipelineError.unexpectedPathCount(expected: 1, found: dAttributes.count, svgFilename: metadata.svgFilename)
        }

        var rawPoints: [CGPoint]
        if isSuzuka {
            let pathA = try SVGTrackParser.parseSVGPathData(dAttribute: dAttributes[0])
            let pathB = try SVGTrackParser.parseSVGPathData(dAttribute: dAttributes[1])
            rawPoints = try mergeSuzukaPaths(pathA: pathA, pathB: pathB)
        } else {
            rawPoints = try SVGTrackParser.parseSVGPathData(dAttribute: dAttributes[0])
        }

        var sampled = try PolylineSampler.samplePolyline(
            rawPoints: rawPoints,
            targetPointCount: GameConfig.trackPointCount
        )

        sampled = normalize(points: sampled)

        if metadata.racingDirectionReversed {
            sampled.reverse()
        }

        let totalLength = computeTotalLength(points: sampled)

        // startHeading: direction from point[0] to point[1]
        let heading: CGFloat
        if sampled.count >= 2 {
            heading = atan2(sampled[1].y - sampled[0].y, sampled[1].x - sampled[0].x)
        } else {
            heading = 0
        }

        return TrackData(
            points: sampled,
            roadHalfWidth: GameConfig.roadHalfWidth,
            totalLength: totalLength,
            startSegmentIndex: 0,
            startHeading: heading
        )
    }

    // MARK: - SVG d-attribute extraction (regex, locked approach)

    private static func extractPathDAttributes(from svgContent: String) -> [String] {
        let pattern = #"<path[^>]*\sd="([^"]*)"[^>]*/?\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(svgContent.startIndex..., in: svgContent)
        let matches = regex.matches(in: svgContent, range: range)

        return matches.compactMap { match -> String? in
            guard match.numberOfRanges >= 2,
                  let captureRange = Range(match.range(at: 1), in: svgContent) else { return nil }
            return String(svgContent[captureRange])
        }
    }

    // MARK: - Suzuka 2-path merge (deterministic algorithm)

    private static func mergeSuzukaPaths(pathA: [CGPoint], pathB: [CGPoint]) throws -> [CGPoint] {
        guard pathA.count >= 2, pathB.count >= 2 else {
            throw TrackPipelineError.mergeFailed(reason: "Paths too short to merge")
        }

        struct Config {
            let a: [CGPoint]
            let b: [CGPoint]
        }

        let configs = [
            Config(a: pathA, b: pathB),
            Config(a: pathA, b: pathB.reversed()),
            Config(a: pathA.reversed(), b: pathB),
            Config(a: pathB, b: pathA),
        ]

        var bestConfig = configs[0]
        var bestDist = CGFloat.greatestFiniteMagnitude

        for config in configs {
            let d = distance(config.a.last!, config.b.first!)
            if d < bestDist {
                bestDist = d
                bestConfig = config
            }
        }

        var merged = bestConfig.a
        if bestDist < 1.0 {
            merged.append(contentsOf: bestConfig.b.dropFirst())
        } else {
            merged.append(contentsOf: bestConfig.b)
        }

        return merged
    }

    // MARK: - Normalization

    private static func normalize(points: [TrackPoint]) -> [TrackPoint] {
        guard !points.isEmpty else { return points }

        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let maxDim = max(maxX - minX, maxY - minY)

        guard maxDim > 0 else { return points }

        let scale = GameConfig.targetTrackSize / maxDim

        return points.map { pt in
            TrackPoint(x: (pt.x - centerX) * scale, y: (pt.y - centerY) * scale)
        }
    }

    // MARK: - Helpers

    private static func computeTotalLength(points: [TrackPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var total: CGFloat = 0
        for i in 0..<points.count {
            let next = (i + 1) % points.count
            let dx = points[next].x - points[i].x
            let dy = points[next].y - points[i].y
            total += sqrt(dx * dx + dy * dy)
        }
        return total
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
