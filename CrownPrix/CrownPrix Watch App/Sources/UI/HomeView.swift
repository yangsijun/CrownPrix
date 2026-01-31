import SwiftUI

struct HomeView: View {
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Crown Prix")
                .font(.system(.title, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("The Tiniest Race on Your Wrist")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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

#Preview {
    HomeView(onStart: {})
}
