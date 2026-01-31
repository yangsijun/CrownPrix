import SwiftUI

enum AppScreen {
    case home
    case trackSelect
    case race(trackId: String)
    case result(trackId: String, lapTime: TimeInterval)
    case trackLeaderboard(trackId: String, trackName: String)
}

struct ContentView: View {
    @State private var screen: AppScreen = .home

    var body: some View {
        switch screen {
        case .home:
            TabView {
                HomeView(onStart: { screen = .trackSelect })

                RankingsListView { meta in
                    screen = .trackLeaderboard(trackId: meta.id, trackName: meta.displayName)
                }
            }
            .tabViewStyle(.page)

        case .trackSelect:
            NavigationStack {
                TrackSelectView(
                    onTrackSelected: { metadata in screen = .race(trackId: metadata.id) },
                    onBack: { screen = .home }
                )
            }

        case .race(let trackId):
            RaceView(
                trackId: trackId,
                onLapComplete: { lapTime in screen = .result(trackId: trackId, lapTime: lapTime) },
                onDNF: { screen = .trackSelect }
            )

        case .result(let trackId, let lapTime):
            ResultView(
                trackId: trackId,
                lapTime: lapTime,
                onRetry: { screen = .race(trackId: trackId) },
                onBackToTracks: { screen = .trackSelect },
                onShowLeaderboard: {
                    if let track = TrackRegistry.track(byId: trackId) {
                        screen = .trackLeaderboard(trackId: trackId, trackName: track.displayName)
                    }
                }
            )
            .onAppear {
                GameCenterManager.shared.submitScore(trackId: trackId, lapTime: lapTime)
            }

        case .trackLeaderboard(let trackId, let trackName):
            if let track = TrackRegistry.track(byId: trackId) {
                NavigationStack {
                    LeaderboardView(
                        leaderboardId: track.leaderboardId,
                        trackName: trackName,
                        onBack: { screen = .home }
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
