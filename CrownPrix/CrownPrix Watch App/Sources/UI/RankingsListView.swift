import SwiftUI

struct RankingsListView: View {
    var onSelectTrack: (TrackMetadata) -> Void

    private let tracks = TrackRegistry.sortedByName
    @State private var localEntries: [String: LeaderboardEntry] = [:]

    var body: some View {
        List(tracks) { meta in
            Button { onSelectTrack(meta) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meta.displayName)
                            .font(.system(.caption, weight: .medium))
                            .lineLimit(1)
                        Text("\(meta.country) \(meta.flag)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let entry = localEntries[meta.id] {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("#\(entry.rank)")
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
