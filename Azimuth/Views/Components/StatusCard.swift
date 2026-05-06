import SwiftUI

struct StatusCard: View {
    let status: SendStatus
    let lastSent: Date?
    let nextSend: Date?
    let isTracking: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(dotColor.opacity(0.4), lineWidth: 6)
                            .scaleEffect(isTracking ? 1.6 : 1.0)
                            .opacity(isTracking ? 0 : 0.6)
                            .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: isTracking)
                    )
                Text(headlineText)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 16) {
                infoColumn(icon: "clock", title: "Last sent", value: lastSentText)
                Divider().frame(height: 28).opacity(0.5)
                infoColumn(icon: "calendar.badge.clock", title: "Next", value: nextSendText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 0.7)
                )
                .shadow(color: Theme.skyDeep.opacity(0.12), radius: 18, x: 0, y: 8)
        )
    }

    private var dotColor: Color {
        switch status {
        case .sending:        return Theme.sky
        case .success:        return Theme.success
        case .failure:        return Theme.danger
        case .idle:           return isTracking ? Theme.sky : .secondary
        }
    }

    private var headlineText: String {
        switch status {
        case .sending:                    return "Sending now…"
        case .success:                    return "Last send succeeded"
        case .failure(let message, _):    return message
        case .idle:                       return isTracking ? "Tracking — waiting for next send" : "Idle"
        }
    }

    private var lastSentText: String {
        guard let lastSent else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSent, relativeTo: Date())
    }

    private var nextSendText: String {
        guard isTracking, let nextSend else { return "—" }
        let interval = nextSend.timeIntervalSinceNow
        if interval <= 0 { return "Soon" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: nextSend, relativeTo: Date())
    }

    private func infoColumn(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.sky)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
    }
}
