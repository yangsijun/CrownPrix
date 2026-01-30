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
            cn.zPosition = -1
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

        let innerOffset = halfW
        let outerOffset = halfW + curbWidth

        for i in 0..<count {
            let next = (i + 1) % count
            let dx = pts[next].x - pts[i].x
            let dy = pts[next].y - pts[i].y
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

        var segStart = 0
        var currentStripe = 0

        for i in 1..<count {
            let stripe = Int(arcLen[i] / stripeWidth)

            if stripe != currentStripe {
                if i > segStart {
                    let target = paths[currentStripe % patternCount]
                    Self.addRibbonQuad(target, inner: innerPts, outer: outerPts,
                                       from: segStart, to: i)
                }
                segStart = i
                currentStripe = stripe
            }
        }

        if count - 1 > segStart {
            let target = paths[currentStripe % patternCount]
            Self.addRibbonQuad(target, inner: innerPts, outer: outerPts,
                               from: segStart, to: count - 1)
        }

        return paths
    }

    private static func addRibbonQuad(_ path: CGMutablePath,
                                      inner: [CGPoint], outer: [CGPoint],
                                      from start: Int, to end: Int) {
        path.move(to: inner[start])
        for j in (start + 1)...end {
            path.addLine(to: inner[j])
        }
        for j in stride(from: end, through: start, by: -1) {
            path.addLine(to: outer[j])
        }
        path.closeSubpath()
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
