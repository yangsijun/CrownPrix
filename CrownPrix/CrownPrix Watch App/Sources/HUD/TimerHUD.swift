import SpriteKit

final class TimerHUD {
    private let timerLabel: SKLabelNode
    private let speedLabel: SKLabelNode
    private let sectorLabels: [SKLabelNode]
    private let sectorBackgrounds: [SKShapeNode]
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

        var bgs: [SKShapeNode] = []
        sectorLabels = (0..<3).map { i in
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.fontSize = 16
            label.fontColor = SKColor(white: 0.5, alpha: 1)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 101
            label.text = "S\(i + 1) --.---"

            let bg = SKShapeNode(rectOf: CGSize(width: 72, height: 20), cornerRadius: 4)
            bg.fillColor = .clear
            bg.strokeColor = .clear
            bg.zPosition = 100
            bgs.append(bg)

            return label
        }
        sectorBackgrounds = bgs
    }

    func attachTo(camera: SKNode, sceneSize: CGSize) {
        timerLabel.position = CGPoint(x: 0, y: sceneSize.height / 2 - 40)
        camera.addChild(timerLabel)

        let sectorY = sceneSize.height / 2 - 68
        let spacing: CGFloat = 80
        for (i, label) in sectorLabels.enumerated() {
            let x = CGFloat(i - 1) * spacing
            sectorBackgrounds[i].position = CGPoint(x: x, y: sectorY)
            camera.addChild(sectorBackgrounds[i])
            label.position = CGPoint(x: x, y: sectorY)
            camera.addChild(label)
        }

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

    func showSectorTime(sector: Int, time: TimeInterval, color: SectorColor) {
        guard sector >= 0, sector < 3 else { return }
        let label = sectorLabels[sector]
        let secs = Int(time) % 60
        let millis = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        let minutes = Int(time) / 60
        if minutes > 0 {
            label.text = String(format: "S%d %d:%02d.%03d", sector + 1, minutes, secs, millis)
        } else {
            label.text = String(format: "S%d %d.%03d", sector + 1, secs, millis)
        }
        label.fontColor = .black
        sectorBackgrounds[sector].fillColor = color.skColor
    }

    func freeze(isNewRecord: Bool) {
        isFrozen = true
        timerLabel.fontColor = isNewRecord ? .green : .white
    }

    var currentTime: TimeInterval { elapsedTime }
}

extension SectorColor {
    var skColor: SKColor {
        switch self {
        case .white:  return .white
        case .yellow: return .yellow
        case .green:  return .green
        case .purple: return SKColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1)
        }
    }
}
