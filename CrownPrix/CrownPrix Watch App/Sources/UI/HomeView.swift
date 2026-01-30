import SwiftUI

struct HomeView: View {
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Crown Prix")
                .font(.system(.title, design: .rounded, weight: .bold))

            Text("F1 Time Attack")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onStart) {
                Text("START")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
