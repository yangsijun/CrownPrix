import SwiftUI
import SpriteKit

struct RaceView: View {
    let trackId: String
    var onLapComplete: (TimeInterval) -> Void
    var onDNF: (() -> Void)? = nil

    @StateObject private var scene: GameScene
    @State private var showRetire = false

    init(trackId: String, onLapComplete: @escaping (TimeInterval) -> Void, onDNF: (() -> Void)? = nil) {
        self.trackId = trackId
        self.onLapComplete = onLapComplete
        self.onDNF = onDNF

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
            .onLongPressGesture(minimumDuration: 0.5) {
                scene.pauseRace()
                showRetire = true
            }
            .confirmationDialog("Retire?", isPresented: $showRetire) {
                Button("Retire", role: .destructive) { onDNF?() }
                Button("Continue", role: .cancel) { scene.resumeRace() }
            }
            ._statusBarHidden()
    }
}

#Preview {
    RaceView(trackId: "albertpark", onLapComplete: { _ in })
}
