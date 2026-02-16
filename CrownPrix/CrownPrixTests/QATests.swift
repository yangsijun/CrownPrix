import CoreGraphics
import XCTest
@testable import CrownPrix_Watch_App

final class QATests: XCTestCase {

    // MARK: - All 22 Tracks Load from JSON

    func testAllTracksLoadFromJSON() throws {
        for metadata in TrackRegistry.allTracks {
            let trackData = try TrackLoader.loadTrackData(trackId: metadata.id)
            XCTAssertFalse(trackData.points.isEmpty, "\(metadata.id): no points loaded")
            XCTAssertEqual(trackData.points.count, GameConfig.trackPointCount, "\(metadata.id): wrong point count")
            XCTAssertGreaterThan(trackData.totalLength, 0, "\(metadata.id): zero totalLength")
            XCTAssertTrue(trackData.startHeading.isFinite, "\(metadata.id): non-finite startHeading")
            XCTAssertGreaterThan(trackData.roadHalfWidth, 0, "\(metadata.id): roadHalfWidth should be positive")
        }
    }

    // MARK: - Track Data Integrity

    func testAllTracksHaveReasonableLength() throws {
        for metadata in TrackRegistry.allTracks {
            let trackData = try TrackLoader.loadTrackData(trackId: metadata.id)
            XCTAssertGreaterThan(trackData.totalLength, 500, "\(metadata.id): track too short")
            XCTAssertLessThan(trackData.totalLength, 50000, "\(metadata.id): track too long")
        }
    }

    func testAllTracksStartHeadingValid() throws {
        for metadata in TrackRegistry.allTracks {
            let trackData = try TrackLoader.loadTrackData(trackId: metadata.id)
            XCTAssertGreaterThanOrEqual(trackData.startHeading, -.pi * 2, "\(metadata.id): heading out of range")
            XCTAssertLessThanOrEqual(trackData.startHeading, .pi * 2, "\(metadata.id): heading out of range")
        }
    }

    func testAllTracksCarSpawnOnRoad() throws {
        for metadata in TrackRegistry.allTracks {
            let trackData = try TrackLoader.loadTrackData(trackId: metadata.id)
            let startPt = trackData.points[0]
            let carPos = CGPoint(x: startPt.x, y: startPt.y)

            let segA = CGPoint(x: trackData.points[0].x, y: trackData.points[0].y)
            let segB = CGPoint(x: trackData.points[1].x, y: trackData.points[1].y)
            let result = CollisionSystem.perpendicularDistance(point: carPos, segA: segA, segB: segB)
            XCTAssertLessThanOrEqual(result.distance, GameConfig.roadHalfWidth,
                                    "\(metadata.id): car spawns off-road (dist=\(result.distance))")
        }
    }

    // MARK: - Crown Input Handler

    func testCrownNeutralProducesMaxSpeed() {
        let result = CrownInputHandler.computeSteering(crownRotation: 0)
        XCTAssertEqual(result.turnRate, 0)
        XCTAssertEqual(result.targetSpeed, GameConfig.maxSpeed)
    }

    func testCrownMaxProducesMinSpeed() {
        let result = CrownInputHandler.computeSteering(crownRotation: 1.0)
        XCTAssertEqual(result.targetSpeed, GameConfig.minSpeedAtMaxSteer, accuracy: 1.0)
    }

    func testCrownSteeringClamped() {
        let extreme = CrownInputHandler.computeSteering(crownRotation: 100.0)
        XCTAssertEqual(abs(extreme.turnRate), GameConfig.maxTurnRate, accuracy: 0.001)
    }

    func testCrownSteeringSymmetric() {
        let left = CrownInputHandler.computeSteering(crownRotation: 0.5)
        let right = CrownInputHandler.computeSteering(crownRotation: -0.5)
        XCTAssertEqual(left.turnRate, -right.turnRate, accuracy: 0.001)
        XCTAssertEqual(left.targetSpeed, right.targetSpeed, accuracy: 0.001)
    }

    // MARK: - GameConfig Sanity

