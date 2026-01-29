import CoreGraphics
import Foundation

final class PhysicsEngine {
    var carPosition: CGPoint
    var carHeading: CGFloat
    var currentSpeed: CGFloat = 0
    var isRecovering: Bool = false
    private var previousCrownRotation: Double = 0
    private var hasPreviousCrown: Bool = false

    init(startPosition: CGPoint, startHeading: CGFloat) {
        self.carPosition = startPosition
        self.carHeading = startHeading
    }

    func update(crownRotation: Double, deltaTime: TimeInterval) {
        let dt = CGFloat(deltaTime)

        if !hasPreviousCrown {
            previousCrownRotation = crownRotation
            hasPreviousCrown = true
        }

        var delta = crownRotation - previousCrownRotation
        previousCrownRotation = crownRotation

        // isContinuous wraps -1..1 (span=2)
        if delta > 1.0 { delta -= 2.0 }
        if delta < -1.0 { delta += 2.0 }

        carHeading += CGFloat(delta) * GameConfig.maxTurnRate

        let turnSpeed = dt > 0.0001 ? abs(CGFloat(delta)) / dt : 0
        let normalizedTurn = min(turnSpeed / GameConfig.maxTurnRate, 1.0)
        let targetSpeed = GameConfig.minSpeedAtMaxSteer + (1.0 - normalizedTurn) * (GameConfig.maxSpeed - GameConfig.minSpeedAtMaxSteer)

        if currentSpeed < targetSpeed {
            currentSpeed = min(currentSpeed + GameConfig.accelerationRate * dt, targetSpeed)
        } else {
            currentSpeed = max(currentSpeed - GameConfig.accelerationRate * dt, targetSpeed)
        }

        carPosition.x += cos(carHeading) * currentSpeed * dt
        carPosition.y += sin(carHeading) * currentSpeed * dt
    }

    func applyWallHit(correctedPosition: CGPoint, correctedHeading: CGFloat, correctedSpeed: CGFloat) {
        carPosition = correctedPosition
        carHeading = correctedHeading
        currentSpeed = correctedSpeed
        isRecovering = true
    }
}
