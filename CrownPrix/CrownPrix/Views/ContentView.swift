import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gcManager: GameCenterManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            if gcManager.isAuthenticated {
                TrackListView()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let subject = "Crown Prix Feedback"
                        let urlString = "mailto:yang@sijun.dev?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
                        if let url = URL(string: urlString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

#Preview("Signed Out") {
    ContentView()
        .environmentObject(GameCenterManager.shared)
        .preferredColorScheme(.dark)
        .tint(.red)
}

#Preview("Signed In") {
    ContentView()
        .environmentObject({
            let m = GameCenterManager.shared
            m.isAuthenticated = true
            return m
        }())
        .preferredColorScheme(.dark)
        .tint(.red)
}
