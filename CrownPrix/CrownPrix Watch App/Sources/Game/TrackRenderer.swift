import SpriteKit

final class TrackRenderer {
    let trackNode: SKShapeNode
    let startLineNode: SKShapeNode
    let curbNodes: [SKShapeNode]

    init(trackData: TrackData, trackId: String = "") {
        let pts = trackData.points
        guard let first = pts.first else {
            trackNode = SKShapeNode()
            startLineNode = SKShapeNode()
            curbNodes = []
            return
        }

        // MARK: - Road

        let path = CGMutablePath()
        path.move(to: CGPoint(x: first.x, y: first.y))
        for i in 1..<pts.count {
            path.addLine(to: CGPoint(x: pts[i].x, y: pts[i].y))
        }
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(white: 0.35, alpha: 1)
        node.lineWidth = GameConfig.roadHalfWidth * 2
        node.lineCap = .round
        node.lineJoin = .round
        node.fillColor = .clear
        node.zPosition = 0
        trackNode = node

        // MARK: - Start Line

        let startPt = CGPoint(x: pts[0].x, y: pts[0].y)
        let nextPt = pts.count > 1
            ? CGPoint(x: pts[1].x, y: pts[1].y)
            : startPt
        let heading = atan2(nextPt.y - startPt.y, nextPt.x - startPt.x)
        let perpAngle = heading + .pi / 2
        let halfW = GameConfig.roadHalfWidth

        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(
            x: startPt.x + cos(perpAngle) * halfW,
            y: startPt.y + sin(perpAngle) * halfW
        ))
        linePath.addLine(to: CGPoint(
            x: startPt.x - cos(perpAngle) * halfW,
            y: startPt.y - sin(perpAngle) * halfW
        ))

        let line = SKShapeNode(path: linePath)
        line.strokeColor = .white
        line.lineWidth = 3
        line.zPosition = 1
        startLineNode = line

        // MARK: - Curbs

        let pattern = Self.curbPattern(for: trackId)
        let curbWidth: CGFloat = 4.0
        let stripeWidth: CGFloat = 8.0
        let count = pts.count

        let leftPaths = Self.buildCurbPaths(
            pts: pts, count: count, halfW: halfW,
            curbWidth: curbWidth, stripeWidth: stripeWidth,
            sign: -1, patternCount: pattern.count)
        let rightPaths = Self.buildCurbPaths(
            pts: pts, count: count, halfW: halfW,
            curbWidth: curbWidth, stripeWidth: stripeWidth,
            sign: 1, patternCount: pattern.count)

        curbNodes = (0..<pattern.count).map { i in
            let merged = CGMutablePath()
            merged.addPath(leftPaths[i])
            merged.addPath(rightPaths[i])
            let cn = SKShapeNode(path: merged)
            cn.fillColor = pattern[i]
            cn.strokeColor = .clear
            cn.lineWidth = 0
            cn.zPosition = 0.5
            return cn
        }
    }

    // MARK: - Curb Geometry

    private static func buildCurbPaths(
        pts: [TrackPoint], count: Int, halfW: CGFloat,
        curbWidth: CGFloat, stripeWidth: CGFloat,
        sign: CGFloat, patternCount: Int
    ) -> [CGMutablePath] {
        var innerPts = [CGPoint]()
        var outerPts = [CGPoint]()
        innerPts.reserveCapacity(count)
        outerPts.reserveCapacity(count)

        let innerOffset = halfW - curbWidth
        let outerOffset = halfW

        for i in 0..<count {
            let prev = (i - 1 + count) % count
            let next = (i + 1) % count
            let dx = pts[next].x - pts[prev].x
            let dy = pts[next].y - pts[prev].y
            let len = sqrt(dx * dx + dy * dy)
            if len > 0 {
                let px = -dy / len * sign
                let py = dx / len * sign
                innerPts.append(CGPoint(x: pts[i].x + px * innerOffset,
                                        y: pts[i].y + py * innerOffset))
                outerPts.append(CGPoint(x: pts[i].x + px * outerOffset,
                                        y: pts[i].y + py * outerOffset))
            } else {
                let p = CGPoint(x: pts[i].x, y: pts[i].y)
                innerPts.append(p)
                outerPts.append(p)
            }
        }

        var arcLen = [CGFloat]()
        arcLen.reserveCapacity(count)
        arcLen.append(0)
        for i in 1..<count {
            let dx = innerPts[i].x - innerPts[i - 1].x
            let dy = innerPts[i].y - innerPts[i - 1].y
            arcLen.append(arcLen[i - 1] + sqrt(dx * dx + dy * dy))
        }

        let paths = (0..<patternCount).map { _ in CGMutablePath() }

        let totalArc = arcLen[count - 1]
        let stripeCount = Int(ceil(totalArc / stripeWidth))
        var cursor = 0

        for s in 0..<stripeCount {
            let arcStart = CGFloat(s) * stripeWidth
            let arcEnd = min(CGFloat(s + 1) * stripeWidth, totalArc)
            guard arcEnd > arcStart else { continue }

            var innerStripe = [CGPoint]()
            var outerStripe = [CGPoint]()

            while cursor > 0 && arcLen[cursor] > arcStart { cursor -= 1 }
            while cursor + 1 < count && arcLen[cursor + 1] <= arcStart { cursor += 1 }
            let si = cursor
            let st = (arcLen[si + 1] > arcLen[si])
                ? (arcStart - arcLen[si]) / (arcLen[si + 1] - arcLen[si]) : 0

            innerStripe.append(Self.lerp(innerPts[si], innerPts[si + 1], st))
            outerStripe.append(Self.lerp(outerPts[si], outerPts[si + 1], st))

            for j in (si + 1)..<count {
                if arcLen[j] >= arcEnd { break }
                innerStripe.append(innerPts[j])
                outerStripe.append(outerPts[j])
            }

            while cursor + 1 < count && arcLen[cursor + 1] <= arcEnd { cursor += 1 }
            let ei = min(cursor, count - 2)
            let et = (arcLen[ei + 1] > arcLen[ei])
                ? (arcEnd - arcLen[ei]) / (arcLen[ei + 1] - arcLen[ei]) : 0

            innerStripe.append(Self.lerp(innerPts[ei], innerPts[ei + 1], et))
            outerStripe.append(Self.lerp(outerPts[ei], outerPts[ei + 1], et))

            guard innerStripe.count >= 2 else { continue }

            let target = paths[s % patternCount]
            target.move(to: innerStripe[0])
            for j in 1..<innerStripe.count {
                target.addLine(to: innerStripe[j])
            }
            for j in stride(from: outerStripe.count - 1, through: 0, by: -1) {
                target.addLine(to: outerStripe[j])
            }
            target.closeSubpath()
        }

        return paths
    }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    // MARK: - Curb Colors

    private static let green = SKColor(red: 0.0, green: 0.6, blue: 0.2, alpha: 1)

    private static func curbPattern(for trackId: String) -> [SKColor] {
        switch trackId {
        case "spa":
            return [.red, .yellow]
        case "monza":
            return [.red, .white, green, .white]
        case "albertpark":
            return [.yellow, green]
        case "interlagos":
            return [.white, .yellow, green]
        default:
            return [.red, .white]
        }
    }
}
