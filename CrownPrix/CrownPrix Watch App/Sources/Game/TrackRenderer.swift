import SpriteKit

final class TrackRenderer {
    let trackNode: SKShapeNode
    let startLineNode: SKShapeNode

    init(trackData: TrackData) {
        let path = CGMutablePath()
        let pts = trackData.points
        guard let first = pts.first else {
            trackNode = SKShapeNode()
            startLineNode = SKShapeNode()
            return
        }

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
    }
}
