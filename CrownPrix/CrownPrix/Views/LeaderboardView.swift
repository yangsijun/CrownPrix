import SwiftUI

struct LeaderboardView: View {
    let leaderboardId: String
    let trackName: String

    @State private var entries: [LeaderboardEntry] = []
    @State private var localPlayer: LeaderboardEntry?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if entries.isEmpty {
                Text("No rankings yet")
                    .foregroundStyle(.secondary)
            } else {
                leaderboardContent
            }
        }
        .navigationTitle(trackName)
        .task { await fetchScores() }
    }

    @ViewBuilder
    private var leaderboardContent: some View {
        let localInTop = entries.contains { $0.isLocalPlayer }

        List {
            ForEach(entries) { entry in
                entryRow(entry)
            }

            if !localInTop, let localPlayer {
                Section("Your Rank") {
                    entryRow(localPlayer)
                }
            }
        }
    }

    private func entryRow(_ entry: LeaderboardEntry) -> some View {
        HStack {
            Text("\(entry.rank)")
                .font(.system(.body, design: .monospaced).bold())
                .frame(width: 36, alignment: .leading)
            Text(entry.playerName)
                .lineLimit(1)
            Spacer()
            Text(TimeFormatter.format(entry.lapTime))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(entry.isLocalPlayer ? .red : .primary)
    }

    private func fetchScores() async {
        let result = await GameCenterManager.shared.loadLeaderboard(leaderboardId: leaderboardId, topCount: 50)
        let rawEntries = result["entries"] as? [[String: Any]] ?? []
        entries = rawEntries.compactMap { LeaderboardEntry.from($0) }
        if let localDict = result["localPlayer"] as? [String: Any] {
            localPlayer = LeaderboardEntry.from(localDict)
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        LeaderboardView(leaderboardId: "cp.laptime.albertpark", trackName: "Albert Park")
    }
    .preferredColorScheme(.dark)
    .tint(.red)
}
