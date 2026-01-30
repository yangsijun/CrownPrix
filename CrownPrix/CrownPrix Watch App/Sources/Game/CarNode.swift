import SpriteKit

final class CarNode: SKShapeNode {
    static func create() -> CarNode {
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 7, y: 0))
        body.addLine(to: CGPoint(x: 4.5, y: 1.0))
        body.addLine(to: CGPoint(x: -4, y: 1.3))
        body.addLine(to: CGPoint(x: -6, y: 0.8))
        body.addLine(to: CGPoint(x: -6, y: -0.8))
        body.addLine(to: CGPoint(x: -4, y: -1.3))
        body.addLine(to: CGPoint(x: 4.5, y: -1.0))
        body.closeSubpath()

        let node = CarNode(path: body)
        node.fillColor = .red
        node.strokeColor = .clear
        node.zPosition = 10

        let wheelColor = SKColor(white: 0.15, alpha: 1)

        for ySign: CGFloat in [-1, 1] {
            let fy = ySign > 0 ? CGFloat(1.5) : CGFloat(-2.5)
            let fw = SKShapeNode(rect: CGRect(x: 2.25, y: fy, width: 2.5, height: 1.0))
            fw.fillColor = wheelColor
            fw.strokeColor = .clear
            node.addChild(fw)

            let ry = ySign > 0 ? CGFloat(1.7) : CGFloat(-2.9)
            let rw = SKShapeNode(rect: CGRect(x: -6.0, y: ry, width: 3.0, height: 1.2))
            rw.fillColor = wheelColor
            rw.strokeColor = .clear
            node.addChild(rw)
        }

        let cockpit = SKShapeNode(circleOfRadius: 1.0)
        cockpit.position = CGPoint(x: -1.5, y: 0)
        cockpit.fillColor = SKColor(white: 0.2, alpha: 1)
        cockpit.strokeColor = .clear
        cockpit.zPosition = 1
        node.addChild(cockpit)

        let fWing = SKShapeNode(rect: CGRect(x: 5.5, y: -3.0, width: 0.8, height: 6.0))
        fWing.fillColor = .red
        fWing.strokeColor = .clear
        node.addChild(fWing)

        let rWing = SKShapeNode(rect: CGRect(x: -7.0, y: -3.3, width: 0.8, height: 6.6))
        rWing.fillColor = .red
        rWing.strokeColor = .clear
        node.addChild(rWing)

        return node
    }
}
