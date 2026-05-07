import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AzimuthEngine.self) private var engine
    @Environment(TabRouter.self) private var router

    @State private var nowTick = Date()
    @State private var pendingStartTap = false

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var settings = engine.settings

        ZStack {
            CanvasBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                PulseButton(
                    isActive: engine.isTracking,
                    isSending: engine.isAnySending,
                    action: handleMainTap
                )
                .opacity(settings.endpoints.isEmpty ? 0.5 : 1.0)
                .allowsHitTesting(!settings.endpoints.isEmpty)

                Spacer(minLength: 16)

                if settings.endpoints.isEmpty {
                    emptyStateCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                } else {
                    VStack(spacing: 14) {
                        StatusCard(
                            status: engine.aggregateStatus,
                            lastSent: engine.aggregateLastSentDate,
                            nextSend: engine.nextSendDate,
                            isTracking: engine.isTracking
                        )

                        MapPreview(location: engine.location.lastLocation)

                        sendAllButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
        }
        .onReceive(tick) { now in nowTick = now }
        .alert("Add an endpoint first", isPresented: Binding(
            get: { needsEndpointAlert },
            set: { _ in pendingStartTap = false }
        )) {
            Button("Open Settings") {
                pendingStartTap = false
                router.selection = .settings
            }
            Button("Cancel", role: .cancel) {
                pendingStartTap = false
            }
        } message: {
            Text("Add at least one endpoint with a valid URL before starting tracking.")
        }
    }

    private var needsEndpointAlert: Bool {
        pendingStartTap && !engine.settings.hasAnyActiveValidEndpoint
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Azimuth")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.skyDeep, Theme.sky],
                                   startPoint: .leading, endPoint: .trailing)
                )
            Text(subhead)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .id(subhead)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subhead: String {
        let endpoints = engine.settings.endpoints
        if endpoints.isEmpty {
            return "Add an endpoint to begin"
        }
        let active = endpoints.filter { $0.isActive && $0.hasValidURL }.count
        if !engine.isTracking {
            return "Ready when you are"
        }
        if active == 0 {
            return "All endpoints paused"
        }
        return "Sending to \(active) endpoint\(active == 1 ? "" : "s")"
    }

    private var sendAllButton: some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .soft)
            haptic.impactOccurred()
            engine.sendAllDueNow(force: true)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .symbolEffect(.pulse, options: .repeating, isActive: engine.isAnySending)
                Text(engine.isAnySending ? "Sending…" : "Send all now")
                    .contentTransition(.opacity)
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                Capsule().fill(Theme.pulseGradient)
            )
            .shadow(color: Theme.sky.opacity(0.35), radius: 10, x: 0, y: 6)
            .animation(.smooth(duration: 0.35), value: engine.isAnySending)
        }
        .buttonStyle(.plain)
        .disabled(!engine.settings.hasAnyActiveValidEndpoint || engine.isAnySending)
        .opacity(engine.settings.hasAnyActiveValidEndpoint ? 1.0 : 0.5)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Theme.sky)
            Text("No endpoints yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text("Add a destination so Azimuth knows where to post your location.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                router.selection = .settings
            } label: {
                Text("Add endpoint")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.pulseGradient))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 0.7)
                )
        )
    }

    private func handleMainTap() {
        if engine.isTracking {
            engine.stopTracking()
            return
        }
        guard engine.settings.hasAnyActiveValidEndpoint else {
            pendingStartTap = true
            return
        }
        engine.startTracking()
    }
}

#Preview {
    HomeView()
        .environment(AzimuthEngine())
        .environment(TabRouter())
}
