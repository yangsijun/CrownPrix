import CoreGraphics
import Foundation

enum GameConfig {
    // MARK: - Crown Input
    static let maxTurnRate: CGFloat = 0.3

    // MARK: - Speed (points/sec at targetTrackSize=2000)
    static let maxSpeed: CGFloat = 180.0
    static let minSpeedAtMaxSteer: CGFloat = 70.0
    static let accelerationRate: CGFloat = 150.0
    static let wallSlowdownFactor: CGFloat = 0.45
    static let speedRecoveryRate: CGFloat = 150.0

    // MARK: - Track (game units at targetTrackSize=2000)
    static let roadHalfWidth: CGFloat = 16.0
    static let collisionHalfWidth: CGFloat = 18.0
    static let targetTrackSize: CGFloat = 2000.0
    static let trackPointCount: Int = 800
    static let wallBounceDistance: CGFloat = 2.0

    // MARK: - Camera
    static let cameraScale: CGFloat = 0.45
    static let cameraSmoothSpeed: CGFloat = 8.0

    // MARK: - Collision & Lap
    static let segmentSearchWindow: Int = 40
    static let lapCrossSegmentWindow: Int = 15

    // MARK: - Timing
    static let countdownDuration: TimeInterval = 3.0
    static let countdownStepInterval: TimeInterval = 1.0

    // MARK: - Display
    static let targetFrameRate: Int = 30
    static let displaySpeedScale: CGFloat = 360.0 / maxSpeed
}
