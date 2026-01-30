import Foundation

enum SectorConfig {
    static func boundaries(for trackId: String, segmentCount: Int) -> [Int] {
        let (s1, s2) = percentages(for: trackId)
        return [
            Int(Double(segmentCount) * s1),
            Int(Double(segmentCount) * s2)
        ]
    }

    private static func percentages(for trackId: String) -> (Double, Double) {
        switch trackId {
        case "americas":          return (0.24, 0.65)
        case "spa":               return (0.30, 0.67)
        case "silverstone":       return (0.32, 0.64)
        case "monaco":            return (0.28, 0.60)
        case "monza":             return (0.33, 0.67)
        case "suzuka":            return (0.28, 0.62)
        case "bahrain":           return (0.35, 0.68)
        case "shanghai":          return (0.30, 0.65)
        case "catalunya":         return (0.33, 0.67)
        case "hungaroring":       return (0.32, 0.66)
        case "sepang":            return (0.33, 0.67)
        case "interlagos":        return (0.30, 0.65)
        case "redbull":           return (0.35, 0.70)
        case "baku":              return (0.28, 0.62)
        case "gillesvilleneuve":  return (0.33, 0.67)
        case "marinabay":         return (0.30, 0.65)
        case "hermanosrodriguez": return (0.32, 0.68)
        case "albertpark":        return (0.30, 0.65)
        case "abudhabi":          return (0.32, 0.66)
        case "sochi":             return (0.30, 0.65)
        case "hockenheim":        return (0.35, 0.70)
        case "paulricard":        return (0.33, 0.67)
        default:                  return (0.33, 0.67)
        }
    }
}
