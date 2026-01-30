import WatchKit

enum HapticsManager {
    static func playCountdownBeat() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playCountdownGo() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playStartLight() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playStartGo() {
        WKInterfaceDevice.current().play(.start)
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
