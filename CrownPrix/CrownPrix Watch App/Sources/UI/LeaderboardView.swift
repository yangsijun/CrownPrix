import SwiftUI

struct LeaderboardView: View {
    let leaderboardId: String
    let trackName: String
    var onBack: (() -> Void)? = nil

    @State private var data: LeaderboardData?
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
            } else if let data, data.topEntries.isEmpty {
                Text("No rankings yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let data {
                leaderboardContent(data)
            }
        }
        .navigationTitle(trackName)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onBack) { Image(systemName: "chevron.backward") }
                }
            }
        }
        .task {
            guard GameCenterManager.shared.isAuthenticated else { return }
            await fetchScores()
        }
    }

    @ViewBuilder
    private func leaderboardContent(_ data: LeaderboardData) -> some View {
        let localInTop = data.topEntries.contains { $0.isLocalPlayer }

        List {
            ForEach(data.topEntries) { entry in
                entryRow(entry)
            }

            if !localInTop, let local = data.localPlayer {
                Section {
                    entryRow(local)
                }
            }
        }
    }

    private func entryRow(_ entry: LeaderboardEntry) -> some View {
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

    private func fetchScores() async {
        do {
            data = try await GameCenterManager.shared.loadLeaderboard(
                leaderboardId: leaderboardId, topCount: 10
            )
            isLoading = false
        } catch {
            errorOccurred = true
            isLoading = false
        }
    }
}

#Preview {
    LeaderboardView(leaderboardId: "crownprix.albertpark", trackName: "Albert Park")
}
