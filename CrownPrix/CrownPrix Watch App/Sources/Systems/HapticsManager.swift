import WatchKit

enum HapticsManager {
    static func playCountdownBeat() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playCountdownGo() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    static func playCrownClick() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playWallCollision() {
        WKInterfaceDevice.current().play(.retry)
    }

    static func playLapComplete() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    static func playNewRecord() {
        WKInterfaceDevice.current().play(.success)
    }
}
