import SwiftUI

struct TrackSelectView: View {
    var onTrackSelected: (TrackMetadata) -> Void
    var onBack: (() -> Void)? = nil

    private let tracks = TrackRegistry.sortedByName
    @State private var trackDataCache: [String: TrackData] = [:]
    @State private var selectedTrackId: String?

    var body: some View {
        TabView(selection: $selectedTrackId) {
            ForEach(tracks) { metadata in
                trackCard(metadata)
                    .tag(Optional(metadata.id))
            }
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            if selectedTrackId == nil { selectedTrackId = tracks.first?.id }
            loadAllTrackData()
        }
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onBack) { Image(systemName: "chevron.backward") }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if let id = selectedTrackId, let meta = TrackRegistry.track(byId: id) {
                        onTrackSelected(meta)
                    }
                } label: {
                    Text("RACE")
                        .foregroundStyle(.red)
                        .bold()
                }
            }
        }
    }

    @ViewBuilder
    private func trackCard(_ metadata: TrackMetadata) -> some View {
        VStack(spacing: 8) {
            if let data = trackDataCache[metadata.id] {
                trackOutline(data)
                    .frame(width: 70, height: 70)
            } else {
                Color.clear.frame(width: 70, height: 70)
            }
            
            VStack(spacing: 4) {
                MarqueeText(text: metadata.displayName, font: .system(.body, weight: .semibold))
                    .padding(.horizontal)
                
                Text("\(metadata.flag)\(metadata.country)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if let best = PersistenceManager.getBestTime(trackId: metadata.id) {
                    Text(TimeFormatter.format(best))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.yellow)
                } else {
                    Text("—")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
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

        func project(_ pt: TrackPoint) -> CGPoint {
            CGPoint(x: (pt.x - cx) * scale + 40, y: 40 - (pt.y - cy) * scale)
        }

        let startPos = project(points[0])
        let arrowTarget = project(points[min(10, points.count - 1)])
        let dx = arrowTarget.x - startPos.x
        let dy = arrowTarget.y - startPos.y
        let len = sqrt(dx * dx + dy * dy)
        let nx = len > 0 ? dx / len : 1
        let ny = len > 0 ? dy / len : 0
        let arrowLen: CGFloat = 6
        let arrowWidth: CGFloat = 3

        let tipX = startPos.x + nx * arrowLen
        let tipY = startPos.y + ny * arrowLen
        let leftX = startPos.x - ny * arrowWidth
        let leftY = startPos.y + nx * arrowWidth
        let rightX = startPos.x + ny * arrowWidth
        let rightY = startPos.y - nx * arrowWidth

        return AnyView(
            ZStack {
                Path { path in
                    for (i, pt) in sampled.enumerated() {
                        let p = project(pt)
                        if i == 0 { path.move(to: p) }
                        else { path.addLine(to: p) }
                    }
                    path.closeSubpath()
                }
                .stroke(Color.gray, lineWidth: 1.5)

                Path { path in
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: leftX, y: leftY))
                    path.addLine(to: CGPoint(x: rightX, y: rightY))
                    path.closeSubpath()
                }
                .fill(Color.red)

                Circle()
                    .fill(Color.red)
                    .frame(width: 4, height: 4)
                    .position(startPos)
            }
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

#Preview {
    TrackSelectView(onTrackSelected: { _ in })
}
