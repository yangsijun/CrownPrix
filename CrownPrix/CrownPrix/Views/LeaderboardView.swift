import SwiftUI

struct LeaderboardView: View {
    let leaderboardId: String
    let trackName: String
    let trackId: String

    @State private var entries: [LeaderboardEntry] = []
    @State private var localPlayer: LeaderboardEntry?
    @State private var sectorRecords: [GameCenterManager.SectorRecord?] = [nil, nil, nil]
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
                Text("No Lap Times yet")
                    .foregroundStyle(.secondary)
            } else {
                leaderboardContent
            }
        }
        .navigationTitle(trackName)
        .task { await fetchAll() }
    }

    @ViewBuilder
    private var leaderboardContent: some View {
        let localInTop = entries.contains { $0.isLocalPlayer }

        List {
            Section("Lap Times") {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            }
            
            if sectorRecords.contains(where: { $0 != nil }) {
                Section("Purple Sectors") {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { i in
                            if let record = sectorRecords[i] {
                                VStack(spacing: 4) {
                                    Text("S\(i + 1)")
                                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                                        .foregroundStyle(Color(red: 0.7, green: 0.3, blue: 1.0))
                                    Text(formatSectorTime(record.time))
                                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                                    Text(record.playerName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                VStack(spacing: 4) {
                                    Text("S\(i + 1)")
                                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text("--.---")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if !localInTop, let localPlayer {
                Section("Your Rank") {
                    entryRow(localPlayer)
                }
            }
        }
        .refreshable { await fetchAll() }
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

    private func formatSectorTime(_ time: TimeInterval) -> String {
        let totalMillis = Int(time * 1000)
        let secs = (totalMillis % 60000) / 1000
        let millis = totalMillis % 1000
        return String(format: "%02d.%03d", secs, millis)
    }

    private func fetchAll() async {
        async let scoresTask: () = fetchScores()
        async let sectorsTask: () = fetchSectorRecords()
        _ = await (scoresTask, sectorsTask)
        isLoading = false
    }

    private func fetchScores() async {
        let result = await GameCenterManager.shared.loadLeaderboard(leaderboardId: leaderboardId, topCount: 50)
        let rawEntries = result["entries"] as? [[String: Any]] ?? []
        entries = rawEntries.compactMap { LeaderboardEntry.from($0) }
        if let localDict = result["localPlayer"] as? [String: Any] {
            localPlayer = LeaderboardEntry.from(localDict)
        }
    }

    private func fetchSectorRecords() async {
        sectorRecords = await GameCenterManager.shared.loadSectorRecords(trackId: trackId)
    }
}

#Preview {
    NavigationStack {
        LeaderboardView(leaderboardId: "cp.laptime.albertpark", trackName: "Albert Park", trackId: "albertpark")
    }
    .preferredColorScheme(.dark)
    .tint(.red)
}
