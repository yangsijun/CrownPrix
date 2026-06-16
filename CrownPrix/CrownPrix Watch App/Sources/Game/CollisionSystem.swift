import CoreGraphics
import Foundation

final class CollisionSystem {
    private(set) var currentSegmentIndex: Int
    private let trackData: TrackData
    // nil on first frame — no trajectory to test yet
    private var previousCarPosition: CGPoint?
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

        // Inner-barrier check: reject trajectories that cross an impassable chord
        // inside a tight curve (e.g. hairpin shortcut). Runs independently of
        // isRecovering — the barrier is additive and must fire regardless of
        // centerline wall state.
        if let prevPos = previousCarPosition, !trackData.innerBarriers.isEmpty {
            for barrier in trackData.innerBarriers {
                let b0 = CGPoint(x: barrier.start.x, y: barrier.start.y)
                let b1 = CGPoint(x: barrier.end.x, y: barrier.end.y)
                if Self.segmentsIntersect(prevPos, physics.carPosition, b0, b1) {
                    let newSpeed = physics.currentSpeed * GameConfig.wallSlowdownFactor
                    physics.applyWallHit(
                        correctedPosition: prevPos,
                        correctedHeading: physics.carHeading,
                        correctedSpeed: newSpeed
                    )
                    onWallCollision?()
                    break
                }
            }
        }

        previousCarPosition = physics.carPosition
    }

    /// Returns true iff segment p1→p2 crosses the strict interior of p3→p4.
    /// Uses open intervals on u (the barrier parameter) so trajectories that
    /// merely graze a barrier endpoint (e.g. apex vertex on centerline) do
    /// not trigger. The car-trajectory parameter t uses an inclusive interval.
    static func segmentsIntersect(
        _ p1: CGPoint, _ p2: CGPoint,
        _ p3: CGPoint, _ p4: CGPoint
    ) -> Bool {
        let d1x = p2.x - p1.x
        let d1y = p2.y - p1.y
        let d2x = p4.x - p3.x
        let d2y = p4.y - p3.y
        let cross = d1x * d2y - d1y * d2x
        guard abs(cross) > 0.0001 else { return false }
        let t = ((p3.x - p1.x) * d2y - (p3.y - p1.y) * d2x) / cross
        let u = ((p3.x - p1.x) * d1y - (p3.y - p1.y) * d1x) / cross
        let eps: CGFloat = 1e-6
        return t >= 0 && t <= 1 && u > eps && u < 1 - eps
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
