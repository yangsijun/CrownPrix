import CoreGraphics
import Foundation

final class CollisionSystem {
    private(set) var currentSegmentIndex: Int
    private let trackData: TrackData
    var onWallCollision: (() -> Void)?

    init(trackData: TrackData) {
        self.trackData = trackData
        self.currentSegmentIndex = trackData.startSegmentIndex
    }

    func update(carPosition: CGPoint, physics: PhysicsEngine) {
        let count = trackData.points.count
        guard count > 1 else { return }

        var bestIndex = currentSegmentIndex
        var bestDist = CGFloat.greatestFiniteMagnitude
        let window = GameConfig.segmentSearchWindow

        for offset in -window...window {
            let i = (currentSegmentIndex + offset + count) % count
            let j = (i + 1) % count
            let segA = CGPoint(x: trackData.points[i].x, y: trackData.points[i].y)
            let segB = CGPoint(x: trackData.points[j].x, y: trackData.points[j].y)
            let result = Self.perpendicularDistance(point: carPosition, segA: segA, segB: segB)
            if result.distance < bestDist {
                bestDist = result.distance
                bestIndex = i
            }
        }

        currentSegmentIndex = bestIndex

        let segI = currentSegmentIndex
        let segJ = (segI + 1) % count
        let segA = CGPoint(x: trackData.points[segI].x, y: trackData.points[segI].y)
        let segB = CGPoint(x: trackData.points[segJ].x, y: trackData.points[segJ].y)
        let nearest = Self.perpendicularDistance(point: carPosition, segA: segA, segB: segB)

        if nearest.distance > GameConfig.collisionHalfWidth {
            let dx = nearest.closest.x - carPosition.x
            let dy = nearest.closest.y - carPosition.y
            let len = sqrt(dx * dx + dy * dy)
            guard len > 0.001 else { return }

            let pushDirX = dx / len
            let pushDirY = dy / len
            let penetration = nearest.distance - GameConfig.collisionHalfWidth

            let newX = carPosition.x + pushDirX * (penetration + GameConfig.wallBounceDistance)
            let newY = carPosition.y + pushDirY * (penetration + GameConfig.wallBounceDistance)
            let correctedPosition = CGPoint(x: newX, y: newY)

            if !physics.isRecovering {
                let vx = cos(physics.carHeading) * physics.currentSpeed
                let vy = sin(physics.carHeading) * physics.currentSpeed

                let outwardDot = vx * (-pushDirX) + vy * (-pushDirY)
                var correctedVx = vx
                var correctedVy = vy
                if outwardDot > 0 {
                    correctedVx += pushDirX * outwardDot
                    correctedVy += pushDirY * outwardDot
                }

                let newSpeed = physics.currentSpeed * GameConfig.wallSlowdownFactor

                let magSq = correctedVx * correctedVx + correctedVy * correctedVy
                let correctedHeading: CGFloat
                if magSq < 0.0001 {
                    let tx = segB.x - segA.x
                    let ty = segB.y - segA.y
                    correctedHeading = atan2(ty, tx)
                } else {
                    correctedHeading = atan2(correctedVy, correctedVx)
                }

                physics.applyWallHit(
                    correctedPosition: correctedPosition,
                    correctedHeading: correctedHeading,
                    correctedSpeed: newSpeed
                )

                onWallCollision?()
            } else {
                physics.carPosition = correctedPosition
            }
        } else if nearest.distance <= GameConfig.collisionHalfWidth * 0.9 {
            physics.isRecovering = false
        }
    }

    static func perpendicularDistance(point: CGPoint, segA: CGPoint, segB: CGPoint) -> (distance: CGFloat, closest: CGPoint) {
        let abx = segB.x - segA.x
        let aby = segB.y - segA.y
        let lengthSq = abx * abx + aby * aby

        if lengthSq < 0.0001 {
            let dx = point.x - segA.x
            let dy = point.y - segA.y
            return (sqrt(dx * dx + dy * dy), segA)
        }

        let apx = point.x - segA.x
        let apy = point.y - segA.y
        let t = max(0, min(1, (apx * abx + apy * aby) / lengthSq))

        let closest = CGPoint(x: segA.x + t * abx, y: segA.y + t * aby)
        let dx = point.x - closest.x
        let dy = point.y - closest.y
        return (sqrt(dx * dx + dy * dy), closest)
    }
}
