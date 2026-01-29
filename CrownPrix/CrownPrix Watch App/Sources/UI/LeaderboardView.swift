import SwiftUI

struct LeaderboardView: View {
    let leaderboardId: String
    let trackName: String

    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorOccurred = false

    var body: some View {
        Group {
            if !GameCenterManager.shared.isAuthenticated {
                Text("Sign in to Game Center on your iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if isLoading {
                ProgressView()
            } else if errorOccurred {
                Text("Unable to load rankings")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if entries.isEmpty {
                Text("No rankings yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                List(entries) { entry in
                    HStack {
                        Text("\(entry.rank)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .frame(width: 28, alignment: .leading)
                        Text(entry.playerName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(TimeFormatter.format(entry.lapTime))
                            .font(.system(.caption2, design: .monospaced))
                    }
                    .foregroundStyle(entry.isLocalPlayer ? .yellow : .primary)
                }
            }
        }
        .navigationTitle(trackName)
        .task {
            guard GameCenterManager.shared.isAuthenticated else { return }
            await fetchScores()
        }
    }

    private func fetchScores() async {
        do {
            entries = try await GameCenterManager.shared.loadTopScores(leaderboardId: leaderboardId, count: 25)
            isLoading = false
        } catch {
            errorOccurred = true
            isLoading = false
        }
    }
}
