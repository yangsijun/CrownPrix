import SpriteKit

final class TimerHUD {
    private let timerLabel: SKLabelNode
    private var elapsedTime: TimeInterval = 0
    private var isRunning: Bool = false
    private var isFrozen: Bool = false

    init() {
        timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        timerLabel.fontSize = 16
        timerLabel.fontColor = .white
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.verticalAlignmentMode = .center
        timerLabel.zPosition = 100
        timerLabel.text = "0:00.000"
    }

    func attachTo(camera: SKNode, sceneSize: CGSize) {
        timerLabel.position = CGPoint(x: 0, y: sceneSize.height / 2 - 20)
        camera.addChild(timerLabel)
    }

    func start() {
        isRunning = true
    }

    func update(deltaTime: TimeInterval) {
        guard isRunning, !isFrozen else { return }

        elapsedTime += deltaTime

        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let millis = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 1000)
        timerLabel.text = String(format: "%d:%02d.%03d", minutes, seconds, millis)
    }

    func freeze(isNewRecord: Bool) {
        isFrozen = true
        timerLabel.fontColor = isNewRecord ? .green : .white
    }

    var currentTime: TimeInterval { elapsedTime }
}
