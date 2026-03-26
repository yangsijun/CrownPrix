import SwiftUI

struct ChampionshipDetailView: View {
    let standing: GameCenterManager.ChampionshipStanding
    let rank: Int

    var body: some View {
        List {
            Section {
                HStack {
                    Text("P\(rank)")
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(rankColor(for: rank))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(standing.totalPoints) pts")
                            .font(.system(.title3, design: .monospaced).bold())
                        Text("\(standing.tracksEntered) track\(standing.tracksEntered == 1 ? "" : "s") entered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Circuit Breakdown") {
                ForEach(standing.trackResults, id: \.trackId) { result in
                    HStack {
                        Text(result.flag)
                        MarqueeText(text: result.trackName, font: .body, staticAlignment: .leading)
                        if result.rank > 0 {
                            Text("P\(result.rank)")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(rankColor(for: result.rank))
                                .fixedSize()
                        }
                        Text("\(result.points) pts")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
            }
        }
        .navigationTitle(standing.playerName)
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
