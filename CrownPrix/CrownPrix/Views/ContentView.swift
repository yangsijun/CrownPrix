import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gcManager: GameCenterManager

    var body: some View {
        NavigationStack {
            if gcManager.isAuthenticated {
                TrackListView()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Sign in to Game Center")
                        .font(.title3)
                    Text("Open Settings → Game Center to sign in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}
