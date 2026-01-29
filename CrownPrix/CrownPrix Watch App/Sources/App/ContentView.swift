import SwiftUI

enum AppScreen {
    case home
    case trackSelect
    case race(trackId: String)
    case result(trackId: String, lapTime: TimeInterval)
    case leaderboard(trackId: String, trackName: String)
}

struct ContentView: View {
    @State private var screen: AppScreen = .home

    var body: some View {
        switch screen {
        case .home:
            HomeView {
                screen = .trackSelect
            }

        case .trackSelect:
            TrackSelectView { metadata in
                screen = .race(trackId: metadata.id)
            }

        case .race(let trackId):
            RaceView(trackId: trackId) { lapTime in
                screen = .result(trackId: trackId, lapTime: lapTime)
            }

        case .result(let trackId, let lapTime):
            ResultView(
                trackId: trackId,
                lapTime: lapTime,
                onRetry: { screen = .race(trackId: trackId) },
                onBackToTracks: { screen = .trackSelect },
                onShowLeaderboard: {
                    if let track = TrackRegistry.track(byId: trackId) {
                        screen = .leaderboard(trackId: trackId, trackName: track.displayName)
                    }
                }
            )
            .onAppear {
                GameCenterManager.shared.submitScore(trackId: trackId, lapTime: lapTime)
            }

        case .leaderboard(let trackId, let trackName):
            if let track = TrackRegistry.track(byId: trackId) {
                LeaderboardView(leaderboardId: track.leaderboardId, trackName: trackName)
            }
        }
    }
}
