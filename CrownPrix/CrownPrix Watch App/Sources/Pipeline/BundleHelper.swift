import Foundation

/// Centralized resource loading utility.
/// ALL resource loading in both app and tests goes through BundleHelper.
/// Tries subdirectory first, then flat bundle root (handles both folder references and flattened bundles).
enum BundleHelper {
    /// Load a track SVG by svgFilename (e.g., "RaceCircuitMonaco").
    static func svgURL(name: String, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: name, withExtension: "svg", subdirectory: "Track")
        ?? bundle.url(forResource: name, withExtension: "svg")
    }

    /// Load a pre-processed track JSON by trackId (e.g., "monaco").
    static func trackDataURL(trackId: String, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: trackId, withExtension: "json", subdirectory: "PreprocessedTracks")
        ?? bundle.url(forResource: trackId, withExtension: "json")
    }
}
