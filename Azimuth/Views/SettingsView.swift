import SwiftUI

struct SettingsView: View {
    @Environment(AzimuthEngine.self) private var engine

    @State private var editingEndpoint: Endpoint?
    @State private var creatingEndpoint: Endpoint?
    @State private var showCopiedToast: Bool = false

    var body: some View {
        @Bindable var settings = engine.settings

        NavigationStack {
            ZStack {
                CanvasBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        endpointsSection(settings: settings)
                        permissionsSection
                        backgroundSection
                        deviceSection(settings: settings)
                        versionFooter
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(item: $editingEndpoint) { ep in
                EndpointEditor(
                    initial: ep,
                    isNew: false,
                    onSave: { updated, token in
                        engine.settings.updateEndpoint(updated)
                        engine.settings.setBearerToken(token, for: updated.id)
                        engine.scheduleNextRefresh()
                    },
                    onDelete: {
                        engine.settings.deleteEndpoint(id: ep.id)
                    }
                )
            }
            .sheet(item: $creatingEndpoint) { ep in
                EndpointEditor(
                    initial: ep,
                    isNew: true,
                    onSave: { new, token in
                        engine.settings.addEndpoint(new)
                        engine.settings.setBearerToken(token, for: new.id)
                        engine.scheduleNextRefresh()
                    },
                    onDelete: nil
                )
            }
        }
    }

    private func endpointsSection(settings: AppSettings) -> some View {
        Card(title: "Endpoints", icon: "link") {
            VStack(spacing: 0) {
                if settings.endpoints.isEmpty {
                    VStack(spacing: 8) {
                        Text("No endpoints yet")
                            .font(.subheadline.weight(.medium))
                        Text("Add a destination to start sending your location.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } else {
                    ForEach(Array(settings.endpoints.enumerated()), id: \.element.id) { idx, ep in
                        Button {
                            editingEndpoint = ep
                        } label: {
                            endpointRow(ep)
                        }
                        .buttonStyle(.plain)
                        if idx < settings.endpoints.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }

                Divider().opacity(0.4)
                Button {
                    creatingEndpoint = Endpoint()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.skyDeep)
                        Text("Add endpoint")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.skyDeep)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func endpointRow(_ ep: Endpoint) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ep.isActive ? Theme.success : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ep.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !ep.isActive {
                        Text("Paused")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.18)))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(rowDetail(ep))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func rowDetail(_ ep: Endpoint) -> String {
        let urlBit: String
        if let host = URL(string: ep.url)?.host, !host.isEmpty {
            urlBit = host
        } else if !ep.url.isEmpty {
            urlBit = ep.url
        } else {
            urlBit = "No URL"
        }
        return "\(urlBit) · \(ep.schedule.summary)"
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
                        Text("Continue")
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
                bullet("Each endpoint has its own schedule. When iOS wakes the app, every endpoint that's due fires on the same wake.")
                bullet("If a send fails because you're offline, it's saved and retried automatically when the network returns.")
                bullet("If you force-quit Azimuth by swiping it out of the App Switcher, the location service shuts down and scheduled sends pause. They resume automatically once iOS detects roughly 500 metres of movement or a cell-tower / Wi-Fi change — at that point iOS silently relaunches Azimuth in the background and sending continues. You don't need to reopen the app.")
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

    private var versionFooter: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return Text("v\(version) (\(build))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
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

private struct EndpointEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AzimuthEngine.self) private var engine

    let isNew: Bool
    let onSave: (Endpoint, String) -> Void
    let onDelete: (() -> Void)?

    @State private var draft: Endpoint
    @State private var nameDraft: String
    @State private var urlDraft: String
    @State private var tokenDraft: String
    @State private var revealToken: Bool = false
    @State private var confirmDelete: Bool = false
    @State private var isURLErrorVisible: Bool = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isURLFocused: Bool
    @FocusState private var isTokenFocused: Bool

    init(initial: Endpoint, isNew: Bool, onSave: @escaping (Endpoint, String) -> Void, onDelete: (() -> Void)?) {
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: initial)
        _nameDraft = State(initialValue: initial.name)
        _urlDraft = State(initialValue: initial.url)
        _tokenDraft = State(initialValue: KeychainStore.shared.bearerToken(for: initial.id) ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        nameAndURLCard
                        tokenCard
                        scheduleCard
                        payloadCard
                        if !isNew { activeCard }
                        if !isNew, onDelete != nil { deleteCard }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNew ? "New endpoint" : "Edit endpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        guard let parsed = URL(string: normalizedURL(from: urlDraft)),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = parsed.host, !host.isEmpty else { return false }

        // Explicit http://… is the escape hatch for local/intranet URLs.
        // Without it, require a public-style host (a 2+ char alphabetic TLD).
        if hasExplicitScheme(urlDraft) { return true }
        guard let dot = host.lastIndex(of: ".") else { return false }
        let tld = host[host.index(after: dot)...]
        return tld.count >= 2 && tld.allSatisfy { $0.isLetter }
    }

    private func hasExplicitScheme(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://")
    }

    private func save() {
        var updated = draft
        updated.name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.url = normalizedURL(from: urlDraft)
        let trimmedToken = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(updated, trimmedToken)
        dismiss()
    }

    private func normalizedURL(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return trimmed
        }
        return "https://" + trimmed
    }

    private var nameAndURLCard: some View {
        Card(title: "Endpoint", icon: "link") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Personal", text: $nameDraft)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .padding(12)
                    .background(inputFieldBackground)
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture().onEnded { isNameFocused = true })

                Divider().opacity(0.4)

                Text("URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    if urlDraft.isEmpty {
                        Text(verbatim: "https://example.com/api/location")
                            .foregroundStyle(.secondary)
                    }
                    TextField("", text: $urlDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .foregroundStyle(.primary)
                        .focused($isURLFocused)
                }
                .padding(12)
                .background(inputFieldBackground)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { isURLFocused = true })
                .background(alignment: .topTrailing) {
                    if isURLErrorVisible {
                        urlErrorTab
                            .padding(.trailing, 12)
                            .offset(y: -22)
                            .transition(.move(edge: .bottom))
                    }
                }
                .onChange(of: isURLFocused) { _, _ in syncURLErrorVisibility() }
                .onChange(of: urlDraft) { _, _ in syncURLErrorVisibility() }
            }
        }
    }

