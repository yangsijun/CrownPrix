import SwiftUI

struct CarColorPickerView: View {
    @Binding var selectedColor: CarColor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CarPreviewView(color: selectedColor.swiftUIColor)
                    .frame(width: 28, height: 56)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.35))
                    )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 10) {
                    ForEach(CarColor.allCases) { color in
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Group {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(color.needsDarkCheckmark ? .black : .white)
                                    }
                                }
                            )
                            .onTapGesture {
                                selectedColor = color
                                CarColor.saved = color
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Color")
    }
}

/// Faithful SwiftUI replica of the SpriteKit CarNode, rotated so the nose points up.
/// Uses the exact same coordinates from CarNode.swift, transformed by 90° CCW.
struct CarPreviewView: View {
    var color: Color

    var body: some View {
        Canvas { context, size in
            // SpriteKit car faces +x. Rotate 90° CCW so nose points up in SwiftUI.
            // Mapping: canvas_x = -sk_y * s + w/2,  canvas_y = -sk_x * s + h/2
            let scale = min(size.width / 7.0, size.height / 15.6)

            func pt(_ sx: CGFloat, _ sy: CGFloat) -> CGPoint {
                CGPoint(x: -sy * scale + size.width / 2,
                        y: -sx * scale + size.height / 2)
            }

            func skRect(_ sx: CGFloat, _ sy: CGFloat, _ sw: CGFloat, _ sh: CGFloat) -> Path {
                var p = Path()
                p.move(to: pt(sx, sy))
                p.addLine(to: pt(sx + sw, sy))
                p.addLine(to: pt(sx + sw, sy + sh))
                p.addLine(to: pt(sx, sy + sh))
                p.closeSubpath()
                return p
            }

            let wheel = Color(white: 0.15)

            // Rear wheels
            context.fill(skRect(-6.0, -2.9, 3.0, 1.2), with: .color(wheel))
            context.fill(skRect(-6.0, 1.7, 3.0, 1.2), with: .color(wheel))

            // Rear wing
            context.fill(skRect(-7.0, -3.3, 0.8, 6.6), with: .color(color))

            // Body
            var body = Path()
            body.move(to: pt(7, 0))
            body.addLine(to: pt(4.5, 1.0))
            body.addLine(to: pt(-4, 1.3))
            body.addLine(to: pt(-6, 0.8))
            body.addLine(to: pt(-6, -0.8))
            body.addLine(to: pt(-4, -1.3))
            body.addLine(to: pt(4.5, -1.0))
            body.closeSubpath()
            context.fill(body, with: .color(color))

            // Front wheels
            context.fill(skRect(2.25, -2.5, 2.5, 1.0), with: .color(wheel))
            context.fill(skRect(2.25, 1.5, 2.5, 1.0), with: .color(wheel))

            // Front wing
            context.fill(skRect(5.5, -3.0, 0.8, 6.0), with: .color(color))

            // Cockpit
            let cc = pt(-1.5, 0)
            let r = 1.0 * scale
            context.fill(
                Path(ellipseIn: CGRect(x: cc.x - r, y: cc.y - r, width: r * 2, height: r * 2)),
                with: .color(Color(white: 0.2))
            )
        }
    }
}
