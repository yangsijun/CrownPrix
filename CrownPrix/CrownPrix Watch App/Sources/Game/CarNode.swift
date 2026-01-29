import SpriteKit

final class CarNode: SKShapeNode {
    static func create() -> CarNode {
        let rect = CGRect(x: -5, y: -10, width: 10, height: 20)
        let node = CarNode(rect: rect, cornerRadius: 3)
        node.fillColor = .red
        node.strokeColor = .white
        node.lineWidth = 1
        node.zPosition = 10
        return node
    }
}
