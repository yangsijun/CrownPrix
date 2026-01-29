import SpriteKit

final class CameraController {
    let cameraNode: SKCameraNode
    let uiNode: SKNode

    init() {
        cameraNode = SKCameraNode()
        cameraNode.setScale(GameConfig.cameraScale)

        uiNode = SKNode()
        uiNode.zPosition = 200
        cameraNode.addChild(uiNode)
    }

    func update(carPosition: CGPoint, carHeading: CGFloat, deltaTime: TimeInterval) {
        let smoothFactor = min(CGFloat(deltaTime) * GameConfig.cameraSmoothSpeed, 1.0)

        let targetX = carPosition.x
        let targetY = carPosition.y
        cameraNode.position.x += (targetX - cameraNode.position.x) * smoothFactor
        cameraNode.position.y += (targetY - cameraNode.position.y) * smoothFactor

        cameraNode.zRotation = carHeading - .pi / 2

        uiNode.zRotation = -cameraNode.zRotation
    }
}
