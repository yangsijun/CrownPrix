import SwiftUI

struct ResultView: View {
    let trackId: String
    let lapTime: TimeInterval
    var onRetry: () -> Void
    var onBackToTracks: () -> Void
    var onShowLeaderboard: (() -> Void)? = nil

    @State private var savedRecord = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("FINISH")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.yellow)

                Text(TimeFormatter.format(lapTime))
                    .font(.system(.title2, design: .monospaced, weight: .bold))

                bestTimeSection

                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                Button("Tracks", action: onBackToTracks)
                    .buttonStyle(.bordered)

                if GameCenterManager.shared.isAuthenticated, let onShowLeaderboard {
                    Button("Rankings", action: onShowLeaderboard)
                        .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            if !savedRecord {
                PersistenceManager.saveBestTime(trackId: trackId, time: lapTime)
                savedRecord = true
            }
        }
    }

    @ViewBuilder
    private var bestTimeSection: some View {
        let previousBest = PersistenceManager.getBestTime(trackId: trackId)
        let isNew = previousBest == nil || lapTime <= previousBest!

        if isNew {
            Text("NEW RECORD!")
                .font(.caption)
                .foregroundStyle(.green)
                .bold()
        } else if let best = previousBest {
            VStack(spacing: 2) {
                Text("Best: \(TimeFormatter.format(best))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                let delta = lapTime - best
                Text(String(format: "+%.3f", delta))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    ResultView(
        trackId: "albertpark",
        lapTime: 83.456,
        onRetry: {},
        onBackToTracks: {}
    )
}
