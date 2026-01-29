import WatchKit

enum HapticsManager {
    static func playCountdownBeat() {
        WKInterfaceDevice.current().play(.stop)
    }
    
    static func playCountdownGo() {
        WKInterfaceDevice.current().play(.start)
    }
    
    static func playCrownClick() {
        WKInterfaceDevice.current().play(.click)
    }
    
    static func playWallCollision() {
        WKInterfaceDevice.current().play(.failure)
    }
    
    static func playLapComplete() {
        WKInterfaceDevice.current().play(.success)
    }
    
    static func playNewRecord() {
        WKInterfaceDevice.current().play(.success)
    }
}
