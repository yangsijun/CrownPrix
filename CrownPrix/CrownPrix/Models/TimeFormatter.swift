import Foundation

enum TimeFormatter {
    static func format(_ time: TimeInterval) -> String {
        let totalMillis = Int(time * 1000)
        let minutes = totalMillis / 60000
        let seconds = (totalMillis % 60000) / 1000
        let millis = totalMillis % 1000
        return String(format: "%d:%02d.%03d", minutes, seconds, millis)
    }
}
