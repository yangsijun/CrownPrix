import SwiftUI

struct TrackListView: View {
    private let tracks = TrackRegistry.allTracks

    var body: some View {
        List(tracks) { meta in
            NavigationLink {
                LeaderboardView(leaderboardId: meta.leaderboardId, trackName: meta.displayName)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meta.displayName)
                            .font(.body)
                        Text("\(meta.flag) \(meta.country)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Crown Prix")
    }
}
