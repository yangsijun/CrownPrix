import SwiftUI
import SpriteKit

enum CarColor: String, CaseIterable, Identifiable {
    // National racing colors, then F1 team colors, then others
    case red, silver, teal, blue, white, navy, orange, pink

    var id: String { rawValue }

    var skColor: SKColor {
        switch self {
        case .red:    return .red
        case .silver: return SKColor(red: 0.7, green: 0.75, blue: 0.78, alpha: 1)
        case .teal:   return SKColor(red: 0.0, green: 0.55, blue: 0.42, alpha: 1)
        case .blue:   return SKColor(red: 0.0, green: 0.2, blue: 0.7, alpha: 1)
        case .white:  return .white
        case .navy:   return SKColor(red: 0.12, green: 0.1, blue: 0.55, alpha: 1)
        case .orange: return .orange
        case .pink:   return SKColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1)
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .red:    return .red
        case .silver: return Color(red: 0.7, green: 0.75, blue: 0.78)
        case .teal:   return Color(red: 0.0, green: 0.55, blue: 0.42)
        case .blue:   return Color(red: 0.0, green: 0.2, blue: 0.7)
        case .white:  return .white
        case .navy:   return Color(red: 0.12, green: 0.1, blue: 0.55)
        case .orange: return .orange
        case .pink:   return Color(red: 1.0, green: 0.4, blue: 0.6)
        }
    }

    var needsDarkCheckmark: Bool {
        switch self {
        case .white, .silver: return true
        default: return false
        }
    }

    var needsBorder: Bool {
        switch self {
        case .navy, .teal, .blue: return true
        default: return false
        }
    }

    private static let storageKey = "selectedCarColor"

    static var saved: CarColor {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey),
                  let color = CarColor(rawValue: raw) else { return .red }
            return color
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
