import SwiftUI

struct ChampionshipView: View {
    @State private var standings: [GameCenterManager.ChampionshipStanding] = []
    @State private var localPlayer: GameCenterManager.ChampionshipStanding?
    @State private var isLoading = true

    var body: some View {
        Group {
            if !GameCenterManager.shared.isAuthenticated {
                Text("Sign in to Game Center")
                    .foregroundStyle(.secondary)
            } else if isLoading {
                ProgressView()
            } else if standings.isEmpty {
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
        List {
            Section {
                ForEach(Array(standings.enumerated()), id: \.element.playerName) { index, standing in
                    NavigationLink {
                        ChampionshipDetailView(standing: standing, rank: index + 1)
                    } label: {
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(.body, design: .monospaced).bold())
                                .frame(width: 36, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                MarqueeText(text: standing.playerName, font: .body, staticAlignment: .leading)
                                Text("\(standing.tracksEntered) track\(standing.tracksEntered == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(standing.totalPoints) pts")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(standing.isLocalPlayer ? .red : .primary)
                    }
                }
            } header: {
                Text("Standings")
            } footer: {
                if let local = localPlayer,
                   let rank = standings.firstIndex(where: { $0.isLocalPlayer }) {
                    Text("P\(rank + 1) — \(local.totalPoints) pts across \(local.tracksEntered) track\(local.tracksEntered == 1 ? "" : "s")")
                }
            }
        }
        .refreshable { await fetchStandings() }
    }

    private func fetchStandings() async {
        let result = await GameCenterManager.shared.calculateChampionship()
        standings = result.standings
        localPlayer = result.localPlayer
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
