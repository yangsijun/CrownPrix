import CoreGraphics
import XCTest
@testable import CrownPrix_Watch_App

final class TrackPipelineTests: XCTestCase {

    func testAllTrackSVGsExist() {
        let bundle = Bundle.main
        for metadata in TrackRegistry.allTracks {
            let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle)
            XCTAssertNotNil(url, "SVG not found: \(metadata.svgFilename)")
        }
    }

    func testParseAllTrackSVGs() throws {
        let bundle = Bundle.main
        for metadata in TrackRegistry.allTracks {
            guard let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle) else {
                XCTFail("SVG not found: \(metadata.svgFilename)")
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            let dAttributes = extractPathDAttributes(from: content)
            XCTAssertFalse(dAttributes.isEmpty, "No d-attribute found in \(metadata.svgFilename)")
            for dAttr in dAttributes {
                let points = try SVGTrackParser.parseSVGPathData(dAttribute: dAttr)
                XCTAssertFalse(points.isEmpty, "Empty parsed points for \(metadata.svgFilename)")
            }
        }
    }

    func testParseSuzukaSpecialCase() throws {
        let bundle = Bundle.main
        guard let metadata = TrackRegistry.track(byId: "suzuka") else {
            XCTFail("Suzuka metadata not found")
            return
        }
        guard let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle) else {
            XCTFail("SVG not found: \(metadata.svgFilename)")
            return
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        let dAttributes = extractPathDAttributes(from: content)
        XCTAssertEqual(dAttributes.count, 2, "Suzuka should have exactly 2 <path> elements")
        let trackData = try TrackPreprocessor.preprocessTrack(svgContent: content, metadata: metadata)
        XCTAssertFalse(trackData.points.isEmpty)
    }

    func testParseMonacoProducesClosedPath() throws {
        let bundle = Bundle.main
        guard let metadata = TrackRegistry.track(byId: "monaco") else {
            XCTFail("Monaco metadata not found")
            return
        }
        guard let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle) else {
            XCTFail("SVG not found: \(metadata.svgFilename)")
            return
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        let dAttributes = extractPathDAttributes(from: content)
        XCTAssertFalse(dAttributes.isEmpty)
        let rawPoints = try SVGTrackParser.parseSVGPathData(dAttribute: dAttributes[0])
        guard let first = rawPoints.first, let last = rawPoints.last else {
            XCTFail("No points parsed")
            return
        }
        let dx = first.x - last.x
        let dy = first.y - last.y
        let dist = sqrt(dx * dx + dy * dy)
        XCTAssertLessThan(dist, 5.0, "Monaco path should be closed (first ≈ last)")
    }

    func testSamplePolylineProducesTargetPointCount() throws {
        let circlePoints = makeCircle(count: 100, radius: 100)
        let sampled = try PolylineSampler.samplePolyline(rawPoints: circlePoints, targetPointCount: 50)
        XCTAssertEqual(sampled.count, 50)
    }

    func testSamplePolylineEquidistant() throws {
        let circlePoints = makeCircle(count: 100, radius: 100)
        let sampled = try PolylineSampler.samplePolyline(rawPoints: circlePoints, targetPointCount: 50)
        var distances = [CGFloat]()
        for i in 0..<sampled.count {
            let next = (i + 1) % sampled.count
            let dx = sampled[next].x - sampled[i].x
            let dy = sampled[next].y - sampled[i].y
            distances.append(sqrt(dx * dx + dy * dy))
        }
        let avg = distances.reduce(0, +) / CGFloat(distances.count)
        for (i, d) in distances.enumerated() {
            XCTAssertLessThan(abs(d - avg) / avg, 0.1, "Segment \(i) distance \(d) deviates >10% from average \(avg)")
        }
    }

    func testPreprocessAllTracks() throws {
        let bundle = Bundle.main
        for metadata in TrackRegistry.allTracks {
            guard let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle) else {
                XCTFail("SVG not found: \(metadata.svgFilename)")
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            let trackData = try TrackPreprocessor.preprocessTrack(svgContent: content, metadata: metadata)
            XCTAssertFalse(trackData.points.isEmpty, "\(metadata.id): empty points")
            XCTAssertEqual(trackData.points.count, GameConfig.trackPointCount, "\(metadata.id): wrong point count")
            XCTAssertGreaterThan(trackData.totalLength, 0, "\(metadata.id): zero totalLength")
            XCTAssertEqual(trackData.startSegmentIndex, 0, "\(metadata.id): startSegmentIndex != 0")
            XCTAssertGreaterThan(trackData.roadHalfWidth, 0, "\(metadata.id): roadHalfWidth should be positive")
            XCTAssertTrue(trackData.startHeading.isFinite, "\(metadata.id): non-finite startHeading")
        }
    }

    func testAllTracksFormClosedLoops() throws {
        let bundle = Bundle.main
        for metadata in TrackRegistry.allTracks {
            guard let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle) else {
                XCTFail("SVG not found: \(metadata.svgFilename)")
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            let trackData = try TrackPreprocessor.preprocessTrack(svgContent: content, metadata: metadata)
            guard let first = trackData.points.first, let last = trackData.points.last else {
                XCTFail("\(metadata.id): no points")
                continue
            }
            let dx = first.x - last.x
            let dy = first.y - last.y
            let dist = sqrt(dx * dx + dy * dy)
            XCTAssertGreaterThan(dist, 1.0, "\(metadata.id): last→first distance too small (duplicate endpoint?)")
        }
    }

    func testTrackNormalization() throws {
        let bundle = Bundle.main
        for metadata in TrackRegistry.allTracks {
            guard let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle) else {
                XCTFail("SVG not found: \(metadata.svgFilename)")
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            let trackData = try TrackPreprocessor.preprocessTrack(svgContent: content, metadata: metadata)
            let xs = trackData.points.map(\.x)
            let ys = trackData.points.map(\.y)
            let bboxCenterX = (xs.min()! + xs.max()!) / 2
            let bboxCenterY = (ys.min()! + ys.max()!) / 2
            XCTAssertLessThan(abs(bboxCenterX), 1.0, "\(metadata.id): bounding box centerX not at origin")
            XCTAssertLessThan(abs(bboxCenterY), 1.0, "\(metadata.id): bounding box centerY not at origin")
            let bboxWidth = xs.max()! - xs.min()!
            let bboxHeight = ys.max()! - ys.min()!
            let maxDim = max(bboxWidth, bboxHeight)
            // targetTrackSize = 2000; max dimension should match after normalization
            XCTAssertEqual(maxDim, GameConfig.targetTrackSize, accuracy: 1.0, "\(metadata.id): max dimension not normalized")
        }
    }

    func testTrackRegistryHas22Entries() {
        XCTAssertEqual(TrackRegistry.allTracks.count, 22)
    }

    func testAllTrackIdsUnique() {
        let ids = TrackRegistry.allTracks.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate track IDs found")
    }

    func testAllLeaderboardIdsUnique() {
        let ids = TrackRegistry.allTracks.map(\.leaderboardId)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate leaderboard IDs found")
    }

    func testGeneratePreprocessedJSON() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GENERATE_TRACKS"] == "1", "Set GENERATE_TRACKS=1 to run")
        let bundle = Bundle.main
        let outputDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CrownPrix Watch App/Resources/PreprocessedTracks")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var writtenCount = 0
        for metadata in TrackRegistry.allTracks {
            guard let url = BundleHelper.svgURL(name: metadata.svgFilename, bundle: bundle) else {
                XCTFail("SVG not found: \(metadata.svgFilename)")
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            let trackData = try TrackPreprocessor.preprocessTrack(svgContent: content, metadata: metadata)
            let jsonData = try encoder.encode(trackData)
            let outputURL = outputDir.appendingPathComponent("\(metadata.id).json")
            try jsonData.write(to: outputURL)
            writtenCount += 1
        }
        XCTAssertEqual(writtenCount, 22)
    }

    private func makeCircle(count: Int, radius: CGFloat) -> [CGPoint] {
        (0..<count).map { i in
            let angle = 2.0 * CGFloat.pi * CGFloat(i) / CGFloat(count)
            return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
        }
    }

    private func extractPathDAttributes(from svgContent: String) -> [String] {
        let pattern = #"<path[^>]*\sd="([^"]*)"[^>]*/?\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(svgContent.startIndex..., in: svgContent)
        let matches = regex.matches(in: svgContent, range: range)
        return matches.compactMap { match -> String? in
            guard match.numberOfRanges >= 2,
                  let captureRange = Range(match.range(at: 1), in: svgContent) else { return nil }
            return String(svgContent[captureRange])
        }
    }
}
