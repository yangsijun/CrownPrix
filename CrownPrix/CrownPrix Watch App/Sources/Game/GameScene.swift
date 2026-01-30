import SpriteKit
import Combine

final class GameScene: SKScene, ObservableObject {
    @Published var crownRotation: Double = 0.0
    var onLapComplete: ((TimeInterval) -> Void)?

    private(set) var trackId: String?
    private(set) var trackData: TrackData?
    private var trackRenderer: TrackRenderer?
    private var carNode: CarNode?
    private var cameraController: CameraController?

    private var physicsEngine: PhysicsEngine?
    private var collisionSystem: CollisionSystem?
    private(set) var lapDetector: LapDetector?
    private var sectorDetector: SectorDetector?

    private var raceCountdown: RaceCountdown?
    private var timerHUD: TimerHUD?
    private var minimap: MinimapView?
    private var wrongWayIndicator: WrongWayIndicator?

    private var lastUpdateTime: TimeInterval = 0
    private var didSetup = false

    func configure(trackId: String, trackData: TrackData) {
        self.trackId = trackId
        self.trackData = trackData
    }

    override func sceneDidLoad() {
        super.sceneDidLoad()
        backgroundColor = SKColor(white: 0.12, alpha: 1)
        physicsWorld.gravity = .zero
        setupIfNeeded()
    }

    private func setupIfNeeded() {
        guard !didSetup, let trackData else { return }
        didSetup = true

        let renderer = TrackRenderer(trackData: trackData, trackId: trackId ?? "")
        renderer.curbNodes.forEach { addChild($0) }
        addChild(renderer.trackNode)
        addChild(renderer.startLineNode)
        trackRenderer = renderer

        let car = CarNode.create()
        let startPt = trackData.points[0]
        car.position = CGPoint(x: startPt.x, y: startPt.y)
        car.zRotation = trackData.startHeading
        addChild(car)
        carNode = car

        let cam = CameraController()
        addChild(cam.cameraNode)
        camera = cam.cameraNode
        cam.cameraNode.position = car.position
        cam.cameraNode.zRotation = trackData.startHeading - .pi / 2
        cameraController = cam

        physicsEngine = PhysicsEngine(
            startPosition: car.position,
            startHeading: trackData.startHeading
        )

        let collision = CollisionSystem(trackData: trackData)
        collision.onWallCollision = { HapticsManager.playWallCollision() }
        collisionSystem = collision

        let currentTrackId = trackId ?? ""

        let lap = LapDetector(trackData: trackData)
        lap.onLapComplete = { [weak self] in
            guard let self, let timer = self.timerHUD else { return }
            let lapTime = timer.currentTime
            let isNew = PersistenceManager.isNewRecord(trackId: currentTrackId, time: lapTime)
            timer.freeze(isNewRecord: isNew)
            self.sectorDetector?.saveBestSectorTimes()
            if let times = self.sectorDetector?.sectorTimes {
                GameCenterManager.shared.submitSectorTimes(trackId: currentTrackId, times: times)
            }
            self.onLapComplete?(lapTime)
        }
        lapDetector = lap

        let sector = SectorDetector(trackId: currentTrackId, segmentCount: trackData.points.count)
        sector.onSectorComplete = { [weak self] sectorIndex, time, color in
            self?.timerHUD?.showSectorTime(sector: sectorIndex, time: time, color: color)
        }
        sectorDetector = sector

        Task {
            let globalTimes = await GameCenterManager.shared.loadGlobalBestSectorTimes(trackId: currentTrackId)
            await MainActor.run { sector.setGlobalBestSectorTimes(globalTimes) }
        }

        let countdown = RaceCountdown()
        countdown.attachTo(camera: cam.uiNode)
        countdown.onCountdownComplete = { [weak self] in
            self?.lapDetector?.startRace()
            self?.sectorDetector?.startRace()
            self?.timerHUD?.start()
        }
        raceCountdown = countdown

        let timer = TimerHUD()
        timer.attachTo(camera: cam.uiNode, sceneSize: size)
        timerHUD = timer

        let mini = MinimapView(trackData: trackData)
        mini.attachTo(camera: cam.uiNode, sceneSize: size)
        minimap = mini

        let wrongWay = WrongWayIndicator()
        wrongWay.attachTo(camera: cam.uiNode, sceneSize: size)
        wrongWayIndicator = wrongWay
    }

    override func update(_ currentTime: TimeInterval) {
        setupIfNeeded()

        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 1.0 / Double(GameConfig.targetFrameRate)
        lastUpdateTime = currentTime

        raceCountdown?.update(deltaTime: dt)

        guard dt < 1.0, let physics = physicsEngine, let collision = collisionSystem, let lap = lapDetector else { return }

        if raceCountdown?.isCountingDown == true { return }

        physics.update(crownRotation: crownRotation, deltaTime: dt)

        collision.update(carPosition: physics.carPosition, physics: physics)

        carNode?.position = physics.carPosition
        carNode?.zRotation = physics.carHeading

        timerHUD?.update(deltaTime: dt, speed: physics.currentSpeed)

        lap.update(currentSegmentIndex: collision.currentSegmentIndex)

        if let timer = timerHUD {
            sectorDetector?.update(
                currentSegmentIndex: collision.currentSegmentIndex,
                elapsedTime: timer.currentTime
            )
        }

        minimap?.update(carPosition: physics.carPosition)

        if let td = trackData {
            let segIdx = collision.currentSegmentIndex
            let nextIdx = (segIdx + 1) % td.points.count
            let trackDir = atan2(
                td.points[nextIdx].y - td.points[segIdx].y,
                td.points[nextIdx].x - td.points[segIdx].x
            )
            wrongWayIndicator?.update(
                carHeading: physics.carHeading,
                trackDirection: trackDir,
                deltaTime: dt
            )
        }
    }

    override func didSimulatePhysics() {
        guard let physics = physicsEngine else { return }
        cameraController?.update(
            carPosition: physics.carPosition,
            carHeading: physics.carHeading,
            deltaTime: 1.0 / Double(GameConfig.targetFrameRate)
        )
    }
}
