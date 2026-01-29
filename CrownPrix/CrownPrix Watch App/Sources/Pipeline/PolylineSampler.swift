import CoreGraphics

enum PolylineSampler {
    // Arc-length resampling: produces exactly targetPointCount equidistant points (open loop).
    static func samplePolyline(rawPoints: [CGPoint], targetPointCount: Int) throws -> [TrackPoint] {
        guard rawPoints.count >= 3 else {
            throw TrackPipelineError.samplingFailed(reason: "Too few raw points: \(rawPoints.count)")
        }

        var points = rawPoints

        // Drop duplicate endpoint if the path is closed (first ≈ last)
        if let first = points.first, let last = points.last {
            let dx = first.x - last.x
            let dy = first.y - last.y
            if sqrt(dx * dx + dy * dy) < 1.0 {
                points.removeLast()
            }
        }

        guard points.count >= 3 else {
            throw TrackPipelineError.samplingFailed(reason: "Too few points after dedup: \(points.count)")
        }

        // Compute cumulative arc-length (closed loop: include wrap-around segment)
        let n = points.count
        var cumLength = [CGFloat](repeating: 0, count: n + 1)
        for i in 0..<n {
            let next = (i + 1) % n
            let dx = points[next].x - points[i].x
            let dy = points[next].y - points[i].y
            cumLength[i + 1] = cumLength[i] + sqrt(dx * dx + dy * dy)
        }
        let totalLength = cumLength[n]

        guard totalLength > 0 else {
            throw TrackPipelineError.samplingFailed(reason: "Zero total arc length")
        }

        // Resample at equidistant intervals
        let segmentLength = totalLength / CGFloat(targetPointCount)
        var result = [TrackPoint]()
        result.reserveCapacity(targetPointCount)

        var segIdx = 0
        for i in 0..<targetPointCount {
            let targetDist = CGFloat(i) * segmentLength

            while segIdx < n && cumLength[segIdx + 1] < targetDist {
                segIdx += 1
            }

            let segStart = cumLength[segIdx]
            let segEnd = cumLength[segIdx + 1]
            let segLen = segEnd - segStart
            let t: CGFloat = segLen > 0 ? (targetDist - segStart) / segLen : 0

            let fromIdx = segIdx % n
            let toIdx = (segIdx + 1) % n
            let x = points[fromIdx].x + t * (points[toIdx].x - points[fromIdx].x)
            let y = points[fromIdx].y + t * (points[toIdx].y - points[fromIdx].y)
            result.append(TrackPoint(x: x, y: y))
        }

        return result
    }
}
