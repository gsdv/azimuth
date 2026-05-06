import SwiftUI

struct SettingsView: View {
    @Environment(AzimuthEngine.self) private var engine

    @State private var endpointDraft: String = ""
    @State private var tokenDraft: String = ""
    @State private var revealToken: Bool = false
    @State private var showCopiedToast: Bool = false

    var body: some View {
        @Bindable var settings = engine.settings

        NavigationStack {
            ZStack {
                CanvasBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        endpointSection(settings: settings)
                        scheduleSection(settings: settings)
                        payloadSection(settings: settings)
                        permissionsSection
                        backgroundSection
                        deviceSection(settings: settings)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                endpointDraft = settings.endpointURL
                tokenDraft = settings.bearerToken
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    Text("Copied")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private func endpointSection(settings: AppSettings) -> some View {
        Card(title: "Endpoint", icon: "link") {
            VStack(alignment: .leading, spacing: 12) {
                Text("URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    if endpointDraft.isEmpty {
                        Text(verbatim: "https://example.com/api/location")
                            .foregroundStyle(.secondary)
                    }
                    TextField("", text: $endpointDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .foregroundStyle(.primary)
                        .onChange(of: endpointDraft) { _, new in
                            settings.endpointURL = new.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                }
                .padding(12)
                .background(inputFieldBackground)

                if !endpointDraft.isEmpty && !settings.hasValidEndpoint {
                    Label("That URL doesn't look right.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }

                Divider().opacity(0.4)

                Text("Bearer token (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    ZStack(alignment: .leading) {
                        if tokenDraft.isEmpty {
                            Text(verbatim: "Paste token")
                                .foregroundStyle(.secondary)
                        }
                        Group {
                            if revealToken {
                                TextField("", text: $tokenDraft)
                            } else {
                                SecureField("", text: $tokenDraft)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.primary)
                        .onChange(of: tokenDraft) { _, new in
                            settings.bearerToken = new
                        }
                    }

                    Button {
                        revealToken.toggle()
                    } label: {
                        Image(systemName: revealToken ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(inputFieldBackground)

                Text("Sent as `Authorization: Bearer …`. Stored in the iOS Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scheduleSection(settings: AppSettings) -> some View {
        Card(title: "Schedule", icon: "clock") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Send my location \(settings.schedule.summary)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .id(settings.schedule.summary)
                SchedulePicker(schedule: Binding(
                    get: { settings.schedule },
                    set: { settings.schedule = $0 }
                ))
                Text("iOS may delay background sends slightly to save battery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func payloadSection(settings: AppSettings) -> some View {
        Card(title: "Payload", icon: "doc.text") {
            VStack(spacing: 4) {
                Toggle("Include speed", isOn: Binding(
                    get: { settings.includeSpeed },
                    set: { settings.includeSpeed = $0 }
                ))
                Toggle("Include battery level", isOn: Binding(
                    get: { settings.includeBattery },
                    set: { settings.includeBattery = $0 }
                ))
                Text("Payload format is GeoJSON Feature, with a `locations` array and a `current` object.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
            .tint(Theme.skyDeep)
        }
    }

    private var permissionsSection: some View {
        Card(title: "Location permission", icon: "location") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle().fill(authColor).frame(width: 8, height: 8)
                    Text(authText).font(.subheadline.weight(.medium))
                    Spacer()
                }
                if engine.location.authorization == .notDetermined {
                    Button {
                        engine.location.requestPermission()
                    } label: {
                        Text("Request permission")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.skyDeep)
                } else if engine.location.authorization == .whenInUse {
                    Button {
                        engine.location.requestPermission()
                    } label: {
                        Text("Allow background tracking")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.skyDeep)
                } else if engine.location.authorization == .denied || engine.location.authorization == .restricted {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var backgroundSection: some View {
        Card(title: "How sending works", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 10) {
                bullet("Azimuth runs a low-power location service so iOS can wake the app and post on schedule, even with the screen locked.")
                bullet("Each send fires on the next location update once your interval has elapsed.")
                bullet("If a send fails because you're offline, it's saved and retried automatically when the network returns.")
                bullet("If you force-quit Azimuth by swiping it out of the App Switcher, the location service shuts down and scheduled sends pause. They resume automatically once iOS detects roughly 500 metres of movement or a cell-tower / Wi-Fi change — at that point iOS silently relaunches Azimuth in the background and sending continues. You don't need to reopen the app.")
                if engine.pendingCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.full")
                            .foregroundStyle(Theme.warning)
                        Text("\(engine.pendingCount) send\(engine.pendingCount == 1 ? "" : "s") queued offline")
                            .font(.footnote.weight(.medium))
                        Spacer()
                        Button("Retry now") {
                            engine.flushPending()
                        }
                        .font(.footnote.weight(.semibold))
                        .tint(Theme.skyDeep)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.chipFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.cardStroke, lineWidth: 0.5)
                            )
                    )
                    .padding(.top, 4)
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.sky)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inputFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.6), lineWidth: 0.7)
            )
    }

    private func deviceSection(settings: AppSettings) -> some View {
        Card(title: "Device", icon: "iphone") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Device ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Text(settings.deviceId)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = settings.deviceId
                        withAnimation { showCopiedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { showCopiedToast = false }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(Theme.skyDeep)
                    }
                    .buttonStyle(.plain)
                }
                Text("Sent as `device_id` in each request so your endpoint can identify this device.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var authColor: Color {
        switch engine.location.authorization {
        case .always:        return Theme.success
        case .whenInUse:     return Theme.warning
        case .denied, .restricted: return Theme.danger
        case .notDetermined: return .secondary
        }
    }

    private var authText: String {
        switch engine.location.authorization {
        case .always:        return "Always — works in the background"
        case .whenInUse:     return "While using the app — switch to Always for background sends"
        case .denied:        return "Denied — open Settings to enable"
        case .restricted:    return "Restricted by device policy"
        case .notDetermined: return "Not requested yet"
        }
    }
}

private struct Card<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.skyDeep)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 0.7)
                )
                .shadow(color: Theme.skyDeep.opacity(0.08), radius: 14, x: 0, y: 6)
        )
    }
}
