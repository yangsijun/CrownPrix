import SwiftUI

struct HomeView: View {
    var onStart: () -> Void
    @ObservedObject private var gameCenterManager = GameCenterManager.shared
    @State private var selectedColor = CarColor.saved

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            VStack(spacing: 8) {
                Text("Crown Prix")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("The Tiniest Race on Your Wrist")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !gameCenterManager.isAuthenticated {
                    Text("Sign in to Game Center on your iPhone")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: .infinity)

            Spacer()

            Button(action: onStart) {
                Text("START")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CarColorPickerView(selectedColor: $selectedColor)
                } label: {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(selectedColor.swiftUIColor)
                }
            }
        }
    }
}

#Preview {
    HomeView(onStart: {})
}
