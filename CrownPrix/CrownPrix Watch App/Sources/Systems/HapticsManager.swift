import WatchKit

enum HapticsManager {
    static func playCountdownBeat() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playCountdownGo() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playCrownClick() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playWallCollision() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playLapComplete() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playNewRecord() {
        WKInterfaceDevice.current().play(.click)
    }
}
