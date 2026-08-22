import SwiftUI

struct ResultView: View {
    let data: RaceCompletionData
    var onRetry: () -> Void
    var onBackToTracks: () -> Void
    var onShowLeaderboard: (() -> Void)? = nil

    @State private var savedRecord = false
    @State private var globalBestTime: TimeInterval?
    @State private var isGlobalFastest = false

    private var previousBest: TimeInterval? { data.previousBestLapTime }

    init(data: RaceCompletionData, onRetry: @escaping () -> Void, onBackToTracks: @escaping () -> Void, onShowLeaderboard: (() -> Void)? = nil, previewGlobalBest: TimeInterval? = nil) {
        self.data = data
        self.onRetry = onRetry
        self.onBackToTracks = onBackToTracks
        self.onShowLeaderboard = onShowLeaderboard
        _globalBestTime = State(initialValue: previewGlobalBest)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    titleSection
                    
                    Text(TimeFormatter.format(data.lapTime))
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                    
                    sectorTimesSection
                    recordSection
                }

                VStack(spacing: 10) {
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
    private var titleSection: some View {
        let isPersonalBest = previousBest == nil || data.lapTime <= previousBest!
        // Compare at millisecond precision: GC stores truncated ms, and the P1
        // entry is often our own just-submitted score — full-precision compare
        // would call this lap "slower" than itself by its sub-ms remainder.
        let isFastestLap = isGlobalFastest
            || globalBestTime.map { Int(data.lapTime * 1000) <= Int(($0 * 1000).rounded()) } ?? false
        
        Group {
            if isFastestLap {
                Text("FASTEST LAP!!")
                    .foregroundStyle(Color(red: 0.7, green: 0.3, blue: 1.0))
            } else if isPersonalBest {
                Text("NEW RECORD!")
                    .foregroundStyle(.green)
            } else {
                Text("FINISH")
                    .foregroundStyle(.yellow)
            }
        }
        .font(.system(.headline, design: .rounded, weight: .bold))
    }

    @ViewBuilder
    private var recordSection: some View {
        VStack(spacing: 4) {
            if let globalBest = globalBestTime {
                HStack(spacing: 4) {
                    Text("P1: \(TimeFormatter.format(globalBest))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    let gap = Double(Int(data.lapTime * 1000) - Int((globalBest * 1000).rounded())) / 1000.0
                    Text(String(format: "%+.3f", gap))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(gap < 0 ? .green : .red)
                }
            }

            if let best = previousBest {
                HStack(spacing: 4) {
                    Text("Best: \(TimeFormatter.format(best))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    let delta = data.lapTime - best
                    Text(String(format: "%+.3f", delta))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(delta < 0 ? .green : .red)
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
                    Text("S\(i + 1)")
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
        guard let track = TrackRegistry.track(byId: data.trackId) else { return }
        // No local isAuthenticated gate: the watch's auth flag can lag the
        // phone's, and the phone already reports failures via WCError.loadFailed.
        // Our own submission races this read (both start when the result screen
        // appears), and reading a board GC hasn't settled yet can fail — retry
        // briefly instead of giving up on the first miss.
        for attempt in 0..<4 {
            if attempt > 0 { try? await Task.sleep(for: .seconds(1.5)) }
            guard let lb = try? await GameCenterManager.shared.loadLeaderboard(
                leaderboardId: track.leaderboardId, topCount: 1
            ) else { continue }
            if let first = lb.topEntries.first {
                globalBestTime = first.lapTime
                if first.isLocalPlayer { isGlobalFastest = true }
            } else {
                // Board is genuinely empty — nobody is faster than this lap.
                isGlobalFastest = true
            }
            return
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

#Preview("World Record") {
    ResultView(
        data: RaceCompletionData(
            trackId: "preview_wr",
            lapTime: 78.123,
            sectorTimes: [23.456, 26.789, 27.878],
            sectorColors: [.purple, .purple, .green],
            previousBestLapTime: 80.500
        ),
        onRetry: {},
        onBackToTracks: {},
        previewGlobalBest: 79.000
    )
}

#Preview("New Record") {
    ResultView(
        data: RaceCompletionData(
            trackId: "preview_nr",
            lapTime: 83.456,
            sectorTimes: [25.432, 28.100, 29.924],
            sectorColors: [.green, .purple, .yellow],
            previousBestLapTime: 84.000
        ),
        onRetry: {},
        onBackToTracks: {},
        previewGlobalBest: 80.000
    )
}

#Preview("Not Beaten") {
    ResultView(
        data: RaceCompletionData(
            trackId: "preview_nb",
            lapTime: 83.456,
            sectorTimes: [25.432, 28.891, 29.133],
            sectorColors: [.yellow, .green, .yellow],
            previousBestLapTime: 80.000
        ),
        onRetry: {},
        onBackToTracks: {},
        previewGlobalBest: 78.500
    )
}
