import CoreGraphics
import Foundation

final class PhysicsEngine {
    var carPosition: CGPoint
    var carHeading: CGFloat
    var currentSpeed: CGFloat = 0
    var isRecovering: Bool = false
    private var previousCrownRotation: Double = 0
    private var hasPreviousCrown: Bool = false
    private var smoothedDelta: CGFloat = 0

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

        let smoothFactor = min(dt * GameConfig.steeringSmoothSpeed, 1.0)
        smoothedDelta += (CGFloat(delta) - smoothedDelta) * smoothFactor
        let sign: CGFloat = smoothedDelta >= 0 ? 1.0 : -1.0
        let magnitude = abs(smoothedDelta)
        let refDelta = GameConfig.maxCrownInputRate / CGFloat(GameConfig.targetFrameRate)
        let curvedDelta: CGFloat
        if magnitude <= refDelta {
            let normalized = magnitude / refDelta
            curvedDelta = pow(normalized, GameConfig.steeringCurveExponent) * refDelta * sign
        } else {
            curvedDelta = smoothedDelta
        }
        carHeading -= curvedDelta * GameConfig.maxTurnRate

        let turnSpeed = dt > 0.0001 ? abs(CGFloat(delta)) / dt : 0
        let normalizedTurn = min(turnSpeed / GameConfig.maxCrownInputRate, 1.0)
        let effective = max(0, (normalizedTurn - GameConfig.steeringDeadZone) / (1.0 - GameConfig.steeringDeadZone))
        let curved = effective * effective * effective * effective * effective
        let targetSpeed = GameConfig.minSpeedAtMaxSteer + (1.0 - curved) * (GameConfig.maxSpeed - GameConfig.minSpeedAtMaxSteer)

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
