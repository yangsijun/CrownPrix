import CoreGraphics
import Foundation

final class PhysicsEngine {
    var carPosition: CGPoint
    var carHeading: CGFloat
    var currentSpeed: CGFloat = 0
    var isRecovering: Bool = false
    private var currentTurnRate: CGFloat = 0

    init(startPosition: CGPoint, startHeading: CGFloat) {
        self.carPosition = startPosition
        self.carHeading = startHeading
    }

    func update(crownRotation: Double, deltaTime: TimeInterval) {
        let steering = CrownInputHandler.computeSteering(crownRotation: crownRotation)

        let dt = CGFloat(deltaTime)
        let alpha = min(dt * GameConfig.steeringResponse, 1.0)
        currentTurnRate += (steering.turnRate - currentTurnRate) * alpha

        carHeading += currentTurnRate * dt

        if currentSpeed < steering.targetSpeed {
            currentSpeed = min(currentSpeed + GameConfig.accelerationRate * dt, steering.targetSpeed)
        } else {
            currentSpeed = max(currentSpeed - GameConfig.accelerationRate * dt, steering.targetSpeed)
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
