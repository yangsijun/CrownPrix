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

        sampled = smooth(points: sampled, iterations: 3)
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

        let a = removeClosingSegment(pathA)
        let b = removeClosingSegment(pathB)

        var bestDist = CGFloat.greatestFiniteMagnitude
        var crossIdxA = 0
        var crossIdxB = 0

        for i in 0..<a.count {
            for j in 0..<b.count {
                let d = distance(a[i], b[j])
                if d < bestDist {
                    bestDist = d
                    crossIdxA = i
                    crossIdxB = j
                }
            }
        }

        guard bestDist < 50.0 else {
            throw TrackPipelineError.mergeFailed(reason: "No crossing point found (min dist: \(bestDist))")
        }

        let loopA = Array(a[crossIdxA...]) + Array(a[..<crossIdxA])
        let loopB = Array(b[crossIdxB...]) + Array(b[..<crossIdxB])

        let dirEndA = atan2(loopA.last!.y - loopA[loopA.count - 2].y,
                            loopA.last!.x - loopA[loopA.count - 2].x)
        let dirStartB = atan2(loopB[1].y - loopB[0].y,
                              loopB[1].x - loopB[0].x)
        var angleDiff = abs(dirStartB - dirEndA)
        if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

        let dirStartBRev = atan2(loopB[loopB.count - 2].y - loopB.last!.y,
                                 loopB[loopB.count - 2].x - loopB.last!.x)
        var angleDiffRev = abs(dirStartBRev - dirEndA)
        if angleDiffRev > .pi { angleDiffRev = 2 * .pi - angleDiffRev }

        let finalB = angleDiffRev < angleDiff ? loopB.reversed() as [CGPoint] : loopB

        var merged = loopA
        merged.append(contentsOf: finalB.dropFirst())

        return merged
    }

    private static func removeClosingSegment(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        let first = points[0]
        let last = points[points.count - 1]
        guard distance(first, last) < 50.0 else { return points }

        let closingDir = atan2(first.y - last.y, first.x - last.x)

        var cutIndex = points.count
        for i in stride(from: points.count - 1, through: 1, by: -1) {
            let prev = points[i - 1]
            let cur = points[i]
            let segDir = atan2(cur.y - prev.y, cur.x - prev.x)
            var diff = abs(segDir - closingDir)
            if diff > .pi { diff = 2 * .pi - diff }
            if diff < 0.15 {
                cutIndex = i
            } else {
                break
            }
        }

        if cutIndex < points.count {
            return Array(points[0..<cutIndex])
        }
        return points
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

    // MARK: - Smoothing (circular moving average)

    private static func smooth(points: [TrackPoint], iterations: Int, windowRadius: Int = 2) -> [TrackPoint] {
        guard points.count > windowRadius * 2 else { return points }
        var pts = points
        let n = pts.count
        for _ in 0..<iterations {
            var smoothed = [TrackPoint]()
            smoothed.reserveCapacity(n)
            for i in 0..<n {
                var sx: CGFloat = 0
                var sy: CGFloat = 0
                let count = windowRadius * 2 + 1
                for j in -windowRadius...windowRadius {
                    let idx = (i + j + n) % n
                    sx += pts[idx].x
                    sy += pts[idx].y
                }
                smoothed.append(TrackPoint(x: sx / CGFloat(count), y: sy / CGFloat(count)))
            }
            pts = smoothed
        }
        return pts
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
