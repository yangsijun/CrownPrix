import SwiftUI

struct ChampionshipView: View {
    @State private var entries: [ChampionshipEntry] = []
    @State private var localPlayer: ChampionshipEntry?
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
                Text("No standings yet")
                    .foregroundStyle(.secondary)
            } else {
                standingsContent
            }
        }
        .navigationTitle("Championship")
        .task { await fetchStandings() }
    }

    @ViewBuilder
    private var standingsContent: some View {
        let localInTop = localPlayer.map { local in entries.contains { $0.id == local.id } } ?? false

        List {
            Section {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
                if !localInTop, let local = localPlayer {
                    entryRow(local)
                }
            } header: {
                Text("Standings")
            } footer: {
                if let local = localPlayer, local.totalPoints > 0 {
                    Text("P\(local.rank) — \(local.totalPoints) pts across \(local.tracksEntered) track\(local.tracksEntered == 1 ? "" : "s")")
                }
            }
        }
        .refreshable {
            for track in TrackRegistry.allTracks {
                await SupabaseManager.shared.syncTrackFromGameCenter(trackId: track.id)
            }
            await fetchStandings()
        }
    }

    private func entryRow(_ entry: ChampionshipEntry) -> some View {
        NavigationLink {
            ChampionshipDetailView(playerId: entry.playerId, playerName: entry.playerName)
        } label: {
            HStack {
                Text("\(entry.rank)")
                    .font(.system(.body, design: .monospaced).bold())
                    .frame(width: 36, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(text: entry.playerName, font: .body, staticAlignment: .leading)
                    Text("\(entry.tracksEntered) track\(entry.tracksEntered == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(entry.totalPoints) pts")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(entry.isLocalPlayer ? .red : .primary)
        }
    }

    private func fetchStandings() async {
        errorMessage = nil
        do {
            let result = try await SupabaseManager.shared.loadStandings(limit: 50)
            entries = result
            localPlayer = result.first { $0.isLocalPlayer }
        } catch {
            errorMessage = "Unable to load championship"
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ChampionshipView()
    }
    .preferredColorScheme(.dark)
    .tint(.red)
}
