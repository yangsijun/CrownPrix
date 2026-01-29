import SpriteKit

final class CarNode: SKShapeNode {
    static func create() -> CarNode {
        let rect = CGRect(x: -10, y: -5, width: 20, height: 10)
        let node = CarNode(rect: rect, cornerRadius: 3)
        node.fillColor = .red
        node.strokeColor = .white
        node.lineWidth = 1
        node.zPosition = 10
        return node
    }
}
