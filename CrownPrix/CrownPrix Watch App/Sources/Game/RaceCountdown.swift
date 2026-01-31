import SpriteKit

final class RaceCountdown {
    private let containerNode: SKNode
    private var lightNodes: [SKShapeNode] = []
    private var litCount: Int = 0
    private var elapsed: TimeInterval = 0
    private var lightsOutDone = false
    private(set) var isCountingDown: Bool = true
    var onCountdownComplete: (() -> Void)?

    private let totalLights = 5
    private let lightInterval: TimeInterval = 1.0
    private let lightsOutDelay: TimeInterval = 0.4

    init() {
        containerNode = SKNode()
        containerNode.zPosition = 200

        let spacing: CGFloat = 22
        let totalWidth = CGFloat(totalLights - 1) * spacing
        let startX = -totalWidth / 2

        for i in 0..<totalLights {
            let light = SKShapeNode(circleOfRadius: 8)
            light.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            light.fillColor = SKColor(white: 0.2, alpha: 1)
            light.strokeColor = SKColor(white: 0.4, alpha: 1)
            light.lineWidth = 1
            containerNode.addChild(light)
            lightNodes.append(light)
        }
    }

    func attachTo(camera: SKNode) {
        containerNode.position = CGPoint(x: 0, y: 60)
        camera.addChild(containerNode)
    }

    func update(deltaTime: TimeInterval) {
        guard isCountingDown else { return }

        elapsed += deltaTime

        if litCount < totalLights {
            let targetLit = min(totalLights, Int(elapsed / lightInterval) + 1)
            while litCount < targetLit {
                lightNodes[litCount].fillColor = .red
                lightNodes[litCount].strokeColor = .red
                HapticsManager.playStartLight()
                litCount += 1
            }
        } else if !lightsOutDone {
            let timeSinceAllLit = elapsed - Double(totalLights) * lightInterval
            if timeSinceAllLit >= lightsOutDelay {
                for light in lightNodes {
                    light.fillColor = .clear
                    light.strokeColor = SKColor(white: 0.3, alpha: 1)
                }
                lightsOutDone = true
                HapticsManager.playStartGo()
            }
        } else {
            let timeSinceLightsOut = elapsed - Double(totalLights) * lightInterval - lightsOutDelay
            if timeSinceLightsOut >= 0.5 {
                containerNode.isHidden = true
                isCountingDown = false
                onCountdownComplete?()
            }
        }
    }
}
