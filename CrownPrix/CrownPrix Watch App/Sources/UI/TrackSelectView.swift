import SwiftUI

struct TrackSelectView: View {
    var onTrackSelected: (TrackMetadata) -> Void

    private let tracks = TrackRegistry.sortedByName
    @State private var trackDataCache: [String: TrackData] = [:]

    var body: some View {
        TabView {
            ForEach(tracks) { metadata in
                trackCard(metadata)
                    .onTapGesture { onTrackSelected(metadata) }
            }
        }
        .tabViewStyle(.verticalPage)
        .onAppear { loadAllTrackData() }
    }

    @ViewBuilder
    private func trackCard(_ metadata: TrackMetadata) -> some View {
        VStack(spacing: 6) {
            if let data = trackDataCache[metadata.id] {
                trackOutline(data)
                    .frame(width: 80, height: 80)
            } else {
                Color.clear.frame(width: 80, height: 80)
            }

            Text(metadata.displayName)
                .font(.system(.footnote, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(metadata.country)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let best = PersistenceManager.getBestTime(trackId: metadata.id) {
                Text(TimeFormatter.format(best))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.yellow)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func trackOutline(_ data: TrackData) -> some View {
        let points = data.points
        let step = max(1, points.count / 80)
        let sampled = stride(from: 0, to: points.count, by: step).map { points[$0] }

        guard let minX = sampled.map(\.x).min(),
              let maxX = sampled.map(\.x).max(),
              let minY = sampled.map(\.y).min(),
              let maxY = sampled.map(\.y).max() else {
            return AnyView(EmptyView())
        }

        let bboxW = maxX - minX
        let bboxH = maxY - minY
        let scale = min(76 / max(bboxW, 1), 76 / max(bboxH, 1))
        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2

        return AnyView(
            Path { path in
                for (i, pt) in sampled.enumerated() {
                    let x = (pt.x - cx) * scale + 40
                    let y = 40 - (pt.y - cy) * scale
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
            }
            .stroke(Color.gray, lineWidth: 1.5)
        )
    }

    private func loadAllTrackData() {
        for metadata in tracks {
            if let data = try? TrackLoader.loadTrackData(trackId: metadata.id) {
                trackDataCache[metadata.id] = data
            }
        }
    }
}
