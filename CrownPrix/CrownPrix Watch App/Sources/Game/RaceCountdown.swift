import SpriteKit

final class RaceCountdown {
    private let countdownLabel: SKLabelNode
    private var countdownValue: Int = 3
    private var countdownElapsed: TimeInterval = 0
    private(set) var isCountingDown: Bool = true
    var onCountdownComplete: (() -> Void)?

    init() {
        countdownLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontRounded-Bold")
        countdownLabel.fontSize = 36
        countdownLabel.fontColor = .white
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.zPosition = 100
        countdownLabel.text = "3"
    }

    func attachTo(camera: SKNode) {
        countdownLabel.position = .zero
        camera.addChild(countdownLabel)
    }

    func update(deltaTime: TimeInterval) {
        guard isCountingDown else { return }

        countdownElapsed += deltaTime

        while countdownElapsed >= GameConfig.countdownStepInterval {
            countdownElapsed -= GameConfig.countdownStepInterval
            countdownValue -= 1

            if countdownValue > 0 {
                countdownLabel.text = "\(countdownValue)"
                HapticsManager.playCountdownBeat()
            } else if countdownValue == 0 {
                countdownLabel.text = "GO!"
                HapticsManager.playCountdownGo()
            } else {
                countdownLabel.isHidden = true
                isCountingDown = false
                onCountdownComplete?()
                break
            }
        }
    }
}
