import Foundation

enum TrackPipelineError: Error, CustomStringConvertible {
    case noPathElementFound(svgFilename: String)
    case unexpectedPathCount(expected: Int, found: Int, svgFilename: String)
    case emptyPathData(svgFilename: String)
    case svgParsingFailed(svgFilename: String, underlying: Error)
    case mergeFailed(reason: String)
    case samplingFailed(reason: String)
    case normalizationFailed(reason: String)

    var description: String {
        switch self {
        case .noPathElementFound(let name):
            "No <path> element found in \(name)"
        case .unexpectedPathCount(let expected, let found, let name):
            "Expected \(expected) path(s) in \(name), found \(found)"
        case .emptyPathData(let name):
            "Empty path d attribute in \(name)"
        case .svgParsingFailed(let name, let err):
            "SVG parsing failed for \(name): \(err)"
        case .mergeFailed(let reason):
            "Path merge failed: \(reason)"
        case .samplingFailed(let reason):
            "Polyline sampling failed: \(reason)"
        case .normalizationFailed(let reason):
            "Track normalization failed: \(reason)"
        }
    }
}
