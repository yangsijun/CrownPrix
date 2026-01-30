import SpriteKit

final class MinimapView {
    private let containerNode: SKNode
    private let trackOutline: SKShapeNode
    private let carDot: SKShapeNode
    private let startLine: SKShapeNode
    private let trackPoints: [TrackPoint]
    private let minimapScale: CGFloat
    private let minimapOffset: CGPoint

    init(trackData: TrackData) {
        trackPoints = trackData.points
        containerNode = SKNode()
        containerNode.zPosition = 100

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for pt in trackPoints {
            minX = min(minX, pt.x)
            maxX = max(maxX, pt.x)
            minY = min(minY, pt.y)
            maxY = max(maxY, pt.y)
        }

        let bboxWidth = maxX - minX
        let bboxHeight = maxY - minY
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        minimapOffset = CGPoint(x: centerX, y: centerY)
        minimapScale = 75.0 / max(bboxWidth, bboxHeight, 1)

        let path = CGMutablePath()
        let stride = max(1, trackPoints.count / 80)
        var first = true
        for i in Swift.stride(from: 0, to: trackPoints.count, by: stride) {
            let pt = trackPoints[i]
            let mx = (pt.x - centerX) * minimapScale
            let my = (pt.y - centerY) * minimapScale
            if first {
                path.move(to: CGPoint(x: mx, y: my))
                first = false
            } else {
                path.addLine(to: CGPoint(x: mx, y: my))
            }
        }
        path.closeSubpath()

        trackOutline = SKShapeNode(path: path)
        trackOutline.strokeColor = .white
        trackOutline.lineWidth = 1
        trackOutline.fillColor = .clear
        containerNode.addChild(trackOutline)

        carDot = SKShapeNode(circleOfRadius: 4)
        carDot.fillColor = .red
        carDot.strokeColor = .clear
        carDot.zPosition = 1
        containerNode.addChild(carDot)

        let startPt = trackPoints[0]
        let smx = (startPt.x - centerX) * minimapScale
        let smy = (startPt.y - centerY) * minimapScale
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: smx - 3, y: smy))
        linePath.addLine(to: CGPoint(x: smx + 3, y: smy))
        startLine = SKShapeNode(path: linePath)
        startLine.strokeColor = .yellow
        startLine.lineWidth = 1.5
        startLine.zPosition = 1
        containerNode.addChild(startLine)
    }

    func attachTo(camera: SKNode, sceneSize: CGSize) {
        containerNode.position = CGPoint(x: sceneSize.width / 2 - 85, y: -sceneSize.height / 2 + 80)
        camera.addChild(containerNode)
    }

    func update(carPosition: CGPoint) {
        carDot.position = CGPoint(
            x: (carPosition.x - minimapOffset.x) * minimapScale,
            y: (carPosition.y - minimapOffset.y) * minimapScale
        )
    }
}
