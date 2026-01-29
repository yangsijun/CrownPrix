import CoreGraphics

enum CrownInputHandler {
    static func computeSteering(crownRotation: Double) -> (turnRate: CGFloat, targetSpeed: CGFloat) {
        let x = CGFloat(max(-1.0, min(1.0, crownRotation)))
        let turnRate = x * GameConfig.maxTurnRate

        let speedFactor = 1.0 - abs(x)
        let targetSpeed = GameConfig.minSpeedAtMaxSteer + speedFactor * (GameConfig.maxSpeed - GameConfig.minSpeedAtMaxSteer)

        return (turnRate, targetSpeed)
    }
}
