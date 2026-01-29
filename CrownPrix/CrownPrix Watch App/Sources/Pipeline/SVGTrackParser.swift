import CoreGraphics
import SVGPath

enum SVGTrackParser {
    static func parseSVGPathData(dAttribute: String) throws -> [CGPoint] {
        let svgPath: SVGPath
        do {
            svgPath = try SVGPath(string: dAttribute)
        } catch {
            throw TrackPipelineError.svgParsingFailed(svgFilename: "unknown", underlying: error)
        }

        let svgPoints = svgPath.points(withDetail: 20)
        guard !svgPoints.isEmpty else {
            throw TrackPipelineError.emptyPathData(svgFilename: "unknown")
        }

        return svgPoints.map { CGPoint($0) }
    }
}
