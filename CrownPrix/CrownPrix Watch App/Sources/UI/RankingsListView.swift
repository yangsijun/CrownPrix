import SwiftUI

struct RankingsListView: View {
    private let tracks = TrackRegistry.sortedByName
    @State private var localEntries: [String: LeaderboardEntry] = [:]

    var body: some View {
        List(tracks) { meta in
            NavigationLink {
                LeaderboardView(
                    leaderboardId: meta.leaderboardId,
                    trackName: meta.displayName
                )
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    MarqueeText(text: meta.displayName, font: .system(.caption, weight: .medium), staticAlignment: .leading)
                    HStack {
                        Text("\(meta.country) \(meta.flag)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    if let entry = localEntries[meta.id] {
                        HStack(spacing: 8) {
                            Spacer()
                            Group {
                                if entry.rank == 0 {
                                    Text("N/A")
                                } else {
                                    Text("#\(entry.rank)")
                                }
                            }
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(.yellow)
                            Text(TimeFormatter.format(entry.lapTime))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Rankings")
        .task { await loadLocalEntries() }
    }

    private func loadLocalEntries() async {
        guard GameCenterManager.shared.isAuthenticated else { return }
        await withTaskGroup(of: (String, LeaderboardEntry?).self) { group in
            for meta in tracks {
                group.addTask {
                    let entry = try? await GameCenterManager.shared
                        .loadLeaderboard(leaderboardId: meta.leaderboardId, topCount: 1)
                        .localPlayer
                    return (meta.id, entry)
                }
            }
            for await (trackId, entry) in group {
                if let entry { localEntries[trackId] = entry }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RankingsListView()
    }
}
