import SwiftUI

struct ChampionshipDetailView: View {
    let playerId: String
    let playerName: String

    @State private var detail: ChampionshipDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if let detail {
                detailContent(detail)
            }
        }
        .navigationTitle(playerName)
        .task { await fetchDetail() }
    }

    @ViewBuilder
    private func detailContent(_ detail: ChampionshipDetail) -> some View {
        List {
            Section {
                HStack {
                    Text("P\(detail.rank)")
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(rankColor(for: detail.rank))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(detail.totalPoints) pts")
                            .font(.system(.title3, design: .monospaced).bold())
                        Text("\(detail.tracksEntered) track\(detail.tracksEntered == 1 ? "" : "s") entered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Circuit Breakdown") {
                ForEach(detail.trackResults) { result in
                    HStack {
                        Text(result.flag)
                        MarqueeText(text: result.trackName, font: .body, staticAlignment: .leading)
                        Spacer()
                        if result.rank > 0 {
                            Text("P\(result.rank)")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(rankColor(for: result.rank))
                        }
                        Text("\(result.points) pts")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
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

    private func fetchDetail() async {
        do {
            detail = try await SupabaseManager.shared.loadPlayerDetail(playerId: playerId)
            if detail == nil { errorMessage = "Player not found" }
        } catch {
            errorMessage = "Unable to load details"
        }
        isLoading = false
    }
}
