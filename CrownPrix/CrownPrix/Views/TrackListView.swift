import SwiftUI

struct TrackListView: View {
    private let tracks = TrackRegistry.allTracks
    @State private var localEntries: [String: LeaderboardEntry] = [:]
    @Binding var showingAbout: Bool

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ChampionshipView()
                } label: {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("World Drivers' Championship")
                            .font(.body)
                        Spacer()
                    }
                }
            }

            Section {
                ForEach(tracks) { meta in
                    NavigationLink {
                        LeaderboardView(leaderboardId: meta.leaderboardId, trackName: meta.displayName, trackId: meta.id)
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
                                        Text("P\(entry.rank)")
                                            .font(.system(.caption, design: .monospaced, weight: .bold))
                                            .foregroundStyle(rankColor(for: entry.rank))
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
                HStack(spacing: 4) {
                    Image(systemName: "applewatch")
                    Text("Open Crown Prix on your Apple Watch")
                        .bold()
                        .font(.subheadline)
                }
                .foregroundStyle(.red.opacity(0.8))
            }
        }
        .navigationTitle("Crown Prix")
        .refreshable { await loadLocalEntries() }
        .task { await loadLocalEntries() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAbout = true } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
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

    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.7, green: 0.3, blue: 1.0)
        case 2, 3: return .green
        case 4...10: return .yellow
        default: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        TrackListView(showingAbout: .constant(false))
    }
    .preferredColorScheme(.dark)
    .tint(.red)
}
