import SpriteKit

final class WrongWayIndicator {
    private let label: SKLabelNode
    private var blinkTimer: TimeInterval = 0
    private var isVisible: Bool = false

    init() {
        label = SKLabelNode(fontNamed: ".AppleSystemUIFontRounded-Bold")
        label.fontSize = 32
        label.fontColor = .red
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 100
        label.text = "WRONG WAY"
        label.isHidden = true
    }

    func attachTo(camera: SKNode, sceneSize: CGSize) {
        label.position = CGPoint(x: 0, y: sceneSize.height / 2 - 80)
        camera.addChild(label)
    }

    func update(carHeading: CGFloat, trackDirection: CGFloat, deltaTime: TimeInterval) {
        var diff = carHeading - trackDirection
        if diff > .pi { diff -= 2 * .pi }
        if diff < -.pi { diff += 2 * .pi }

        let isWrongWay = abs(diff) > .pi / 2

        if isWrongWay {
            blinkTimer += deltaTime
            let blinkOn = Int(blinkTimer * 3) % 2 == 0
            label.isHidden = !blinkOn
        } else {
            label.isHidden = true
            blinkTimer = 0
        }
    }
}
