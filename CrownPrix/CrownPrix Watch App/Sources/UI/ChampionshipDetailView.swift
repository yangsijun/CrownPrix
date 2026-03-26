import SwiftUI

struct ChampionshipDetailView: View {
    let playerName: String

    @State private var detail: ChampionshipDetail?
    @State private var isLoading = true
    @State private var errorOccurred = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if errorOccurred {
                Text("Unable to load details")
                    .font(.footnote)
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
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(rankColor(for: detail.rank))
                    Spacer()
                    Text("\(detail.totalPoints) pts")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
            } header: {
                Text("\(detail.tracksEntered) track\(detail.tracksEntered == 1 ? "" : "s") entered")
                    .font(.caption2)
            }

            Section("Circuits") {
                ForEach(detail.trackResults) { result in
                    VStack(alignment: .leading, spacing: 0) {
                        MarqueeText(text: "\(result.flag) \(result.trackName)", font: .caption2, staticAlignment: .leading)
                        HStack(spacing: 8) {
                            Spacer()
                            if result.rank > 0 {
                                Text("P\(result.rank)")
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(rankColor(for: result.rank))
                            }
                            Text("\(result.points) pts")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
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
            detail = try await GameCenterManager.shared.loadChampionshipDetail(playerName: playerName)
            if detail == nil { errorOccurred = true }
        } catch {
            errorOccurred = true
        }
        isLoading = false
    }
}