    func testGameConfigValuesSane() {
        XCTAssertGreaterThan(GameConfig.maxSpeed, GameConfig.minSpeedAtMaxSteer)
        XCTAssertGreaterThan(GameConfig.roadHalfWidth, 0)
        XCTAssertGreaterThan(GameConfig.maxTurnRate, 0)
        XCTAssertGreaterThan(GameConfig.cameraScale, 0)
        XCTAssertGreaterThan(GameConfig.trackPointCount, 100)
        XCTAssertGreaterThan(GameConfig.wallBounceDistance, 0)
        XCTAssertGreaterThan(GameConfig.accelerationRate, 0)
        XCTAssertGreaterThan(GameConfig.countdownDuration, 0)
        XCTAssertGreaterThan(GameConfig.lapCrossSegmentWindow, 0)
    }

    // MARK: - Collision Geometry (static methods only)

    func testPerpendicularDistanceOnSegment() {
        let result = CollisionSystem.perpendicularDistance(
            point: CGPoint(x: 5, y: 5),
            segA: CGPoint(x: 0, y: 0),
            segB: CGPoint(x: 10, y: 0)
        )
        XCTAssertEqual(result.distance, 5.0, accuracy: 0.01)
        XCTAssertEqual(result.closest.x, 5.0, accuracy: 0.01)
        XCTAssertEqual(result.closest.y, 0.0, accuracy: 0.01)
    }

    func testPerpendicularDistanceAtEndpoint() {
        let result = CollisionSystem.perpendicularDistance(
            point: CGPoint(x: 15, y: 0),
            segA: CGPoint(x: 0, y: 0),
            segB: CGPoint(x: 10, y: 0)
        )
        XCTAssertEqual(result.distance, 5.0, accuracy: 0.01)
        XCTAssertEqual(result.closest.x, 10.0, accuracy: 0.01)
    }

    func testPerpendicularDistanceZeroLengthSegment() {
        let result = CollisionSystem.perpendicularDistance(
            point: CGPoint(x: 3, y: 4),
            segA: CGPoint(x: 0, y: 0),
            segB: CGPoint(x: 0, y: 0)
        )
        XCTAssertEqual(result.distance, 5.0, accuracy: 0.01)
    }

    // MARK: - Persistence

    func testPersistenceRoundTrip() {
        let testTrackId = "__qa_test_track__"
        let key = "bestTime.\(testTrackId)"
        UserDefaults.standard.removeObject(forKey: key)

        XCTAssertNil(PersistenceManager.getBestTime(trackId: testTrackId))
        XCTAssertTrue(PersistenceManager.isNewRecord(trackId: testTrackId, time: 30.0))

        PersistenceManager.saveBestTime(trackId: testTrackId, time: 30.0)
        XCTAssertEqual(PersistenceManager.getBestTime(trackId: testTrackId), 30.0)

        XCTAssertFalse(PersistenceManager.isNewRecord(trackId: testTrackId, time: 31.0))
        XCTAssertTrue(PersistenceManager.isNewRecord(trackId: testTrackId, time: 29.0))

        PersistenceManager.saveBestTime(trackId: testTrackId, time: 29.0)
        XCTAssertEqual(PersistenceManager.getBestTime(trackId: testTrackId), 29.0)

        UserDefaults.standard.removeObject(forKey: key)
    }

    func testPersistenceDoesNotOverwriteBetter() {
        let testTrackId = "__qa_test_track_2__"
        let key = "bestTime.\(testTrackId)"
        UserDefaults.standard.removeObject(forKey: key)

        PersistenceManager.saveBestTime(trackId: testTrackId, time: 25.0)
        PersistenceManager.saveBestTime(trackId: testTrackId, time: 30.0)
        XCTAssertEqual(PersistenceManager.getBestTime(trackId: testTrackId), 25.0)

        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - TimeFormatter

    func testTimeFormatterOutput() {
        let formatted = TimeFormatter.format(65.123)
        XCTAssertTrue(formatted.contains("1"), "Should show minutes for 65s")
        XCTAssertTrue(formatted.contains("05"), "Should show 05 seconds")
        XCTAssertTrue(formatted.contains("123"), "Should show milliseconds")
    }

    func testTimeFormatterZero() {
        XCTAssertEqual(TimeFormatter.format(0), "0:00.000")
    }

    func testTimeFormatterSubMinute() {
        XCTAssertEqual(TimeFormatter.format(42.567), "0:42.567")
    }
}
