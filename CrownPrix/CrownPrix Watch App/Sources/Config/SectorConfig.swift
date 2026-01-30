import Foundation

enum SectorConfig {
    struct TrackLayout {
        let startOffset: Double
        let sector1End: Double
        let sector2End: Double
    }

    static func layout(for trackId: String) -> TrackLayout {
        switch trackId {
        case "abudhabi":          return TrackLayout(startOffset: 0.71, sector1End: 0.276, sector2End: 0.627)
        case "albertpark":        return TrackLayout(startOffset: 0.67, sector1End: 0.333, sector2End: 0.680)
        case "americas":          return TrackLayout(startOffset: 0.52, sector1End: 0.238, sector2End: 0.644)
        case "monza":             return TrackLayout(startOffset: 0.54, sector1End: 0.353, sector2End: 0.678)
        case "bahrain":           return TrackLayout(startOffset: 0.84, sector1End: 0.299, sector2End: 0.683)
        case "catalunya":         return TrackLayout(startOffset: 0.15, sector1End: 0.334, sector2End: 0.679)
        case "baku":              return TrackLayout(startOffset: 0.89, sector1End: 0.233, sector2End: 0.630)
        case "gillesvilleneuve":  return TrackLayout(startOffset: 0.36, sector1End: 0.350, sector2End: 0.679)
        case "hermanosrodriguez": return TrackLayout(startOffset: 0.03, sector1End: 0.303, sector2End: 0.688)
        case "hockenheim":        return TrackLayout(startOffset: 0.80, sector1End: 0.291, sector2End: 0.700)
        case "hungaroring":       return TrackLayout(startOffset: 0.51, sector1End: 0.330, sector2End: 0.676)
        case "interlagos":        return TrackLayout(startOffset: 0.21, sector1End: 0.244, sector2End: 0.724)
        case "marinabay":         return TrackLayout(startOffset: 0.88, sector1End: 0.290, sector2End: 0.721)
        case "monaco":            return TrackLayout(startOffset: 0.64, sector1End: 0.277, sector2End: 0.644)
        case "paulricard":        return TrackLayout(startOffset: 0.74, sector1End: 0.340, sector2End: 0.671)
        case "redbull":           return TrackLayout(startOffset: 0.65, sector1End: 0.336, sector2End: 0.679)
        case "sepang":            return TrackLayout(startOffset: 0.70, sector1End: 0.352, sector2End: 0.689)
        case "shanghai":          return TrackLayout(startOffset: 0.39, sector1End: 0.271, sector2End: 0.690)
        case "silverstone":       return TrackLayout(startOffset: 0.50, sector1End: 0.314, sector2End: 0.707)
        case "sochi":             return TrackLayout(startOffset: 0.05, sector1End: 0.308, sector2End: 0.687)
        case "spa":               return TrackLayout(startOffset: 0.94, sector1End: 0.293, sector2End: 0.688)
        case "suzuka":            return TrackLayout(startOffset: 0.56, sector1End: 0.331, sector2End: 0.671)
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
