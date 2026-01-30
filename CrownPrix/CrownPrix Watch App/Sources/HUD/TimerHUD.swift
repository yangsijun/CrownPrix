import SpriteKit

final class TimerHUD {
    private let timerLabel: SKLabelNode
    private let speedLabel: SKLabelNode
    private var elapsedTime: TimeInterval = 0
    private var isRunning: Bool = false
    private var isFrozen: Bool = false

    init() {
        timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        timerLabel.fontSize = 32
        timerLabel.fontColor = .white
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.verticalAlignmentMode = .center
        timerLabel.zPosition = 100
        timerLabel.text = "0:00.000"

        speedLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        speedLabel.fontSize = 24
        speedLabel.fontColor = SKColor(white: 0.7, alpha: 1)
        speedLabel.horizontalAlignmentMode = .center
        speedLabel.verticalAlignmentMode = .center
        speedLabel.zPosition = 100
        speedLabel.text = "0 km/h"
    }

    func attachTo(camera: SKNode, sceneSize: CGSize) {
        timerLabel.position = CGPoint(x: 0, y: sceneSize.height / 2 - 40)
        camera.addChild(timerLabel)

        speedLabel.position = CGPoint(x: 0, y: -sceneSize.height / 2 + 32)
        camera.addChild(speedLabel)
    }

    func start() {
        isRunning = true
    }

    func update(deltaTime: TimeInterval, speed: CGFloat) {
        guard isRunning, !isFrozen else { return }

        elapsedTime += deltaTime

        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let millis = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 1000)
        timerLabel.text = String(format: "%d:%02d.%03d", minutes, seconds, millis)

        let kmh = Int(speed * GameConfig.displaySpeedScale)
        speedLabel.text = "\(kmh) km/h"
    }

    func freeze(isNewRecord: Bool) {
        isFrozen = true
        timerLabel.fontColor = isNewRecord ? .green : .white
    }

    var currentTime: TimeInterval { elapsedTime }
}
