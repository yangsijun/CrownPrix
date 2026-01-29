import SwiftUI
import SpriteKit

struct RaceView: View {
    let trackId: String
    var onLapComplete: (TimeInterval) -> Void

    @StateObject private var scene: GameScene

    init(trackId: String, onLapComplete: @escaping (TimeInterval) -> Void) {
        self.trackId = trackId
        self.onLapComplete = onLapComplete

        let s = GameScene()
        s.size = CGSize(width: 400, height: 480)
        s.scaleMode = .aspectFill

        if let trackData = try? TrackLoader.loadTrackData(trackId: trackId) {
            s.configure(trackId: trackId, trackData: trackData)
        }

        _scene = StateObject(wrappedValue: s)
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .focusable()
            .digitalCrownRotation(
                $scene.crownRotation,
                from: -1.0, through: 1.0,
                sensitivity: .medium,
                isContinuous: true,
                isHapticFeedbackEnabled: true
            )
            .onAppear {
                scene.onLapComplete = onLapComplete
            }
    }
}
