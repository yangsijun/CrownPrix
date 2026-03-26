import SwiftUI

struct ChampionshipView: View {
    @State private var entries: [ChampionshipEntry] = []
    @State private var localPlayer: ChampionshipEntry?
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
                Text("Unable to load championship")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if entries.isEmpty {
                Text("No standings yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                standingsContent
            }
        }
        .navigationTitle("Championship")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        isLoading = true
                        await fetchStandings()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await fetchStandings()
        }
    }

    @ViewBuilder
    private var standingsContent: some View {
        let localInTop = localPlayer.map { local in entries.contains { $0.id == local.id } } ?? false

        List {
            if let local = localPlayer {
                Section {
                    HStack {
                        Text("P\(local.rank)")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(rankColor(for: local.rank))
                        Spacer()
                        Text("\(local.totalPoints) pts")
                            .font(.system(.caption2, design: .monospaced, weight: .semibold))
                            .foregroundStyle(.yellow)
                    }
                } header: {
                    Text("Your Standing")
                        .font(.caption2)
                }
            }

            Section {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
                if !localInTop, let local = localPlayer {
                    entryRow(local)
                }
            } footer: {
                if let local = localPlayer {
                    Text("P\(local.rank) — \(local.tracksEntered) track\(local.tracksEntered == 1 ? "" : "s") entered")
                }
            }
        }
    }

    private func entryRow(_ entry: ChampionshipEntry) -> some View {
        NavigationLink {
            ChampionshipDetailView(playerId: entry.playerId, playerName: entry.playerName)
        } label: {
            HStack {
                Text("\(entry.rank)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .frame(width: 28, alignment: .leading)
                MarqueeText(text: entry.playerName, font: .caption, staticAlignment: .leading)
                Spacer()
                Text("\(entry.totalPoints)p")
                    .font(.system(.caption2, design: .monospaced))
            }
            .foregroundStyle(entry.isLocalPlayer ? .yellow : .primary)
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

    private func fetchStandings() async {
        errorOccurred = false
        do {
            let result = try await GameCenterManager.shared.loadChampionshipStandings(topCount: 20)
            entries = result.entries
            localPlayer = result.localPlayer
        } catch {
            errorOccurred = true
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ChampionshipView()
    }
}
