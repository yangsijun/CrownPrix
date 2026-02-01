import SwiftUI

struct RankingsListView: View {
    private let tracks = TrackRegistry.allTracks
    @State private var localEntries: [String: LeaderboardEntry] = [:]
    @State private var isSyncing = false

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
                            if entry.rank != 0 {
                                Text("#\(entry.rank)")
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(.yellow)
                            }
                            Group {
                                if entry.lapTime == .zero {
                                    Text("-:--.---")
                                } else {
                                    Text(TimeFormatter.format(entry.lapTime))
                                }
                            }
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Rankings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard !isSyncing else { return }
                    isSyncing = true
                    syncLocalScores()
                } label: {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise")
                }
                .disabled(isSyncing)
            }
        }
        .task { await loadLocalEntries() }
    }

    private func syncLocalScores() {
        let allBests = PersistenceManager.getAllBestTimes()
        for (trackId, lapTime) in allBests {
            GameCenterManager.shared.submitScore(trackId: trackId, lapTime: lapTime)
            let sectorTimes = PersistenceManager.getBestSectorTimes(trackId: trackId)
            if sectorTimes.contains(where: { $0 != nil }) {
                GameCenterManager.shared.submitSectorTimes(trackId: trackId, times: sectorTimes)
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await loadLocalEntries()
            isSyncing = false
        }
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
