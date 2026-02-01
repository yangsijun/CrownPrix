import SwiftUI

struct TrackListView: View {
    private let tracks = TrackRegistry.allTracks
    @State private var localEntries: [String: LeaderboardEntry] = [:]

    var body: some View {
        List {
            Section {
                ForEach(tracks) { meta in
                    NavigationLink {
                        LeaderboardView(leaderboardId: meta.leaderboardId, trackName: meta.displayName)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(meta.displayName)
                                    .font(.body)
                                Spacer()
                            }
                            HStack {
                                Text("\(meta.flag) \(meta.country)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let entry = localEntries[meta.id] {
                                    Spacer()
                                    if entry.rank != 0 {
                                        Text("#\(entry.rank)")
                                            .font(.system(.caption, design: .monospaced, weight: .bold))
                                            .foregroundStyle(.yellow)
                                    }
                                    Group {
                                        if entry.lapTime == .zero {
                                            Text("-:--.---")
                                        } else {
                                            Text(TimeFormatter.format(entry.lapTime))
                                        }
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Label("Open Crown Prix on your Apple Watch", systemImage: "applewatch")
                    .font(.subheadline)
                    .textCase(nil)
            }
        }
        .navigationTitle("Crown Prix")
        .task { await loadLocalEntries() }
    }

    private func loadLocalEntries() async {
        guard GameCenterManager.shared.isAuthenticated else { return }
        await withTaskGroup(of: (String, LeaderboardEntry?).self) { group in
            for meta in tracks {
                group.addTask {
                    let result = await GameCenterManager.shared.loadLeaderboard(leaderboardId: meta.leaderboardId, topCount: 1)
                    if let localDict = result["localPlayer"] as? [String: Any] {
                        return (meta.id, LeaderboardEntry.from(localDict))
                    }
                    return (meta.id, nil)
                }
            }
            for await (trackId, entry) in group {
                if let entry { localEntries[trackId] = entry }
            }
        }
    }
}
