import SwiftUI

struct ResultView: View {
    let data: RaceCompletionData
    var onRetry: () -> Void
    var onBackToTracks: () -> Void
    var onShowLeaderboard: (() -> Void)? = nil

    @State private var savedRecord = false
    @State private var globalBestTime: TimeInterval?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("FINISH")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.yellow)

                Text(TimeFormatter.format(data.lapTime))
                    .font(.system(.title2, design: .monospaced, weight: .bold))

                recordSection
                sectorTimesSection

                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                Button("Tracks", action: onBackToTracks)
                    .buttonStyle(.bordered)

                #if DEBUG
                let canShowLeaderboard = GameCenterManager.shared.isAuthenticated || data.trackId == "dev"
                #else
                let canShowLeaderboard = GameCenterManager.shared.isAuthenticated
                #endif
                if canShowLeaderboard, let onShowLeaderboard {
                    Button("Rankings", action: onShowLeaderboard)
                        .buttonStyle(.bordered)
                }
            }
        }
        .task {
            if !savedRecord {
                PersistenceManager.saveBestTime(trackId: data.trackId, time: data.lapTime)
                savedRecord = true
            }
            await loadGlobalBest()
        }
    }

    @ViewBuilder
    private var recordSection: some View {
        let previousBest = PersistenceManager.getBestTime(trackId: data.trackId)
        let isPersonalBest = previousBest == nil || data.lapTime <= previousBest!
        let isWorldRecord = globalBestTime != nil && data.lapTime <= globalBestTime!

        VStack(spacing: 4) {
            if isWorldRecord {
                Text("WORLD RECORD!")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color(red: 0.7, green: 0.3, blue: 1.0))
            } else if let globalBest = globalBestTime {
                VStack(spacing: 1) {
                    Text("P1: \(TimeFormatter.format(globalBest))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    let gap = data.lapTime - globalBest
                    Text(String(format: "+%.3f", gap))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if isPersonalBest && !isWorldRecord {
                Text("NEW RECORD!")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .bold()
            } else if !isPersonalBest, let best = previousBest {
                VStack(spacing: 1) {
                    Text("Best: \(TimeFormatter.format(best))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    let delta = data.lapTime - best
                    Text(String(format: "+%.3f", delta))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var sectorTimesSection: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                let time = data.sectorTimes[i]
                let color = data.sectorColors[i]
                VStack(spacing: 2) {
                    Text("S\(i)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                    Text(formatSectorTime(time))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(color.swiftUIColor.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func formatSectorTime(_ time: TimeInterval?) -> String {
        guard let time else { return "--.---" }
        let totalMillis = Int(time * 1000)
        let secs = (totalMillis % 60000) / 1000
        let millis = totalMillis % 1000
        return String(format: "%02d.%03d", secs, millis)
    }

    private func loadGlobalBest() async {
        #if DEBUG
        let canLoad = GameCenterManager.shared.isAuthenticated || data.trackId == "dev"
        #else
        let canLoad = GameCenterManager.shared.isAuthenticated
        #endif
        guard canLoad, let track = TrackRegistry.track(byId: data.trackId) else { return }
        let entries = try? await GameCenterManager.shared.loadTopScores(
            leaderboardId: track.leaderboardId, count: 1
        )
        if let first = entries?.first {
            globalBestTime = first.lapTime
        }
    }
}

extension SectorColor {
    var swiftUIColor: Color {
        switch self {
        case .white:  return Color(white: 0.5)
        case .yellow: return .yellow
        case .green:  return .green
        case .purple: return Color(red: 0.7, green: 0.3, blue: 1.0)
        }
    }
}

#Preview {
    ResultView(
        data: RaceCompletionData(
            trackId: "albertpark",
            lapTime: 83.456,
            sectorTimes: [25.432, 28.891, 29.133],
            sectorColors: [.purple, .green, .yellow]
        ),
        onRetry: {},
        onBackToTracks: {}
    )
}
