import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .caption
    var speed: Double = 30
    var gap: CGFloat = 40

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflows: Bool { textWidth > containerWidth && containerWidth > 0 }
    private var cycleWidth: CGFloat { textWidth + gap }

    var body: some View {
        GeometryReader { geo in
            if overflows {
                HStack(spacing: gap) {
                    label
                    label
                }
                .offset(x: offset)
            } else {
                label
                    .frame(width: geo.size.width, alignment: .center)
            }
        }
        .frame(height: 18)
        .clipped()
        .background(GeometryReader { g in
            Color.clear.onAppear { containerWidth = g.size.width }
        })
    }

    private var label: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .background(GeometryReader { g in
                Color.clear.onAppear {
                    if textWidth == 0 {
                        textWidth = g.size.width
                        tryStart()
                    }
                }
            })
    }

    private func tryStart() {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run { loop() }
        }
    }

    private func loop() {
        guard overflows else { return }
        offset = 0
        let duration = cycleWidth / speed

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            while !Task.isCancelled {
                withAnimation(.linear(duration: duration)) {
                    offset = -cycleWidth
                }
                try? await Task.sleep(for: .seconds(duration))
                offset = 0
            }
        }
    }
}

#Preview {
    MarqueeText(text: "Circuit de Monaco — Grand Prix", font: .system(.body, weight: .semibold))
        .padding()
}
