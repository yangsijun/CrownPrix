import Foundation

enum TrackLoader {
    static func loadTrackData(trackId: String, bundle: Bundle = .main) throws -> TrackData {
        guard let url = BundleHelper.trackDataURL(trackId: trackId, bundle: bundle) else {
            throw TrackPipelineError.noPathElementFound(svgFilename: trackId)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TrackData.self, from: data)
    }
}
