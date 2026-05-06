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
                    isSending: engine.status.isSending,
                    action: handleMainTap
                )

                Spacer(minLength: 16)

                VStack(spacing: 14) {
                    StatusCard(
                        status: engine.status,
                        lastSent: settings.lastSentDate,
                        nextSend: engine.nextSendDate,
                        isTracking: engine.isTracking
                    )

                    MapPreview(location: engine.location.lastLocation)

                    sendNowButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .onReceive(tick) { now in nowTick = now }
        .alert("Set an endpoint first", isPresented: Binding(
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
            Text("Tell Azimuth which URL to send your location to before starting tracking.")
        }
    }

    private var needsEndpointAlert: Bool {
        pendingStartTap && !engine.settings.hasValidEndpoint
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
        if !engine.settings.hasValidEndpoint {
            return "Set an endpoint to begin"
        }
        if engine.isTracking {
            return "Sending \(engine.settings.schedule.summary)"
        }
        return "Ready when you are"
    }

    private var sendNowButton: some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .soft)
            haptic.impactOccurred()
            engine.sendNow()
        } label: {
            Label("Send now", systemImage: "paperplane.fill")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    Capsule().fill(Theme.pulseGradient)
                )
                .shadow(color: Theme.sky.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!engine.settings.hasValidEndpoint || engine.status.isSending)
        .opacity(engine.settings.hasValidEndpoint ? 1.0 : 0.5)
    }

    private func handleMainTap() {
        if engine.isTracking {
            engine.stopTracking()
            return
        }
        guard engine.settings.hasValidEndpoint else {
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