    private var urlErrorTab: some View {
        Text("That URL doesn't look right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 8
                )
                .fill(Theme.danger)
            )
    }

    private var showURLError: Bool {
        !urlDraft.isEmpty && !canSave && !isURLFocused
    }

    private func syncURLErrorVisibility() {
        let target = showURLError
        guard target != isURLErrorVisible else { return }
        withAnimation(.smooth(duration: 0.3)) {
            isURLErrorVisible = target
        }
    }

    private var tokenCard: some View {
        Card(title: "Authentication", icon: "key") {
            VStack(alignment: .leading, spacing: 8) {
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
                                    .focused($isTokenFocused)
                            } else {
                                SecureField("", text: $tokenDraft)
                                    .focused($isTokenFocused)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.primary)
                    }
                    .frame(minHeight: 22)
                    Button {
                        revealToken.toggle()
                    } label: {
                        Image(systemName: revealToken ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .animation(.smooth(duration: 0.3), value: revealToken)
                }
                .padding(12)
                .background(inputFieldBackground)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { isTokenFocused = true })

                Text("Sent as `Authorization: Bearer …`. Stored in the iOS Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scheduleCard: some View {
        Card(title: "Schedule", icon: "clock") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Send my location \(draft.schedule.summary)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .id(draft.schedule.summary)
                SchedulePicker(schedule: $draft.schedule)
                Text("iOS may delay background sends slightly to save battery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var payloadCard: some View {
        Card(title: "Payload", icon: "doc.text") {
            VStack(spacing: 4) {
                Toggle("Include speed", isOn: $draft.includeSpeed)
                Toggle("Include battery level", isOn: $draft.includeBattery)
                Text("Payload format is GeoJSON Feature, with a `locations` array and a `current` object.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
            .tint(Theme.skyDeep)
        }
    }

    private var activeCard: some View {
        Card(title: "Status", icon: "power") {
            Toggle("Active", isOn: $draft.isActive)
                .tint(Theme.skyDeep)
        }
    }

    private var deleteCard: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Text("Delete endpoint")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Theme.danger)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.danger.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .alert("Delete endpoint?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("This removes \(draft.displayName) and its bearer token. Recent send history is preserved.")
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
}
