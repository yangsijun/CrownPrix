import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gcManager: GameCenterManager
    @Environment(\.openURL) private var openURL
    @State private var showingAbout = false

    var body: some View {
        Group {
            if gcManager.isAuthenticated {
                TabView {
                    NavigationStack {
                        TrackListView(showingAbout: $showingAbout)
                    }
                    .tabItem {
                        Label("Rankings", systemImage: "list.number")
                    }

                    NavigationStack {
                        ChampionshipView()
                    }
                    .tabItem {
                        Label("Championship", systemImage: "trophy.fill")
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Sign in to Game Center")
                        .font(.title3)
                    Text("Open Settings \u{2192} Game Center to sign in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView(openURL: openURL)
        }
    }
}

private struct AboutView: View {
    let openURL: OpenURLAction
    @Environment(\.dismiss) private var dismiss

    private var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            if let icon = appIcon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                            Text("Crown Prix")
                                .font(.title2.bold())
                            Text("v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Developer") {
                    Button { openURL(URL(string: "https://sijun.dev")!) } label: {
                        Label("Website", systemImage: "globe")
                    }
                    .foregroundStyle(.red)
                    Button { openURL(URL(string: "https://github.com/yangsijun")!) } label: {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .foregroundStyle(.red)
                    Button { openURL(URL(string: "https://linkedin.com/in/yangsijun")!) } label: {
                        Label("LinkedIn", systemImage: "person.crop.rectangle")
                    }
                    .foregroundStyle(.red)
                }

                Section("Feedback") {
                    Button {
                        let subject = "Crown Prix Feedback"
                        let urlString = "mailto:yang@sijun.dev?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
                        if let url = URL(string: urlString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
