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

    private var raceCountdown: RaceCountdown?
    private var timerHUD: TimerHUD?
    private var minimap: MinimapView?

    private var lastUpdateTime: TimeInterval = 0

    func configure(trackId: String, trackData: TrackData) {
        self.trackId = trackId
        self.trackData = trackData
    }

    override func sceneDidLoad() {
        super.sceneDidLoad()
        backgroundColor = SKColor(white: 0.12, alpha: 1)
        physicsWorld.gravity = .zero

        guard let trackData else { return }

        let renderer = TrackRenderer(trackData: trackData)
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
        cam.uiNode.zRotation = -(trackData.startHeading - .pi / 2)
        cameraController = cam

        physicsEngine = PhysicsEngine(
            startPosition: car.position,
            startHeading: trackData.startHeading
        )

        let collision = CollisionSystem(trackData: trackData)
        collision.onWallCollision = { HapticsManager.playWallCollision() }
        collisionSystem = collision

        let lap = LapDetector(trackData: trackData)
        let currentTrackId = trackId ?? ""
        lap.onLapComplete = { [weak self] (time: TimeInterval) in
            let isNew = PersistenceManager.isNewRecord(trackId: currentTrackId, time: time)
            self?.timerHUD?.freeze(isNewRecord: isNew)
            self?.onLapComplete?(time)
        }
        lapDetector = lap

        let countdown = RaceCountdown()
        countdown.attachTo(camera: cam.uiNode)
        countdown.onCountdownComplete = { [weak self] in
            self?.lapDetector?.startRace(at: 0)
            self?.timerHUD?.start()
        }
        raceCountdown = countdown

        let timer = TimerHUD()
        timer.attachTo(camera: cam.uiNode, sceneSize: size)
        timerHUD = timer

        let mini = MinimapView(trackData: trackData)
        mini.attachTo(camera: cam.uiNode, sceneSize: size)
        minimap = mini
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 1.0 / Double(GameConfig.targetFrameRate)
        lastUpdateTime = currentTime

        raceCountdown?.update(deltaTime: dt)

        guard dt < 1.0, let physics = physicsEngine, let collision = collisionSystem, let lap = lapDetector else { return }

        if raceCountdown?.isCountingDown == true { return }

        physics.update(crownRotation: crownRotation, deltaTime: dt)

        collision.update(carPosition: physics.carPosition, physics: physics)

        carNode?.position = physics.carPosition
        carNode?.zRotation = physics.carHeading

        timerHUD?.update(deltaTime: dt)

        lap.update(currentSegmentIndex: collision.currentSegmentIndex, currentTime: currentTime)

        minimap?.update(carPosition: physics.carPosition)
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
