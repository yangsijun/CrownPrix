import SwiftUI
import SpriteKit

struct RaceView: View {
    let trackId: String
    var onLapComplete: (TimeInterval) -> Void
    var onDNF: (() -> Void)? = nil

    @StateObject private var scene: GameScene
    @State private var showDNFConfirm = false
    @State private var showToolbar = false
    @State private var hideTask: Task<Void, Never>?

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
                revealToolbar()
            }
            .overlay(alignment: .top) {
                if showToolbar, onDNF != nil {
                    Button(action: { showDNFConfirm = true }) {
                        Text("DNF")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.red)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .transition(.opacity)
                }
            }
            .confirmationDialog("Retire?", isPresented: $showDNFConfirm) {
                Button("Retire", role: .destructive) { onDNF?() }
                Button("Continue", role: .cancel) { }
            }
            ._statusBarHidden()
    }

    private func revealToolbar() {
        hideTask?.cancel()
        withAnimation { showToolbar = true }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showToolbar = false }
            }
        }
    }
}
