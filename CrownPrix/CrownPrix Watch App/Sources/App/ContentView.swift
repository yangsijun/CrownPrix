import SwiftUI

enum AppScreen {
    case home
    case trackSelect
    case race(trackId: String)
    case result(data: RaceCompletionData)
    case trackLeaderboard(trackId: String, trackName: String)
}

struct ContentView: View {
    @State private var screen: AppScreen = .home
    @State private var lastTrackId: String?
    @State private var lastResultData: RaceCompletionData?
    @State private var scoreSubmissionTask: Task<Void, Never>?

    var body: some View {
        switch screen {
        case .home:
            TabView {
                HomeView(onStart: { screen = .trackSelect })

                NavigationStack {
                    RankingsListView(onStartRace: { trackId in
                        lastTrackId = trackId
                        screen = .race(trackId: trackId)
                    })
                }

                NavigationStack {
                    ChampionshipView()
                }
            }
            .tabViewStyle(.page)

        case .trackSelect:
            NavigationStack {
                TrackSelectView(
                    onTrackSelected: { metadata in
                        lastTrackId = metadata.id
                        screen = .race(trackId: metadata.id)
                    },
                    onBack: { screen = .home },
                    initialTrackId: lastTrackId
                )
            }

        case .race(let trackId):
            RaceView(
                trackId: trackId,
                onLapComplete: { data in screen = .result(data: data) },
                onDNF: { screen = .trackSelect }
            )

        case .result(let data):
            ResultView(
                data: data,
                onRetry: { screen = .race(trackId: data.trackId) },
                onBackToTracks: { screen = .trackSelect },
                onShowLeaderboard: {
                    if let track = TrackRegistry.track(byId: data.trackId) {
                        screen = .trackLeaderboard(trackId: data.trackId, trackName: track.displayName)
                    }
                }
            )
            .onAppear {
                lastResultData = data
                scoreSubmissionTask = Task {
                    try? await GameCenterManager.shared.submitScore(trackId: data.trackId, lapTime: data.lapTime)
                }
            }

        case .trackLeaderboard(let trackId, let trackName):
            if let track = TrackRegistry.track(byId: trackId) {
                NavigationStack {
                    LeaderboardView(
                        leaderboardId: track.leaderboardId,
                        trackName: trackName,
                        onBack: {
                            if let data = lastResultData {
                                screen = .result(data: data)
                            } else {
                                screen = .home
                            }
                        },
                        trackId: trackId,
                        pendingSubmission: scoreSubmissionTask,
                        submittedLapTime: lastResultData?.lapTime
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
