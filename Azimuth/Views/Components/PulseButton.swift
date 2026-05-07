import SwiftUI

struct PulseButton: View {
    let isActive: Bool
    let isSending: Bool
    let action: () -> Void

    @State private var press = false

    private let cycleDuration: Double = 2.4
    private let ringCount = 3
    private let stagger: Double = 0.8

    var body: some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
            action()
        } label: {
            ZStack {
                ringsContainer

                Circle()
                    .fill(Theme.pulseGradient)
                    .frame(width: 200, height: 200)
                    .shadow(color: Theme.sky.opacity(isActive ? 0.55 : 0.25), radius: isActive ? 24 : 12, x: 0, y: 8)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    )
                    .scaleEffect(press ? 0.95 : 1.0)
                    .saturation(isActive ? 1.0 : 0.55)
                    .animation(.smooth(duration: 0.45), value: isActive)
                    .animation(.smooth(duration: 0.45), value: isSending)

                VStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.wiggle, options: .repeating, isActive: isSending)
                    Text(buttonLabel)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.92))
                        .contentTransition(.opacity)
                }
                .animation(.smooth(duration: 0.4), value: iconName)
                .animation(.smooth(duration: 0.4), value: buttonLabel)
            }
            .frame(width: 260, height: 260)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { down in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                press = down
            }
        })
        .accessibilityLabel(buttonLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var ringsContainer: some View {
        ZStack {
            rings(outward: true, strokeOpacity: 0.35)
                .opacity(isActive ? 1 : 0)
            rings(outward: false, strokeOpacity: 0.32)
                .opacity(isActive ? 0 : 1)
        }
        .animation(.easeInOut(duration: 0.45), value: isActive)
    }

    private func rings(outward: Bool, strokeOpacity: Double) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<ringCount, id: \.self) { i in
                    let ringTime = t + Double(i) * stagger
                    let phase = ringTime.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
                    let eased = 1 - pow(1 - phase, 2)
                    let scale = outward
                        ? 1.0 + eased * 0.45
                        : 1.45 - eased * 0.45
                    let opacity = ringOpacity(phase: phase, outward: outward)

                    Circle()
                        .stroke(Theme.sky.opacity(strokeOpacity), lineWidth: 1.5)
                        .frame(width: 220, height: 220)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
            }
        }
    }

    private func ringOpacity(phase: Double, outward: Bool) -> Double {
        let maxOpacity = 0.9
        if outward {
            let introEnd = 0.08
            if phase < introEnd {
                return (phase / introEnd) * maxOpacity
            }
            let t = (phase - introEnd) / (1 - introEnd)
            let eased = 1 - pow(1 - t, 2)
            return (1 - eased) * maxOpacity
        } else {
            let peakAt = 0.85
            if phase < peakAt {
                let t = phase / peakAt
                return t * t * maxOpacity
            }
            let t = (phase - peakAt) / (1 - peakAt)
            return (1 - t) * maxOpacity
        }
    }

    private var iconName: String {
        isActive ? "location.fill" : "location.slash.fill"
    }

    private var buttonLabel: String {
        if isSending { return "Sending" }
        return isActive ? "Tracking" : "Start"
    }
}

#Preview {
    ZStack {
        CanvasBackground()
        PulseButton(isActive: true, isSending: false, action: {})
    }
}
