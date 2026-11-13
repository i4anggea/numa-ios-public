import SwiftUI

// Small visual vocabulary shared by the dashboard, savings and privacy cover.
enum NumaStyle {
    static let accent = Color(uiColor: .systemBlue)
    static let cardRadius: CGFloat = 22
}

struct NumaMark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.70))
            path.addLine(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.30))
            path.addLine(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.70))
            path.addLine(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.30))
        }
    }
}

struct NumaLogo: View {
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26).fill(Color(red: 0.07, green: 0.24, blue: 0.47))
            NumaMark().stroke(.white, style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct GoalProgress: View {
    var saved: Cents
    var target: Cents
    @AppStorage("hideAmounts") private var hidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var fraction: Double { target > 0 ? min(1, max(0, Double(saved) / Double(target))) : 0 }
    private var milestone: Int { Int(fraction * 4) }
    private var milestoneMessage: String? {
        switch milestone {
        case 1: "Primer 25 % reservado. Tu meta toma forma."
        case 2: "Llegaste a la mitad de tu meta."
        case 3: "75 % reservado. Cada paso suma."
        case 4: "Meta alcanzada. ¡Lo lograste!"
        default: nil
        }
    }
    var body: some View {
        if hidden {
            Text("Progreso oculto").font(.caption).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: fraction).tint(NumaStyle.accent)
                    .accessibilityLabel("Avance de la meta")
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: fraction)
                Text("\(Int(fraction * 100)) % de tu meta")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("goal.progressPercent")
                if let milestoneMessage {
                    Label(milestoneMessage, systemImage: milestone == 4 ? "checkmark.seal" : "sparkle")
                        .font(.caption).foregroundStyle(NumaStyle.accent)
                        .accessibilityIdentifier("goal.milestone")
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: milestone)
                }
            }
        }
    }
}
