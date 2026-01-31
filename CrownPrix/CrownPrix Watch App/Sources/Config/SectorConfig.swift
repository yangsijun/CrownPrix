import Foundation

enum SectorConfig {
    struct TrackLayout {
        let startOffset: Double
        let sector1End: Double
        let sector2End: Double
    }

    static func layout(for trackId: String) -> TrackLayout {
        switch trackId {
        case "albertpark":        return TrackLayout(startOffset: 0.00, sector1End: 0.333, sector2End: 0.680)
        case "shanghai":          return TrackLayout(startOffset: 0.00, sector1End: 0.271, sector2End: 0.690)
        case "suzuka":            return TrackLayout(startOffset: 0.00, sector1End: 0.331, sector2End: 0.671)
        case "bahrain":           return TrackLayout(startOffset: 0.00, sector1End: 0.299, sector2End: 0.683)
        case "jeddah":            return TrackLayout(startOffset: 0.00, sector1End: 0.332, sector2End: 0.664)
        case "miami":             return TrackLayout(startOffset: 0.00, sector1End: 0.324, sector2End: 0.659)
        case "gillesvilleneuve":  return TrackLayout(startOffset: 0.00, sector1End: 0.350, sector2End: 0.679)
        case "monaco":            return TrackLayout(startOffset: 0.26, sector1End: 0.277, sector2End: 0.644)
        case "catalunya":         return TrackLayout(startOffset: 0.00, sector1End: 0.334, sector2End: 0.679)
        case "redbull":           return TrackLayout(startOffset: 0.00, sector1End: 0.336, sector2End: 0.679)
        case "silverstone":       return TrackLayout(startOffset: 0.00, sector1End: 0.314, sector2End: 0.707)
        case "spa":               return TrackLayout(startOffset: 0.00, sector1End: 0.293, sector2End: 0.688)
        case "hungaroring":       return TrackLayout(startOffset: 0.00, sector1End: 0.330, sector2End: 0.676)
        case "zandvoort":         return TrackLayout(startOffset: 0.00, sector1End: 0.295, sector2End: 0.683)
        case "monza":             return TrackLayout(startOffset: 0.00, sector1End: 0.353, sector2End: 0.678)
        case "madring":           return TrackLayout(startOffset: 0.00, sector1End: 0.333, sector2End: 0.667)
        case "baku":              return TrackLayout(startOffset: 0.94, sector1End: 0.233, sector2End: 0.630)
        case "marinabay":         return TrackLayout(startOffset: 0.00, sector1End: 0.290, sector2End: 0.721)
        case "americas":          return TrackLayout(startOffset: 0.00, sector1End: 0.238, sector2End: 0.644)
        case "hermanosrodriguez": return TrackLayout(startOffset: 0.00, sector1End: 0.303, sector2End: 0.688)
        case "interlagos":        return TrackLayout(startOffset: 0.00, sector1End: 0.244, sector2End: 0.724)
        case "lasvegas":          return TrackLayout(startOffset: 0.00, sector1End: 0.451, sector2End: 0.742)
        case "losail":            return TrackLayout(startOffset: 0.00, sector1End: 0.352, sector2End: 0.690)
        case "abudhabi":          return TrackLayout(startOffset: 0.00, sector1End: 0.276, sector2End: 0.627)
        default:                  return TrackLayout(startOffset: 0.00, sector1End: 0.333, sector2End: 0.667)
        }
    }

    static func boundaries(for trackId: String, segmentCount: Int) -> [Int] {
        let l = layout(for: trackId)
        return [
            Int(Double(segmentCount) * l.sector1End),
            Int(Double(segmentCount) * l.sector2End)
        ]
    }
}
