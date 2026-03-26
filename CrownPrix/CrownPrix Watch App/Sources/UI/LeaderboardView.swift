import SwiftUI

struct LeaderboardView: View {
    let leaderboardId: String
    let trackName: String
    var onBack: (() -> Void)? = nil
    var onStartRace: (() -> Void)? = nil
    var trackId: String? = nil
    var pendingSubmission: Task<Void, Never>? = nil
    var submittedLapTime: TimeInterval? = nil

    @State private var data: LeaderboardData?
    @State private var isLoading = true
    @State private var errorOccurred = false
    @State private var isSyncing = false
    @State private var sectorRecords: [GameCenterManager.SectorRecord?] = [nil, nil, nil]

    var body: some View {
        Group {
            #if DEBUG
            let needsAuth = !GameCenterManager.shared.isAuthenticated && !GameCenterManager.isDevLeaderboard(leaderboardId)
            #else
            let needsAuth = !GameCenterManager.shared.isAuthenticated
            #endif
            if needsAuth {
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
            ToolbarItem(placement: .topBarTrailing) {
                if let onStartRace {
                    Button(action: onStartRace) {
                        Image(systemName: "flag.checkered")
                    }
                } else {
                    Button {
                        Task {
                            isLoading = true
                            await fetchAll()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            isLoading = true
            errorOccurred = false
            data = nil
            #if DEBUG
            guard GameCenterManager.shared.isAuthenticated || GameCenterManager.isDevLeaderboard(leaderboardId) else { return }
            #else
            guard GameCenterManager.shared.isAuthenticated else { return }
            #endif
            await pendingSubmission?.value
            await fetchAll()

            // Game Center has eventual consistency — a submitted score may not
            // appear in loadEntries immediately. Only retry when a new personal
            // best was submitted but not yet reflected in the leaderboard.
            if let submitted = submittedLapTime {
                let gcBest = data?.localPlayer?.lapTime ?? .infinity
                if submitted < gcBest {
                    isSyncing = true
                    for _ in 0..<5 {
                        try? await Task.sleep(for: .seconds(2))
                        await fetchAll()
                        if data?.localPlayer?.lapTime ?? .infinity <= submitted { break }
                    }
                    isSyncing = false
                }
            }
        }
    }

    @ViewBuilder
    private func leaderboardContent(_ data: LeaderboardData) -> some View {
        let localInTop = data.topEntries.contains { $0.isLocalPlayer }

        List {
            Section {
                ForEach(data.topEntries) { entry in
                    entryRow(entry)
                }
                if !localInTop, let local = data.localPlayer {
                    entryRow(local)
                }
            } header: {
                if isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("Syncing...")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } footer: {
                if let local = data.localPlayer, data.totalPlayerCount > 0 {
                    Text("P\(local.rank) out of \(data.totalPlayerCount) Drivers")
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
        do {
            data = try await GameCenterManager.shared.loadLeaderboard(
                leaderboardId: leaderboardId, topCount: 10
            )
        } catch {
            errorOccurred = true
        }
    }

    private func fetchSectorRecords() async {
        guard let trackId else { return }
        sectorRecords = await GameCenterManager.shared.loadSectorRecords(trackId: trackId)
    }
}

#Preview {
    LeaderboardView(leaderboardId: "crownprix.albertpark", trackName: "Albert Park")
}
